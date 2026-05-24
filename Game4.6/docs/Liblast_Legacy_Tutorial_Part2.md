## 5. 核心系统分析

### 5.1 Globals 系统

`Globals.gd` 是项目的核心,定义了全局状态和常量。

**主要功能:**

```gdscript
# 版本号管理
class LiblastVersionNumber:
    var major: int
    var minor: int
    var patch: int
    var hotfix: int
    var type: ReleaseType

# 游戏模式枚举
enum GameMode {
    CONTROL_POINTS,      # 据点争夺
    DUEL,                # 决斗
    CAMPAIGN,            # 战役
    DEATHMATCH,          # 死亡竞赛
    TEAM_DEATHMATCH,     # 团队死亡竞赛
    KING_OF_THE_HILL,    # 山顶之王
    FRIDGE_STACKING      # 冰箱堆叠(彩蛋模式)
}

# 匹配阶段
enum MatchPhase {
    LOBBY,   # 大厅
    WARMUP,  # 热身
    GAME     # 游戏中
}

# 焦点状态(控制输入行为)
enum Focus {
    MENU,    # 菜单
    GAME,    # 游戏
    CHAT,    # 聊天
    AWAY,    # 离开
    CONSOLE  # 控制台
}

# 网络配置
const NET_SERVER: String = "localhost"
const NET_PORT: int = 12597
const NET_PEER_LIMIT = 32

# 队伍颜色
enum Teams { NONE, LIME, PLUM }
var team_colors = {
    Teams.NONE: Color.from_hsv(0, 0, 0.9),
    Teams.LIME: Color.html("cbfc10"),  # 青柠色
    Teams.PLUM: Color.html("a100ff"),  # 紫色
}

# 当前焦点管理
var focus: Focus = Focus.MENU:
    set(value):
        if value == self.focus:
            return
        focus_previous = focus
        focus = value
        focus_changed.emit(focus, focus_previous)
        
        # 根据焦点设置鼠标模式
        if value in [Focus.MENU, Focus.CONSOLE]:
            Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
        else:
            Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# 当前控制的角色
var current_character: CharacterBody3D = null:
    set(value):
        if value == current_character:
            return
        var previous_character = current_character
        current_character = value
        current_character_changed.emit(current_character, previous_character)
```

**使用示例:**

```gdscript
# 在任何脚本中访问 Globals
func _ready():
    # 获取当前游戏模式
    var mode = MultiplayerState.game_config.game_mode
    
    # 检查焦点状态
    if Globals.focus == Globals.Focus.GAME:
        print("在游戏中")
    
    # 获取队伍颜色
    var team_color = Globals.team_colors[Globals.Teams.LIME]
```

### 5.2 Settings 系统

`Settings.gd` 管理所有游戏配置,类似于 idtech 引擎的 cvars 系统。

**主要功能:**

```gdscript
# 默认设置
const settings_default = {
    'first_run': true,
    'auth_enabled': false,
    'input_mouse_sensitivity': 1.0,
    'input_mouse_invert_y': false,
    'display_fullscreen': true,
    'display_window_size': Vector2(1280, 720),
    'display_vsync': 2,
    'render_scale': 1.0,
    'render_fps_max': 0,
    'render_fov': 90,
    'render_hud': true,
    'render_refprobes': true,
    'render_gibs': true,
    'render_particles_amount': 1.0,
    'render_enviro_quality': EnviroQuality.MEDIUM,
    'audio_volume_master': 0.0,
    'audio_volume_music': -6.0,
    'audio_volume_sfx': -6.0,
    'network_upnp': true,
}

# 设置变更信号
signal var_changed(var_name, value)

# 获取设置值
func get_var(var_name: String) -> Variant:
    if settings.has(var_name):
        return settings.get(var_name)
    elif settings_default.has(var_name):
        return settings_default.get(var_name)
    else:
        push_error("Settings: var not found: '", var_name, "'")
        return null

# 设置值
func set_var(var_name: String, value: Variant) -> int:
    if value == null:
        return ERR_INVALID_DATA
    
    if not dirty:
        dirty = true
    settings[var_name] = value
    emit_signal('var_changed', var_name, value)
    call_apply_var(var_name)  # 应用设置
    save_settings()           # 保存到磁盘
    
    return OK

# 应用设置的函数(示例)
func apply_display_fullscreen(value: bool) -> void:
    if value:
        get_viewport().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
    else:
        get_viewport().mode = Window.MODE_WINDOWED

func apply_render_fps_max(value) -> void:
    Engine.max_fps = value

func apply_audio_volume_master(value) -> void:
    AudioServer.set_bus_volume_db(0, value)
```

