## 14. 配置与设置系统

### 14.1 设置存储

**设置文件位置:**
- Windows: `%APPDATA%/Godot/app_userdata/Liblast/settings/settings.liblast`
- Linux: `~/.local/share/godot/app_userdata/Liblast/settings/settings.liblast`
- macOS: `~/Library/Application Support/Godot/app_userdata/Liblast/settings/settings.liblast`

**设置文件格式:**
```gdscript
# settings.liblast (GDScript 字典格式)
{
    "display_fullscreen": true,
    "render_fov": 90,
    "input_mouse_sensitivity": 1.5,
    "audio_volume_sfx": -6.0
}
```

### 14.2 添加新设置

**步骤 1: 在 Settings.gd 中添加默认值**

```gdscript
const settings_default = {
    # ... 现有设置 ...
    'my_new_setting': false,  # 添加新设置
}
```

**步骤 2: 创建应用函数**

```gdscript
func apply_my_new_setting(value):
    if value:
        print("New setting enabled!")
    else:
        print("New setting disabled!")
```

**步骤 3: 在 UI 中添加控制**

```gdscript
# 在设置菜单中
var checkbox = $MyNewSettingCheckbox
checkbox.button_pressed = Settings.get_var("my_new_setting")
checkbox.toggled.connect(_on_my_new_setting_toggled)

func _on_my_new_setting_toggled(pressed):
    Settings.set_var("my_new_setting", pressed)
```

### 14.3 预设系统

**创建质量预设:**

```gdscript
# Settings.gd
enum EnviroQuality {VERY_LOW, LOW, MEDIUM, HIGH, VERY_HIGH, EXTREME}

var presets = {
    "very_low": {
        "render_enviro_quality": EnviroQuality.VERY_LOW,
        "render_scale": 0.5,
        "render_particles_amount": 0.25,
        "render_refprobes": false,
    },
    "low": {
        "render_enviro_quality": EnviroQuality.LOW,
        "render_scale": 0.75,
        "render_particles_amount": 0.5,
        "render_refprobes": false,
    },
    "medium": {
        "render_enviro_quality": EnviroQuality.MEDIUM,
        "render_scale": 1.0,
        "render_particles_amount": 1.0,
        "render_refprobes": true,
    },
    "high": {
        "render_enviro_quality": EnviroQuality.HIGH,
        "render_scale": 1.0,
        "render_particles_amount": 1.5,
        "render_refprobes": true,
    },
}

func load_preset(preset_name: String):
    if presets.has(preset_name):
        for key in presets[preset_name].keys():
            set_var(key, presets[preset_name][key])
```

---

## 15. 二次开发指南

### 15.1 添加新武器

**步骤 1: 创建武器场景**

1. 创建新场景,根节点为 `Node3D`
2. 添加武器模型 (`MeshInstance3D`)
3. 添加枪管节点 (`Node3D`,命名为 "Barrels")
4. 添加弹匣节点 (使用 Magazine 场景)
5. 添加动画播放器 (`AnimationPlayer`)
6. 保存为 `res://Assets/Weapons/WeaponTypes/YourWeapon/YourWeapon.tscn`

**步骤 2: 创建武器脚本**

```gdscript
# YourWeapon.gd
extends "res://Assets/Weapons/WeaponTypes/ShootingWeapon/ShootingWeapon.gd"

@export var damage_amount: int = 50
@export var fire_rate: float = 0.5  # 射击间隔(秒)
@export var spread: float = 2.0  # 散布角度

var last_shot_time: float = 0

func shoot(from_barrel = barrel):
    # 检查射速限制
    var current_time = Time.get_ticks_msec() / 1000.0
    if current_time - last_shot_time < fire_rate:
        return
    
    # 调用父类射击方法
    super.shoot(from_barrel)
    
    last_shot_time = current_time

func calculate_spread():
    # 自定义散布计算
    return Vector3(
        randf_range(-spread, spread),
        randf_range(-spread, spread),
        0
    )
```

**步骤 3: 注册武器类型**

```gdscript
# Weapons.gd
enum Weapon {
    NONE = -1,
    GENERIC = 1,
    HITSCAN = 2,
    AUTOMATIC = 3,
    PLASMA = 4,
    YOUR_WEAPON = 5,  # 添加新武器
}

const WeaponScenePaths = {
    Weapon.NONE: null,
    Weapon.GENERIC: "res://Assets/Weapons/WeaponTypes/Generic/Weapon.tscn",
    # ... 其他武器 ...
    Weapon.YOUR_WEAPON: "res://Assets/Weapons/WeaponTypes/YourWeapon/YourWeapon.tscn",
}
```

**步骤 4: 添加到角色装备**

