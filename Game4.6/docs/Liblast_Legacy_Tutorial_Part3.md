## 7. 网络与多人游戏

### 7.1 Godot 多人游戏架构

Liblast 使用 Godot 4 的高级多人 API(High-Level Multiplayer API)。

**关键概念:**

1. **权威模型(Authority Model)**
   - 服务器拥有最终决定权
   - 客户端预测并在服务器确认后修正

2. **RPC(远程过程调用)**
   - `@rpc` 注解标记可远程调用的函数
   - 支持可靠/不可靠传输
   - 支持不同权限级别

3. **MultiplayerSpawner**
   - 自动同步生成的节点
   - 处理节点的创建和销毁

### 7.2 RPC 模式

```gdscript
# RPC 模式说明
@rpc(mode, transfer_mode, call_local)

# mode: 谁可以调用
# - "authority": 只有权威端可以调用
# - "any_peer": 任何对等方可以调用
# - "call_local": 仅本地调用(不通过网络)

# transfer_mode: 传输方式
# - "reliable": 可靠传输(保证到达,可能重复)
# - "unreliable": 不可靠传输(可能丢失,不会重复)
# - "unreliable_ordered": 不可靠但有序

# call_local: 是否在本地也调用
# - "call_local": 本地也执行
# - "call_remote": 仅远程执行
```

**示例:**

```gdscript
# 服务器权威的可靠 RPC
@rpc("authority", "call_remote", "reliable")
func spawn_character(pid: int):
    # 只在服务器上执行,然后同步到所有客户端
    pass

# 任何客户端可调用的 RPC
@rpc("any_peer", "call_remote", "reliable")
func send_chat_message(text: String):
    var sender_id = multiplayer.get_remote_sender_id()
    # 广播消息给所有人
    broadcast_chat_message.rpc(sender_id, text)

@rpc("call_remote", "any_peer", "reliable")
func broadcast_chat_message(sender_id: int, text: String):
    # 在所有客户端显示消息
    display_chat_message(sender_id, text)

# 高频更新的不可靠 RPC
@rpc("authority", "call_remote", "unreliable")
func update_position(pos: Vector3):
    # 位置更新,允许丢失
    global_position = pos
```

### 7.3 角色同步

**MultiplayerSpawner 配置:**

```gdscript
# GameState.gd
@onready var spawner: MultiplayerSpawner = $CharacterSpawner

func _ready():
    spawner.spawn_function = _spawn_custom

func _spawn_custom(data: Dictionary) -> Node:
    var pid = data["owner_pid"]
    var team = data["team"]
    var bot = data["bot"]
    
    # 加载角色场景
    var character_scene = preload("res://Assets/Characters/Character.tscn")
    var character = character_scene.instantiate()
    
    # 设置所有权
    character.set_character_owner(pid)
    
    # 设置状态
    var state = CharacterState.new()
    state.team = team
    character.state = state
    
    # 添加到场景
    $CharactersRoot.add_child(character)
    
    # 注册到字典
    characters_by_pid[pid] = character
    characters.append(character)
    characters_by_team[team].append(character)
    
    if pid < 0:
        bots_by_pid[pid] = character
    
    return character
```

**状态同步:**

```gdscript
# CharacterState.gd
class_name CharacterState
extends Resource

@export var health: int = 100
@export var alive: bool = true
@export var team: int = 0
@export var kills: int = 0
@export var deaths: int = 0
@export var spawn_time: float = 0
@export var ping: int = 0
@export var packet_loss: int = 0
```

### 7.4 网络优化

**延迟补偿:**

```gdscript
# 服务器计算客户端延迟
func set_match_timer_on_peer(pid: int):
    var network_peer = MultiplayerState.peer.get_peer(pid)
    var ping = network_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
    
    # 补偿一半的往返时间
    set_match_timer.rpc_id(pid, 
        round(match_timer.time_left * 1000 - (ping / 2)), 
        weight)
```

**带宽优化:**

```gdscript
# 使用不可靠传输发送高频数据
@rpc("authority", "call_remote", "unreliable")
func update_velocity(vel: Vector3):
    velocity = vel

# 使用可靠传输发送关键数据
@rpc("authority", "call_remote", "reliable")
func take_damage(amount: int):
    health -= amount

# 批量更新减少 RPC 调用次数
@rpc("authority", "call_remote", "reliable")
func batch_update(states: Array):
    for state_data in states:
        apply_state(state_data)
```