**使用示例:**

```gdscript
# 读取设置
var fov = Settings.get_var("render_fov")
var sensitivity = Settings.get_var("input_mouse_sensitivity")

# 修改设置
Settings.set_var("render_fov", 100)
Settings.set_var("audio_volume_sfx", -10.0)

# 监听设置变化
Settings.var_changed.connect(_on_setting_changed)

func _on_setting_changed(var_name: String, value):
    if var_name == "render_fov":
        update_camera_fov(value)
```

**设置保存:**
- 设置保存在 `user://settings/settings.liblast`
- 使用防抖动机制,避免频繁写入磁盘
- 只保存与默认值不同的设置

### 5.3 MultiplayerState 系统

`MultiplayerState.gd` 管理所有多人游戏相关的功能。

**主要功能:**

```gdscript
# 多人游戏角色枚举
enum MultiplayerRole {
    NONE,              # 未连接
    CLIENT,            # 客户端
    SERVER,            # 服务器(带本地玩家)
    DEDICATED_SERVER,  # 专用服务器
    INTERMEDIATE       # 中间状态
}

var role: MultiplayerRole = MultiplayerRole.NONE
var peer: ENetMultiplayerPeer
var local_character: Character = null
var auth_enabled: bool
var auth_username: String
var auth_tokens: Array

# 启动服务器
func start_server(new_role = MultiplayerRole.SERVER) -> int:
    role = MultiplayerRole.INTERMEDIATE
    
    peer = ENetMultiplayerPeer.new()
    var err = peer.create_server(Globals.NET_PORT, Globals.NET_PEER_LIMIT)
    
    if err == OK:
        get_tree().get_multiplayer().multiplayer_peer = peer
        spawn_game_state(false)
        await(Globals.game_state.map_spawned)
        
        role = new_role
        
        if role != MultiplayerRole.DEDICATED_SERVER:
            Globals.game_state.spawn_character(1)  # 生成服务器玩家
            Globals.focus = Globals.Focus.GAME
    
    return err

# 启动客户端
func start_client(host: String) -> int:
    peer = ENetMultiplayerPeer.new()
    var err = peer.create_client(host, Globals.NET_PORT)
    
    get_tree().get_multiplayer().multiplayer_peer = peer
    role = MultiplayerRole.INTERMEDIATE
    
    return err

# 停止服务器
func stop_server():
    assert(multiplayer.is_server(), "Trying to stop server while not being a server")
    stop_client.rpc()  # 通知所有客户端断开
    cleanup_game_state()

# 清理游戏状态
func cleanup_game_state():
    if Globals.game_state:
        Globals.game_state.queue_free()
    
    multiplayer.multiplayer_peer = null
    role = MultiplayerRole.NONE
    local_character = null
    Globals.current_character = null
```

**连接流程:**

```
服务器启动:
1. start_server() 创建 ENet 服务器
2. spawn_game_state() 创建 GameState
3. 等待地图加载完成
4. 生成服务器玩家角色

客户端连接:
1. start_client(host) 连接到服务器
2. 触发 _on_connected_to_server()
3. spawn_game_state() 创建 GameState
4. 等待地图加载
5. 请求生成角色: spawn_character.rpc_id(1, pid)
6. 发送角色配置
```

### 5.4 GameState 系统

`GameState.gd` 管理单个游戏会话的所有状态。

**主要功能:**