```gdscript
# CharacterWeapons.gd
func _ready():
    equip_weapon(WeaponSlot.PRIMARY, Weapon.YOUR_WEAPON)
```

### 15.2 创建新游戏模式

**步骤 1: 添加游戏模式枚举**

```gdscript
# Globals.gd
enum GameMode {
    CONTROL_POINTS,
    DUEL,
    CAMPAIGN,
    DEATHMATCH,
    TEAM_DEATHMATCH,
    KING_OF_THE_HILL,
    FRIDGE_STACKING,
    YOUR_MODE,  # 添加新模式
}
```

**步骤 2: 创建游戏模式逻辑**

```gdscript
# YourGameMode.gd
extends Node

signal mode_ended(winner_team: int)

var game_state: GameState

func _ready():
    game_state = Globals.game_state
    
    # 连接信号
    game_state.match_started.connect(_on_match_started)
    game_state.match_ended.connect(_on_match_ended)

func _on_match_started():
    print("Your game mode started!")
    # 初始化游戏模式特定逻辑

func check_win_condition():
    # 实现你的胜利条件
    if some_condition:
        mode_ended.emit(winning_team)

func process_game_logic(delta):
    # 每帧处理游戏逻辑
    pass
```

**步骤 3: 在 GameState 中集成**

```gdscript
# GameState.gd
func start_match():
    match MultiplayerState.game_config.game_mode:
        Globals.GameMode.TEAM_DEATHMATCH:
            setup_team_deathmatch()
        Globals.GameMode.CONTROL_POINTS:
            setup_control_points()
        Globals.GameMode.YOUR_MODE:
            setup_your_mode()

func setup_your_mode():
    var mode_script = preload("res://Assets/Game/YourGameMode.gd").instantiate()
    add_child(mode_script)
    mode_script.mode_ended.connect(end_match)
```

### 15.3 添加新角色能力

**步骤 1: 扩展 CharMovement**

```gdscript
# CharMovementType2.gd (继承自 CharMovementType1)
extends CharMovementType1

const DASH_SPEED = 20.0
const DASH_DURATION = 0.3
const DASH_COOLDOWN = 2.0

var can_dash: bool = true
var is_dashing: bool = false
var dash_timer: float = 0

func process(delta: float):
    super.process(delta)
    
    # 处理冲刺
    if is_dashing:
        dash_timer -= delta
        if dash_timer <= 0:
            is_dashing = false
            can_dash = false
            
            # 开始冷却
            get_tree().create_timer(DASH_COOLDOWN).timeout.connect(func(): can_dash = true)
    
    # 检测冲刺输入
    if character.controls[Globals.CharCtrlType.MOVE_S].changed and \
       character.controls[Globals.CharCtrlType.MOVE_S].enabled and \
       can_dash and not is_dashing:
        start_dash()

func start_dash():
    is_dashing = true
    dash_timer = DASH_DURATION
    
    # 获取朝向
    var direction = character.global_transform.basis.z.normalized()
    
    # 应用冲刺速度
    character.velocity = direction * DASH_SPEED
    
    # 播放特效
    play_dash_effect()

func play_dash_effect():
    var particles = preload("res://Assets/Effects/DashEffect.tscn").instantiate()
    character.add_child(particles)
    particles.emitting = true
```

**步骤 2: 应用到角色**

```gdscript
# Character.gd
@export var movement_type: int = 1  # 1 = Type1, 2 = Type2

func _ready():
    match movement_type:
        1:
            movement = CharMovementType1.new()
        2:
            movement = CharMovementType2.new()
    
    movement.character = self
    add_child(movement)
```

### 15.4 创建自定义地图组件

**示例: 移动平台**

```gdscript
# MovingPlatform.gd
extends AnimatableBody3D

@export var move_distance: Vector3 = Vector3(0, 5, 0)
@export var move_duration: float = 3.0
@export var wait_duration: float = 1.0
@export var auto_start: bool = true

var start_position: Vector3
var moving_up: bool = true
var timer: float = 0

func _ready():
    start_position = global_position
    
    if auto_start:
        start_moving()

func start_moving():
    set_physics_process(true)

func _physics_process(delta):
    timer += delta
    
    if timer < move_duration:
        # 移动阶段
        var progress = timer / move_duration
        if moving_up:
            global_position = start_position + move_distance * progress
        else:
            global_position = start_position + move_distance * (1 - progress)
    elif timer < move_duration + wait_duration:
        # 等待阶段
        pass
    else:
        # 切换方向
        moving_up = !moving_up
        timer = 0
```

**使用组件:**

1. 在地图场景中实例化 `MovingPlatform.tscn`
2. 在编辑器中配置参数
3. 运行游戏测试