### 7.5 握手和认证

```gdscript
# MultiplayerState.gd
func start_client(host: String) -> int:
    peer = ENetMultiplayerPeer.new()
    var err = peer.create_client(host, Globals.NET_PORT)
    
    if err != OK:
        push_error("Cannot start client: ", error_string(err))
        return err
    
    get_tree().get_multiplayer().multiplayer_peer = peer
    
    # 发送握手信息
    var handshake_data = {
        "client_version": Globals.build_version,
        "auth_token": auth_tokens[0] if not auth_tokens.is_empty() else null,
        "user_display_name": user_character_profile.display_name,
        "request": "join",
        "platform": "web" if OS.has_feature("web") else "pc"
    }
    
    peer.put_var(handshake_data)
    
    return err
```

---

## 8. 资源管理

### 8.1 资源类型

**Godot 资源类型:**

1. **PackedScene**:打包的场景文件(.tscn)
2. **Resource**:通用资源基类
3. **Texture**:纹理资源
4. **Material**:材质资源
5. **AudioStream**:音频流
6. **Animation**:动画资源

**Liblast 自定义资源:**

```gdscript
# CharacterProfile.gd
class_name CharacterProfile
extends Resource

@export var display_name: String = "Player"
@export var display_color: Color = Color.WHITE
@export var voice_pitch: float = 1.0
@export var fov: int = 90
@export var badges: Array[Badges.Badge] = []

# GameConfig.gd
class_name GameConfig
extends Resource

@export var game_mode: Globals.GameMode = Globals.GameMode.TEAM_DEATHMATCH
@export var map: String = "TrainingRing"
@export var bot_amount: int = 4
@export var bots_vs_humans: bool = false
@export var bots_fill_vacant: bool = true
@export var match_time_limit_minutes: int = 10
@export var match_score_limit: int = 30
@export var respawn_wait_time: float = 3.0
@export var friendy_fire_amount: float = 0.0
```

### 8.2 资源加载

**预加载(编译时):**

```gdscript
# 在脚本顶部预加载
const CHARACTER_SCENE = preload("res://Assets/Characters/Character.tscn")
const BULLET_TRAILER = preload("res://Assets/Effects/BulletTracer.tscn")

func _ready():
    var character = CHARACTER_SCENE.instantiate()
    add_child(character)
```

**动态加载(运行时):**

```gdscript
# 同步加载
var scene = load("res://Assets/Maps/DM1-2.tscn")
var map = scene.instantiate()
add_child(map)

# 异步加载(推荐用于大资源)
ResourceLoader.load_threaded_request("res://Assets/Maps/DM1-2.tscn")

func _process(delta):
    var status = ResourceLoader.load_threaded_get_status(map_path)
    match status:
        ResourceLoader.THREAD_LOAD_IN_PROGRESS:
            var progress = []
            ResourceLoader.load_threaded_get_status(map_path, progress)
            print("Loading: ", progress[0] * 100, "%")
        
        ResourceLoader.THREAD_LOAD_LOADED:
            var scene = ResourceLoader.load_threaded_get(map_path)
            var map = scene.instantiate()
            add_child(map)
```

### 8.3 资源缓存

```gdscript
# Resources.gd - 资源管理器
extends Node

var cached_scenes: Dictionary = {}

func get_scene(path: String) -> PackedScene:
    if cached_scenes.has(path):
        return cached_scenes[path]
    
    var scene = load(path)
    if scene:
        cached_scenes[path] = scene
    
    return scene

func clear_cache():
    cached_scenes.clear()
```

### 8.4 内存管理

```gdscript
# 正确释放资源
func cleanup():
    # 从场景中移除节点
    remove_child(node)
    
    # 释放节点
    node.queue_free()
    
    # 等待一帧确保完全释放
    await get_tree().process_frame
    
    # 清除引用
    node = null

# 避免内存泄漏
func _exit_tree():
    # 断开所有信号连接
    some_signal.disconnect(my_handler)
    
    # 停止所有定时器
    timer.stop()
    
    # 清理资源
    resource = null
```

---

## 9. UI 与 HUD 系统

### 9.1 UI 架构