```gdscript
class_name GameState
extends Node3D

# 信号
signal map_loaded
signal map_spawned
signal match_started
signal match_ended(winner_team: int)
signal game_scores_updated
signal match_phase_changed

# 游戏状态
var current_match_phase: MatchPhase
var match_timer: SceneTreeTimer
var threaded_map_loading: bool = true

# 角色管理
var characters: Array  # 所有角色
var characters_by_pid: Dictionary  # 按 PID 索引
var characters_by_team: Dictionary  # 按队伍索引
var bots_by_pid: Dictionary  # 机器人按 PID 索引
var profiles_by_pid: Dictionary  # 角色配置按 PID 索引

# 得分
var scores_by_team = {0: 0, 1: 0, 2: 0}

# 地图
var map: Node3D
var map_path: String:
    set(value):
        if value == map_path:
            return
        map_path = value
        if map:
            unload_map()
        if not map_path.is_empty():
            load_map(threaded_map_loading)

# 加载地图
func load_map(threaded := false):
    if has_map():
        unload_map()
    
    var map_resource: PackedScene
    
    if threaded:
        ResourceLoader.load_threaded_request(map_path, "PackedScene", true)
        set_process(true)
        await(map_loaded)
        set_process(false)
        map_resource = ResourceLoader.load_threaded_get(map_path)
    else:
        map_resource = load(map_path)
    
    map = map_resource.instantiate()
    map.name = "Map"
    add_child(map)
    
    if not map.map_is_ready:
        await(map.map_ready)
    
    map_spawned.emit()
    update_bots()

# 生成角色
@rpc("any_peer", "call_remote", "reliable")
func spawn_character(pid: int, bot: bool = false):
    assert(is_instance_valid(map))
    
    if not map.map_is_ready:
        await(map.map_ready)
    
    if multiplayer.is_server():
        var team: int
        
        # 决定队伍
        if not MultiplayerState.game_config.bots_vs_humans:
            if characters_by_team[1].size() > characters_by_team[2].size():
                team = 2
            elif characters_by_team[1].size() < characters_by_team[2].size():
                team = 1
            else:
                team = randi_range(1, 2)
        else:
            team = 2 if bot else 1
        
        if bot:
            # 生成机器人配置
            var profile = CharacterProfile.new()
            profile.badges.append(Badges.Badge.BOT)
            profile.display_name = NameGenerator.generate()
            
            pid = -(bots_by_pid.size() + 1)
            update_character_profile(pid, profile)
        
        # 生成角色
        $CharacterSpawner.spawn({
            &"owner_pid": pid,
            &"team": team,
            &"bot": bot
        })
    
    update_bots()

# 开始比赛
@rpc("any_peer", "call_remote", "reliable")
func start_match():
    # 重置得分
    for i in scores_by_team.keys():
        scores_by_team[i] = 0
    
    map.start_match()
    
    if multiplayer.is_server():
        set_match_timer(MultiplayerState.game_config.match_time_limit_minutes * 60 * 1000)
    
    get_tree().paused = false
    current_match_phase = Globals.MatchPhase.GAME
    match_started.emit()
```

---

## 6. 游戏逻辑实现

### 6.1 角色控制系统

角色控制分为三层:
1. **CharacterController**:接收输入
2. **Character**:处理逻辑和状态
3. **CharMovement**:执行移动

**CharMovementType1.gd 核心逻辑:**

```gdscript
extends CharacterMovement

const GRAVITY = 30.0
const WALK_SPEED = 8.0
const JUMP_VELOCITY = 12.0
const JETPACK_FORCE = 25.0
const JETPACK_FUEL_MAX = 100.0

var special_amount: float = 1.0  # 喷气背包燃料
var special_active: bool = false

func process(delta: float):
    if not character:
        return
    
    # 应用重力
    if not character.is_on_floor():
        character.velocity.y -= GRAVITY * delta
    
    # 处理移动输入
    var input_dir = Vector3.ZERO
    
    if character.controls[Globals.CharCtrlType.MOVE_F].enabled:
        input_dir.z -= 1
    if character.controls[Globals.CharCtrlType.MOVE_B].enabled:
        input_dir.z += 1
    if character.controls[Globals.CharCtrlType.MOVE_L].enabled:
        input_dir.x -= 1
    if character.controls[Globals.CharCtrlType.MOVE_R].enabled:
        input_dir.x += 1
    
    input_dir = input_dir.normalized()
    
    # 转换为世界空间方向
    var direction = (character.global_transform.basis * input_dir).normalized()
    
    # 应用速度
    if direction.length() > 0:
        character.velocity.x = direction.x * WALK_SPEED
        character.velocity.z = direction.z * WALK_SPEED
    else:
        character.velocity.x = move_toward(character.velocity.x, 0, WALK_SPEED)
        character.velocity.z = move_toward(character.velocity.z, 0, WALK_SPEED)
    
    # 跳跃
    if character.controls[Globals.CharCtrlType.MOVE_J].changed and \
       character.controls[Globals.CharCtrlType.MOVE_J].enabled and \
       character.is_on_floor():
        character.velocity.y = JUMP_VELOCITY
    
    # 喷气背包
    if character.controls[Globals.CharCtrlType.MOVE_S].enabled and \
       special_amount > 0:
        special_active = true
        character.velocity.y += JETPACK_FORCE * delta
        special_amount -= delta * 20.0 / JETPACK_FUEL_MAX
    else:
        special_active = false
        if special_amount < 1.0:
            special_amount += delta * 10.0 / JETPACK_FUEL_MAX
    
    # 应用移动
    character.move_and_slide()
```

### 6.2 战斗系统

战斗系统基于伤害(Damage)类和武器系统。

**伤害类层次:**