### 15.5 Mod 支持

**创建 Mod 加载器:**

```gdscript
# ModLoader.gd
extends Node

var loaded_mods: Array = []

func _ready():
    scan_for_mods()

func scan_for_mods():
    var mods_dir = "user://mods/"
    
    if not DirAccess.dir_exists_absolute(mods_dir):
        DirAccess.make_dir_recursive_absolute(mods_dir)
        return
    
    var dir = DirAccess.open(mods_dir)
    if dir:
        dir.list_dir_begin()
        var mod_name = dir.get_next()
        
        while mod_name != "":
            if dir.current_is_dir():
                load_mod(mods_dir.path_join(mod_name))
            mod_name = dir.get_next()

func load_mod(mod_path: String):
    var config_path = mod_path.path_join("mod.cfg")
    
    if not FileAccess.file_exists(config_path):
        printerr("Mod ", mod_path, " missing mod.cfg")
        return
    
    var config = ConfigFile.new()
    var err = config.load(config_path)
    
    if err != OK:
        printerr("Failed to load mod config: ", error_string(err))
        return
    
    var mod_info = {
        "name": config.get_value("mod", "name", "Unknown"),
        "version": config.get_value("mod", "version", "1.0"),
        "path": mod_path,
    }
    
    print("Loading mod: ", mod_info.name, " v", mod_info.version)
    loaded_mods.append(mod_info)
    
    # 加载 mod 脚本
    var script_path = mod_path.path_join("main.gd")
    if FileAccess.file_exists(script_path):
        var script = load(script_path)
        if script:
            var instance = script.new()
            add_child(instance)
```

**Mod 配置文件示例:**

```ini
# mod.cfg
[mod]
name="Custom Weapons Pack"
version="1.0"
author="Your Name"
description="Adds new weapons to the game"
```

---

## 16. 常见问题与调试

### 16.1 调试工具

**启用调试输出:**

```gdscript
# 在任何脚本中
print("Debug message")
printerr("Error message")
push_warning("Warning message")

# 打印变量
var health = 100
print("Health: ", health)
prints("Health:", health)  # 自动添加空格
printt("Health:", health)  # 制表符分隔
```

**使用 Logger 单例:**

```gdscript
# Logger.gd
func event(data: Array):
    var timestamp = Time.get_datetime_string_from_system()
    var message = str(timestamp, " - ", data)
    print(message)
    
    # 可选:写入日志文件
    if log_file:
        log_file.store_line(message)
```

**性能监控:**

```gdscript
# PerformanceMonitor.gd
func _process(delta):
    var fps = Engine.get_frames_per_second()
    var frame_time = Engine.get_process_frames()
    
    print("FPS: ", fps, " Frame time: ", frame_time, "ms")
    
    # 内存使用
    var memory = OS.get_static_memory_usage()
    print("Memory: ", memory / 1024 / 1024, " MB")
```

### 16.2 常见错误及解决方案

**错误 1: 节点未找到**

```
ERROR: Node not found: "SomeNode"
```

**解决方案:**
```gdscript
# 检查节点路径是否正确
if has_node("SomeNode"):
    var node = get_node("SomeNode")
else:
    printerr("SomeNode not found!")

# 使用 @onready 确保节点已加载
@onready var some_node = $SomeNode
```

**错误 2: 空引用**

```
ERROR: Attempt to call function 'xxx' on a null value
```

**解决方案:**
```gdscript
# 检查对象是否有效
if is_instance_valid(some_object):
    some_object.some_function()
else:
    printerr("Object is null or freed!")

# 使用断言
assert(some_object != null, "some_object should not be null")
```

**错误 3: RPC 失败**

```
ERROR: RPC failed - no multiplayer peer
```

**解决方案:**
```gdscript
# 检查是否有多人游戏对等方
if multiplayer.has_multiplayer_peer():
    some_rpc.rpc()
else:
    # 本地调用
    some_rpc()
```

**错误 4: 资源加载失败**

```
ERROR: Failed to load resource: res://...
```

**解决方案:**
```gdscript
# 检查文件是否存在
if ResourceLoader.exists("res://path/to/resource.tscn"):
    var resource = load("res://path/to/resource.tscn")
else:
    printerr("Resource does not exist!")

# 使用 preload 在编译时检查
const MY_RESOURCE = preload("res://path/to/resource.tscn")
```

### 16.3 网络调试

**监控网络状态:**

```gdscript
# 显示网络统计
func _process(delta):
    if multiplayer.has_multiplayer_peer():
        var peer = MultiplayerState.peer
        
        for pid in peer.get_peers():
            var enet_peer = peer.get_peer(pid)
            var ping = enet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
            var packet_loss = enet_peer.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS)
            
            print("PID ", pid, " - Ping: ", ping, "ms, Loss: ", packet_loss, "%")
```