Liblast 使用 Godot 的 Control 节点系统构建 UI。

**UI 层次结构:**

```
Main.tscn
└── UI (Control)
    ├── MainMenu (Control)
    │   ├── Title (Label)
    │   ├── Buttons (VBoxContainer)
    │   └── Background (TextureRect)
    ├── GameMenu (Control)
    │   ├── HostSection (VBoxContainer)
    │   └── JoinSection (VBoxContainer)
    └── HUD (Control)
        ├── Crosshair (TextureRect)
        ├── Stats (VBoxContainer)
        │   ├── HealthBar (ProgressBar)
        │   └── JetpackBar (ProgressBar)
        ├── TeamScores (HBoxContainer)
        ├── DamageOverlay (ColorRect)
        └── Chat (Control)
```

### 9.2 HUD 系统

**HUD.gd 核心功能:**

```gdscript
extends Control

var pain: float = 0:
    set(value):
        pain = value
        $Overlays/Damage.color.a = pain

func _ready():
    hide()  # 默认隐藏
    
    Globals.current_character_changed.connect(_on_current_character_changed)
    Globals.focus_changed.connect(_on_focus_changed)

func _on_current_character_changed(new_character, old_character):
    # 断开旧角色
    if old_character:
        old_character.character_hud_update.disconnect(character_hud_update)
    
    # 连接新角色
    if new_character:
        new_character.character_hud_update.connect(character_hud_update)
        update_character_profile(new_character)
    
    # 显示/隐藏 HUD
    visible = true if new_character and Settings.get_var('render_hud') else false

func character_hud_update(update: CharHudUpdate):
    # 更新特殊能力条(喷气背包)
    if update.special_type != CharMovement.SpecialType.NONE:
        $Stats/JetpackBar.value = update.special_amount
    
    # 更新准星
    if update.zoom:
        if update.zoom_amount > 0:
            dim_crosshair(true)
        else:
            dim_crosshair(false)
    
    # 更新生命值
    if update.got_damage or update.got_healing or update.got_spawned:
        var health_bar = $Stats/HealthBar
        health_bar.value = update.state.health
        
        if update.got_damage:
            # 添加疼痛效果
            pain += clampf(update.got_damage.damage_amount / 50.0, 0.33, 1.5) * 3
        
        elif update.got_spawned:
            pain = 0
    
    # 死亡处理
    if update.got_killed:
        $DamageCompass.hide()
        %KilledBy.show()
        $RespawnCountdown.show()
    
    # 击杀提示
    if update.did_kill:
        $Crosshair.kill()
        %Killed.show()

func _process(delta):
    # 疼痛效果逐渐消退
    if pain > 0:
        pain = lerpf(pain, 0, delta)
    
    # 更新重生倒计时
    if Globals.current_character:
        var cur_char_state = Globals.current_character.state
        if cur_char_state.spawn_time > 0 and not cur_char_state.alive:
            var countdown = max(0, cur_char_state.spawn_time - 
                Time.get_ticks_msec() / 1000.0)
            $RespawnCountdown.text = "RESPAWNING IN %1.2f SECONDS..." % countdown
    
    # 更新比赛计时器
    if Globals.game_state and Globals.game_state.match_timer:
        update_match_timer(roundi(Globals.game_state.match_timer.time_left * 1000))
```

### 9.3 聊天系统

**Chat.gd:**

```gdscript
extends Control

@onready var chat_log: RichTextLabel = $ChatLog
@onready var input_field: LineEdit = $InputField

var message_history: Array[String] = []

func _input(event):
    if event.is_action_pressed("say_all"):
        open_chat(false)  # 全局聊天
    elif event.is_action_pressed("say_team"):
        open_chat(true)   # 队伍聊天

func open_chat(team_only: bool):
    show()
    input_field.show()
    input_field.grab_focus()

func _on_input_field_text_submitted(text: String):
    if text.is_empty():
        close_chat()
        return
    
    # 发送消息
    var team_only = input_field.placeholder_text.begins_with("Team")
    send_message.rpc(text, team_only)
    
    input_field.clear()
    close_chat()

@rpc("any_peer", "call_remote", "reliable")
func send_message(text: String, team_only: bool):
    var sender_id = multiplayer.get_remote_sender_id()
    display_message(sender_id, text, team_only)

func display_message(sender: String, text: String, team_only: bool):
    var color = "[color=#ffffff]" if not team_only else "[color=#00ff00]"
    chat_log.append_text(color + sender + ": " + text + "[/color]\n")
    chat_log.scroll_to_line(chat_log.get_line_count())
```