```gdscript
# 基础伤害类
class_name Damage
extends Resource

var damage_amount: int
var source_position: Vector3
var hit_position: Vector3

# 攻击伤害
class_name DamageAttack
extends Damage

var attacker: Character
var attacker_pid: int

# 爆炸伤害
class_name DamageExplosion
extends DamageAttack

var explosion_radius: float
var falloff: float

# 坠落伤害
class_name DamageFall
extends Damage

func kill_message() -> String:
    return "fell to their death"
```

**角色受伤处理:**

```gdscript
# Character.gd
@rpc("call_remote", "any_peer", "reliable")
func hurt(_damage):
    if is_gibbed:
        return
    
    var damage: Damage
    if _damage is Damage:
        damage = _damage
    elif _damage is Dictionary:
        damage = dict_to_inst(_damage)
    
    if state.alive:
        # 检查友军伤害
        if damage is DamageAttack and damage.attacker:
            if damage.attacker.state.team == state.team:
                if MultiplayerState.game_config.friendy_fire_amount != 0:
                    damage.damage_amount *= MultiplayerState.game_config.friendy_fire_amount
                else:
                    return
        
        # 应用伤害
        state.health -= damage.damage_amount
        
        # 相机震动
        camera_shake_damage.shake_amount += damage.damage_amount / 100.0
        
        # 检查是否死亡
        if state.health <= 0:
            if damage is DamageAttack and damage.attacker:
                killer = damage.attacker
                damage.attacker.attack_hit_confirmation(true, self)
            die(damage)
        else:
            # 播放受伤声音
            if not mouth.playing:
                mouth.stream = voice.hurt
                mouth.play()

func die(damage: Damage):
    if state.alive == false:
        return
    
    # 播放死亡声音
    mouth.stream = voice.die
    mouth.play()
    
    # 禁用碰撞
    collision_layer = collision_layer_dead
    is_mobile = false
    
    # 启动布娃娃物理
    if MultiplayerState.role != MultiplayerRole.DEDICATED_SERVER:
        skeleton.physical_bones_start_simulation()
    
    # 切换到死亡相机
    current_camera = CharacterCurrentCamera.DEATH
    
    state.health = 0
    state.alive = false
    state.deaths += 1
    
    # 安排重生
    var respawn_tween = create_tween()
    respawn_tween.tween_interval(MultiplayerState.game_config.respawn_wait_time)
    respawn_tween.finished.connect(respawn)
    respawn_tween.play()

func respawn():
    hide()
    
    # 停止布娃娃物理
    skeleton.physical_bones_stop_simulation()
    
    # 重置状态
    movement.reset()
    current_camera = CharacterCurrentCamera.FIRST_PERSON
    state.health = max_health
    state.alive = true
    
    # 传送到出生点
    global_transform = game_state.get_spawn_transform(state.team)
    
    # 恢复碰撞
    collision_layer = collision_layer_alive
    
    show()
    is_mobile = true
```

### 6.3 游戏模式实现

**据点争夺模式(Control Points):**

```gdscript
# ControlPoint.gd
class_name ControlPoint extends Node3D

var team: Teams = Teams.NONE:
    set(value):
        var old_team = team
        team = value
        
        # 更新视觉效果
        match team:
            Teams.NONE:
                $Team1.hide()
                $Team2.hide()
                $ScoreTimer.stop()
            Teams.LIME:
                $Team1.show()
                $Team2.hide()
                $ScoreTimer.start()
            Teams.PLUM:
                $Team1.hide()
                $Team2.show()
                $ScoreTimer.start()
        
        $Sprite3D.modulate = Globals.team_colors[team]

var colliding_characters: Array[Character]

func _on_area_3d_body_entered(body: Node3D):
    if not multiplayer.is_server():
        return
    if body is Character:
        colliding_characters.append(body)
        body.connect(&"character_died", check_for_capture)
        check_for_capture()

func check_for_capture():
    if not multiplayer.is_server():
        return
    
    var teams_present = {0: false, 1: false, 2: false}
    
    for char in colliding_characters:
        if is_instance_valid(char) and char.state.alive:
            teams_present[char.state.team] = true
    
    # 只有一个队伍在场时才占领
    if teams_present[1] and not teams_present[2]:
        team = Teams.LIME
    elif teams_present[2] and not teams_present[1]:
        team = Teams.PLUM
    
    set_team.rpc(team)

func _on_score_timer_timeout():
    if not multiplayer.is_server():
        return
    if Globals.game_state.current_match_phase == Globals.MatchPhase.GAME:
        # 每秒为占领队伍增加分数
        Globals.game_state.increment_team_score(team, self)
```

---

*(教程继续...)*