**调试 RPC 调用:**

```gdscript
@rpc("any_peer", "call_remote", "reliable")
func debug_rpc(data):
    var sender = multiplayer.get_remote_sender_id()
    print("RPC received from PID ", sender, ": ", data)
```

### 16.4 性能优化建议

**1. 减少 Draw Calls**

```gdscript
# 使用相同的材质
var shared_material = preload("res://Materials/SharedMaterial.tres")

for mesh in meshes:
    mesh.material_override = shared_material
```

**2. 对象池**

```gdscript
# ObjectPool.gd
extends Node

var pool: Array = []
var scene: PackedScene

func initialize(scene_path: String, initial_size: int = 10):
    scene = load(scene_path)
    
    for i in range(initial_size):
        var instance = scene.instantiate()
        instance.visible = false
        add_child(instance)
        pool.append(instance)

func get_instance():
    for instance in pool:
        if not instance.visible:
            instance.visible = true
            return instance
    
    # 池为空,创建新实例
    var instance = scene.instantiate()
    add_child(instance)
    pool.append(instance)
    return instance

func return_instance(instance):
    instance.visible = false
```

**3. 异步加载**

```gdscript
# 使用线程加载大资源
func load_map_async(map_path: String):
    ResourceLoader.load_threaded_request(map_path)
    
    while true:
        var status = ResourceLoader.load_threaded_get_status(map_path)
        
        if status == ResourceLoader.THREAD_LOAD_LOADED:
            var scene = ResourceLoader.load_threaded_get(map_path)
            return scene.instantiate()
        elif status == ResourceLoader.THREAD_LOAD_FAILED:
            push_error("Failed to load map")
            return null
        
        await get_tree().process_frame
```

**4. 限制粒子数量**

```gdscript
# 根据设置调整粒子数量
func update_particle_effects(root: Node):
    for child in root.get_children():
        if child is GPUParticles3D or child is CPUParticles3D:
            child.amount = max(1, round(child.amount * 
                Settings.get_var("render_particles_amount")))
```

### 16.5 测试建议

**自动化测试:**

```gdscript
# AutomatedTests/TestCharacter.gd
extends Node

func _ready():
    test_character_spawn()
    test_character_movement()
    test_character_damage()

func test_character_spawn():
    var character_scene = preload("res://Assets/Characters/Character.tscn")
    var character = character_scene.instantiate()
    
    assert(character != null, "Character should spawn")
    assert(character.state != null, "Character should have state")
    assert(character.state.health == 100, "Character should start with 100 HP")
    
    print("✓ Character spawn test passed")
    character.queue_free()

func test_character_movement():
    var character = create_test_character()
    
    # 模拟输入
    character.controls[Globals.CharCtrlType.MOVE_F].enabled = true
    
    # 运行一帧
    await get_tree().process_frame
    
    assert(character.velocity.length() > 0, "Character should move")
    
    print("✓ Character movement test passed")
    character.queue_free()

func test_character_damage():
    var character = create_test_character()
    
    # 应用伤害
    var damage = DamageAttack.new()
    damage.damage_amount = 50
    damage.attacker = character
    
    character.hurt(damage)
    
    assert(character.state.health == 50, "Character should have 50 HP after damage")
    
    print("✓ Character damage test passed")
    character.queue_free()

func create_test_character():
    var character_scene = preload("res://Assets/Characters/Character.tscn")
    var character = character_scene.instantiate()
    get_tree().root.add_child(character)
    return character
```

---

## 结语

恭喜你完成了 Liblast Legacy 的系统教程!现在你应该:

✅ 理解项目的整体架构和核心系统
✅ 掌握 Godot 4 的基本概念和 GDScript 编程
✅ 了解多人游戏网络同步的原理
✅ 能够创建新的武器、地图和游戏模式
✅ 知道如何调试和优化性能
✅ 具备二次开发的能力

### 下一步学习建议

1. **实践项目**
   - 尝试创建一个简单的武器
   - 设计一个小型测试地图
   - 修改现有的游戏模式

2. **深入阅读代码**
   - 仔细阅读 `Character.gd` 的完整实现
   - 研究 `GameState.gd` 的游戏流程管理
   - 分析网络同步的具体实现

3. **参与社区**
   - 加入 Liblast 的开发社区
   - 查看 GitHub/Codeberg 上的 issue 和 PR
   - 贡献代码或提出改进建议

4. **学习资源**
   - Godot 官方文档: https://docs.godotengine.org/
   - Godot 社区论坛
   - YouTube 上的 Godot 教程

祝你开发愉快!🎮