---

## 10. 武器系统

### 10.1 武器架构

Liblast 的武器系统采用继承层次结构:

```
Weapon (基类)
├── ShootingWeapon (射击武器)
│   ├── HitscanShootingWeapon (即时命中武器)
│   │   ├── Generic (通用武器)
│   │   └── AutomaticHitscanShootingWeapon (自动武器)
│   └── ProjectileShootingWeapon (投射物武器)
│       └── Plasma (等离子武器)
```

### 10.2 武器核心逻辑

**HitscanShootingWeapon.gd:**

```gdscript
extends "res://Assets/Weapons/WeaponTypes/ShootingWeapon/ShootingWeapon.gd"

@export var damage_amount: int = 25
@export var full_auto: bool = false

func shoot(from_barrel = barrel):
    # 检查是否可以射击
    if magazine.is_reloading:
        return
    if is_empty():
        reload_press()
        return
    if not from_barrel.can_shoot():
        return
    
    # 执行射击
    var shot = from_barrel.shoot()
    var hits = shot.hits
    var target = shot.targets[0]
    
    # 播放动画
    anim.play("Shoot")
    
    # 处理命中
    if not hits.is_empty():
        for hit in hits:
            if hit.collider is Character:
                deal_damage(hit)
            else:
                spawn_hit_effect(hit, 0)
    
    # 生成弹道追踪效果
    spawn_bullet_tracer(target)
    
    # 全自动模式
    if full_auto and primary_trigger_held and character.state.alive:
        await from_barrel.slide.slide_returned
        shoot(from_barrel)

func deal_damage(hit):
    var damage = damage_class.new()
    damage.attacker = character
    damage.attacker_pid = int(str(character.name))
    damage.hit_position = hit.position
    damage.damage_amount = damage_amount
    
    # 只有权威端处理伤害
    if multiplayer.has_multiplayer_peer():
        if character.is_multiplayer_authority():
            hit.collider.hurt.rpc(inst_to_dict(damage))
            hit.collider.hurt(damage)
    else:
        hit.collider.hurt(damage)

@rpc("call_remote", "any_peer", "reliable")
func trigger_primary_press():
    primary_trigger_held = true
    shoot($Barrels/Barrel1)

@rpc("call_remote", "any_peer", "reliable")
func trigger_primary_release():
    primary_trigger_held = false

@rpc("call_remote", "any_peer", "reliable")
func reload_press():
    if magazine.is_reloading:
        return
    if anim.is_playing():
        return
    
    for m in $Magazines.get_children():
        m.reload(anim.animation_finished)
    
    anim.play("Reload")
```

### 10.3 武器切换

**CharacterWeapons.gd:**

```gdscript
extends Node

var character: Character
var primary: Weapon
var secondary: Weapon
var tertiary: Weapon
var current_weapon: Weapon

func switch_weapon(slot: WeaponSlot):
    match slot:
        WeaponSlot.PRIMARY:
            current_weapon = primary
        WeaponSlot.SECONDARY:
            current_weapon = secondary
        WeaponSlot.TERTIARY:
            current_weapon = tertiary
    
    # 隐藏所有武器
    for weapon in [primary, secondary, tertiary]:
        if weapon:
            weapon.visible = false
    
    # 显示当前武器
    if current_weapon:
        current_weapon.visible = true

func _controller_event(event: CharCtrlEvent):
    if not current_weapon:
        return
    
    for change in event.control_changes:
        match change.control_type:
            Globals.CharCtrlType.TRIG_P:
                if change.enabled:
                    current_weapon.trigger_primary_press.rpc()
                else:
                    current_weapon.trigger_primary_release.rpc()
            
            Globals.CharCtrlType.WEPN_R:
                if change.changed and change.enabled:
                    current_weapon.reload_press.rpc()
            
            Globals.CharCtrlType.WEPN_1:
                if change.changed and change.enabled:
                    switch_weapon(WeaponSlot.PRIMARY)
```

---

*(教程继续...)*
