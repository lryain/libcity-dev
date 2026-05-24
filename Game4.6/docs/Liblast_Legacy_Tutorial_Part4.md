## 11. 地图与关卡设计

### 11.1 地图结构

Liblast 的地图基于 Godot 场景系统,每个地图都是一个独立的 `.tscn` 文件。

**地图基本结构:**

```
Map.tscn (根节点)
├── StaticGeometry (静态几何体)
│   ├── Walls (墙体)
│   ├── Floors (地板)
│   └── Props (道具)
├── SpawnPoints (出生点容器)
│   ├── SpawnPoint1 (出生点1)
│   ├── SpawnPoint2 (出生点2)
│   └── ...
├── ControlPoints (据点 - 可选)
│   ├── CP1 (据点1)
│   └── CP2 (据点2)
├── Lighting (光照)
│   ├── DirectionalLight (方向光)
│   └── ReflectionProbes (反射探针)
├── Music (音乐)
└── MapScript.gd (地图脚本)
```

### 11.2 创建新地图

**步骤 1: 创建基础场景**

1. 在 Godot 编辑器中创建新场景
2. 添加 `Node3D` 作为根节点
3. 附加 `Map.gd` 脚本
4. 保存为 `res://Assets/Maps/YourMap.tscn`

**步骤 2: 添加静态几何体**

```gdscript
# 使用 Blender 或其他 3D 软件创建模型
# 导出为 GLTF/GLB 格式
# 导入到 Godot 并添加到场景中

# 或者使用 Godot 内置工具创建简单几何体
var mesh = BoxMesh.new()
mesh.size = Vector3(10, 1, 10)

var mesh_instance = MeshInstance3D.new()
mesh_instance.mesh = mesh
add_child(mesh_instance)
```

**步骤 3: 设置碰撞**

```gdscript
# 为静态物体添加碰撞
var static_body = StaticBody3D.new()
var collision_shape = CollisionShape3D.new()
collision_shape.shape = BoxShape3D.new()
collision_shape.shape.size = Vector3(10, 1, 10)

static_body.add_child(collision_shape)
add_child(static_body)
```

**步骤 4: 添加出生点**

```gdscript
# 创建出生点容器
var spawn_points = Node3D.new()
spawn_points.name = "SpawnPoints"
add_child(spawn_points)

# 添加出生点
for i in range(8):
    var spawn_point = preload("res://Assets/MapComponents/SpawnPoint.tscn").instantiate()
    spawn_point.position = Vector3(randf_range(-20, 20), 0, randf_range(-20, 20))
    spawn_point.team = 0  # 0 = 所有队伍, 1 = LIME, 2 = PLUM
    spawn_points.add_child(spawn_point)
```

**步骤 5: 配置光照**

```gdscript
# 添加方向光(太阳光)
var sun = DirectionalLight3D.new()
sun.shadow_enabled = true
sun.shadow_bias = 0.05
sun.rotation_degrees = Vector3(-45, 45, 0)
add_child(sun)

# 添加环境光
var environment = Environment.new()
environment.background_mode = Environment.BG_COLOR
environment.background_color = Color(0.1, 0.1, 0.15)
get_viewport().world_3d.environment = environment
```

### 11.3 地图脚本

**Map.gd 核心功能:**

```gdscript
@tool
extends Node3D

@onready var spawnpoints = $SpawnPoints
@export var overview_camera: Camera3D

signal map_ready
var map_is_ready := false

func _ready():
    if Engine.is_editor_hint():
        return
    
    # 使概览相机成为当前相机
    overview_camera.make_current()
    
    # 更新反射探针
    if Settings.get_var(&"render_refprobes") == true:
        set_reflection_probe_render_layers(1 + 2 + 4)
        await _reflection_probes_updated
    
    map_is_ready = true
    map_ready.emit()

func start_match():
    randomize()

func get_spawn_transform(for_team: int = 0) -> Transform3D:
    var shuffled_spawnpoints = spawnpoints.get_children()
    shuffled_spawnpoints.shuffle()
    
    for i in shuffled_spawnpoints:
        if i.is_free and i.team != 3:  # 检查是否可用
            if i.team == for_team or i.team == 0 or for_team == 0:
                return i.global_transform
    
    push_error("Map found no free spawnpoints! Choosing a random one...")
    return spawnpoints.get_children().pick_random().global_transform
```

### 11.4 出生点系统

**SpawnPoint.gd:**

```gdscript
extends Node3D

@export var team: int = 0  # 0 = 所有队伍, 1 = LIME, 2 = PLUM, 3 = 禁用
var is_free: bool = true

func _ready():
    # 可视化出生点(仅编辑器)
    if Engine.is_editor_hint():
        var marker = Marker3D.new()
        add_child(marker)
```

**使用出生点:**

```gdscript
# GameState.gd
func get_spawn_transform(for_team: int = 0) -> Transform3D:
    if is_instance_valid(map):
        return map.get_spawn_transform(for_team)
    else:
        printerr("GameState spawning character before the map is spawned!")
        return Transform3D.IDENTITY
```

### 11.5 据点组件

**ControlPoint.gd (已在第6章详细介绍):**

```gdscript
class_name ControlPoint extends Node3D

var team: Teams = Teams.NONE

func check_for_capture():
    # 检测哪个队伍在据点内
    # 如果只有一个队伍,则占领
    # 每秒为占领队伍增加分数
```

### 11.6 地图优化技巧

**性能优化:**

1. **使用 LOD (Level of Detail)**
   ```gdscript
   # 为复杂模型设置 LOD
   mesh_instance.lod_min_distance = 10
   mesh_instance.lod_max_distance = 50
   ```

2. **遮挡剔除**
   ```gdscript
   # 启用遮挡剔除
   geometry_instance.use_occlusion_culling = true
   ```

3. **合批渲染**
   ```gdscript
   # 使用相同的材质以启用合批
   mesh_instance.material_override = shared_material
   ```

4. **光照烘焙**
   ```gdscript
   # 在 Blender 中烘焙光照贴图
   # 或使用 Godot 的光照烘焙系统
   lightmap_gi.bake()
   ```

---

## 12. 角色系统

### 12.1 角色架构

Character 是 Liblast 中最复杂的类,包含以下子系统:

```
Character (CharacterBody3D)
├── Movement System (移动系统)
│   ├── CharMovementType1
│   └── Physics
├── Weapon System (武器系统)
│   ├── CharacterWeapons
│   └── Weapon instances
├── Visual System (视觉系统)
│   ├── 3D Model (3D 模型)
│   ├── Face Expression (面部表情)
│   ├── Banner (头顶标识)
│   └── Effects (特效)
├── Audio System (音频系统)
│   ├── Voice (语音)
│   ├── Footsteps (脚步声)
│   └── Jetpack (喷气背包)
├── Camera System (相机系统)
│   ├── First Person (第一人称)
│   ├── Third Person (第三人称)
│   └── Death Camera (死亡相机)
└── Network System (网络系统)
    ├── State Synchronization
    └── RPC handlers
```

### 12.2 角色状态管理

**CharacterState.gd:**

```gdscript
class_name CharacterState
extends Resource

@export var health: int = 100
@export var max_health: int = 100
@export var alive: bool = true
@export var team: int = 0
@export var kills: int = 0
@export var deaths: int = 0
@export var spawn_time: float = 0
@export var ping: int = 0
@export var packet_loss: int = 0
```

**状态更新:**

```gdscript
# Character.gd
func update_state():
    # 更新生命值
    if state.health <= 0 and state.alive:
        die(last_damage)
    
    # 更新击杀/死亡统计
    if state.kills > previous_kills:
        play_kill_effect()
    
    # 同步到网络
    if multiplayer.is_server():
        sync_state.rpc(state)
```

### 12.3 面部表情系统

**CharacterFaceExpression 枚举:**

```gdscript
enum CharacterFaceExpression { 
    NEUTRAL,   # 中性
    ATTACK,    # 攻击
    HURT,      # 受伤
    DEAD,      # 死亡
    KILL,      # 击杀
    LOOSE,     # 失败
    WIN,       # 胜利
    WINK       # 眨眼
}
```

**设置表情:**

```gdscript
# Character.gd
func set_face_expression(expression: CharacterFaceExpression, expiration_time: float = 1.5):
    if MultiplayerState.role == MultiplayerRole.DEDICATED_SERVER:
        return  # 专用服务器跳过视觉效果
    
    if not state.alive:
        return  # 死亡时不能改变表情
    
    # 设置着色器中的表情
    face_mesh.set(&"shader_uniforms/FaceExpression", expression)
    
    # 安排重置为默认表情
    if expiration_time > 0:
        if face_expression_tween:
            face_expression_tween.kill()
        
        face_expression_tween = create_tween()
        face_expression_tween.tween_interval(expiration_time)
        face_expression_tween.tween_property(face_mesh, 
            "shader_uniforms/FaceExpression",
            CharacterFaceExpression.NEUTRAL, 0)
        face_expression_tween.play()
```

**使用示例:**

```gdscript
# 受伤时
set_face_expression(CharacterFaceExpression.HURT, 2.0)

# 击杀时
set_face_expression(CharacterFaceExpression.KILL, 3.0)

# 死亡时
set_face_expression(CharacterFaceExpression.DEAD, 0)  # 不自动重置
```

### 12.4 头顶标识系统

**CharacterBannerStatus 枚举:**

```gdscript
enum CharacterBannerStatus { 
    NONE = -1,     # 无
    CHAT,          # 聊天中
    MENU,          # 菜单中
    IDLE,          # 空闲
    LAG,           # 延迟高
    ZOOM,          # 瞄准中
    SAME_TEAM      # 队友
}
```

**设置标识状态:**

```gdscript
# Character.gd
@rpc("call_remote", "any_peer", "reliable")
func set_banner_status(status: CharacterBannerStatus):
    if banner_status.frame == status and banner_status.visible:
        return
    
    if status == CharacterBannerStatus.NONE:
        banner_status.visible = false
    else:
        banner_status.visible = true
        banner_status.frame = status
```

**自动显示空闲状态:**

```gdscript
func check_idle():
    idle_time += delta
    
    if idle_time >= IDLE_TIME_THRESHOLD:
        if not banner_status.visible:
            set_banner_status(CharacterBannerStatus.IDLE)
    
    if idle_time < IDLE_TIME_THRESHOLD:
        if banner_status.frame == CharacterBannerStatus.IDLE:
            set_banner_status(CharacterBannerStatus.NONE)
```

### 12.5 相机系统

**相机类型:**

```gdscript
enum CharacterCurrentCamera {
    FIRST_PERSON,   # 第一人称
    THIRD_PERSON,   # 第三人称
    DEATH           # 死亡相机
}
```

**切换相机:**

```gdscript
# Character.gd
func update_camera():
    match current_camera:
        CharacterCurrentCamera.FIRST_PERSON:
            models3rdPerson.hide()
            models.show()
            banner.hide()
            face_light.hide()
            face_light_1st_person.show()
        
        CharacterCurrentCamera.THIRD_PERSON:
            models3rdPerson.show()
            models.hide()
            banner.show()
            face_light.show()
            face_light_1st_person.hide()
        
        CharacterCurrentCamera.DEATH:
            models3rdPerson.show()
            models.hide()
            banner.show()
    
    cameras[current_camera].make_current()
```

**缩放功能:**

```gdscript
func process_view_zoom(delta: float):
    var base_fov = profile.fov if profile else 90.0
    var target_fov = base_fov / ZOOM_FACTOR
    
    # 处理缩放输入
    if controls[Globals.CharCtrlType.V_ZOOM].enabled:
        zoom_velocity = minf(zoom_velocity + delta * ZOOM_VELOCITY_RATE, 1.0)
    else:
        zoom_velocity = maxf(zoom_velocity - delta * ZOOM_VELOCITY_RATE, -1.0)
    
    zoom_amount += delta * ZOOM_SPEED * zoom_velocity
    zoom_amount = clamp(zoom_amount, 0.0, 1.0)
    
    # 应用 FOV
    var factor = smoothstep(0, 1, zoom_amount)
    camera.fov = lerpf(base_fov, target_fov, factor)
    
    # 缩放时禁用武器
    if zoom_amount > 0:
        is_armed = false
        set_banner_status(CharacterBannerStatus.ZOOM)
    else:
        is_armed = true
        set_banner_status(CharacterBannerStatus.NONE)
```

### 12.6 角色配置文件

**CharacterProfile.gd:**

```gdscript
class_name CharacterProfile
extends Resource

@export var display_name: String = "Player"
@export var display_color: Color = Color.WHITE
@export var voice_pitch: float = 1.0
@export var fov: int = 90
@export var badges: Array[Badges.Badge] = []

func _init():
    display_name = "Player"
    display_color = Color.WHITE
    voice_pitch = 1.0
    fov = 90
    badges = []
```

**应用配置文件:**

```gdscript
# Character.gd
func apply_profile():
    if not is_instance_valid(profile):
        return
    
    # 应用 FOV
    profile.fov = Settings.get_var("render_fov")
    update_camera_fov()
    
    # 应用语音音调
    mouth.pitch_scale = profile.voice_pitch
    
    # 应用颜色
    if profile.display_color:
        body_mesh.set_instance_shader_parameter("body_color", profile.display_color)
        hands_mesh.set_instance_shader_parameter("body_color", profile.display_color)
    
    # 应用名称
    if profile.display_name:
        banner.get_node("NameTag").text = profile.display_name
    
    # 应用徽章
    banner.get_node("Badge").texture = Badges.get_top_priority_badge_texture(profile.badges)
```

---

## 13. 音效与视觉效果

### 13.1 音频系统

**音频总线布局:**

```
Master (总线 0)
├── Music (总线 1) - 背景音乐
├── SFX (总线 2) - 音效
└── UI (总线 3) - 界面音效
```

**音量控制:**

```gdscript
# Settings.gd
func apply_audio_volume_master(value):
    AudioServer.set_bus_volume_db(0, value)

func apply_audio_volume_music(value):
    AudioServer.set_bus_volume_db(1, value)

func apply_audio_volume_sfx(value):
    AudioServer.set_bus_volume_db(2, value)

func apply_audio_volume_ui(value):
    AudioServer.set_bus_volume_db(3, value)
```

**播放音效:**

```gdscript
# Character.gd
func say_random_taunt(taunts: Array[AudioStream], probability: float = 1.0):
    if MultiplayerState.role == MultiplayerRole.DEDICATED_SERVER:
        return
    
    if randf() > probability:
        return
    
    mouth.stream = taunts[randi() % taunts.size()]
    get_tree().create_timer(randf_range(0.4, 0.8)).timeout.connect(mouth.play)

# 播放受伤声音
if not mouth.playing:
    mouth.stream = voice.hurt
    mouth.play()
```

**3D 音频:**

```gdscript
# 创建 3D 音频播放器
var audio_player = AudioStreamPlayer3D.new()
audio_player.stream = load("res://Assets/SFX/explosion.wav")
audio_player.position = explosion_position
audio_player.max_distance = 50.0
audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE

add_child(audio_player)
audio_player.play()
```

### 13.2 粒子系统

**生成粒子效果:**

```gdscript
# Character.gd - 重生特效
func spawn_fx():
    if MultiplayerState.role == MultiplayerRole.DEDICATED_SERVER:
        return
    
    $SpawnFX/SpawnVFX.emitting = false
    $SpawnFX/SpawnVFX2.emitting = false
    
    $SpawnFX/SpawnSFX.play()
    $SpawnFX/SpawnVFX.emitting = true
    $SpawnFX/SpawnVFX2.emitting = true
    $SpawnFX/SpawnLight.play(&"Spawn")
```

**肢解特效:**

```gdscript
func gib():
    hide()
    is_gibbed = true
    
    if MultiplayerState.role == MultiplayerRole.DEDICATED_SERVER:
        return
    
    # 生成肢解特效
    var gib_fx = preload("res://Assets/Effects/Gibbing.tscn").instantiate()
    Globals.get_spawn_root().add_child(gib_fx)
    gib_fx.global_position = $Gibs.global_position
    gib_fx.show()
    
    # 生成肢体碎片
    if Settings.get_var(&"render_gibs"):
        var gib_scene = preload("res://Assets/Characters/CharacterGib.tscn")
        
        for i in range(10):
            var gib = gib_scene.instantiate()
            gib.global_position = $Gibs.global_position + \
                Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.5
            gib.apply_central_impulse(
                velocity + Vector3(randf(), randf(), randf()).normalized() * 25
            )
            Globals.get_spawn_root().add_child(gib)
```

### 13.3 相机震动

**震动源管理:**

```gdscript
# Character.gd
var rumble_sources = {}

@rpc("call_remote", "any_peer", "unreliable")
func set_rumble_source(source_id, rumble):
    rumble_sources[source_id] = {
        "amount": rumble.amount,
        "decay": rumble.decay,
        "attack": rumble.attack,
        "factor": 0.0,
        "stage": 0,
    }

func process_rumble(delta: float):
    var erase_queue = []
    camera_shake_rumble.shake_amount = 0
    
    for i in rumble_sources.keys():
        match rumble_sources[i].stage:
            0: rumble_sources[i].factor = move_toward(
                rumble_sources[i].factor, 1, delta * rumble_sources[i].attack)
            1: rumble_sources[i].factor = move_toward(
                rumble_sources[i].factor, 0, delta * rumble_sources[i].decay)
        
        # 从攻击阶段转换到衰减阶段
        if is_equal_approx(rumble_sources[i].factor, 1) and \
           rumble_sources[i].stage == 0:
            rumble_sources[i].stage = 1
        
        # 应用震动
        camera_shake_rumble.shake_amount += \
            rumble_sources[i].amount * rumble_sources[i].factor
        
        # 检查是否结束
        if rumble_sources[i].factor <= 0 and rumble_sources[i].stage == 1:
            erase_queue.append(i)
    
    # 删除结束的震动源
    for i in erase_queue:
        rumble_sources.erase(i)
    
    camera_shake_rumble.shake_amount = clamp(camera_shake_rumble.shake_amount, 0, 1)
```

**受伤震动:**

```gdscript
# HUD.gd
func damage(hp):
    pain += hp / 20
    
    # 触发相机震动
    if Globals.current_character:
        Globals.current_character.camera_shake_damage.shake_amount += hp / 100.0
```

### 13.4 后期处理效果

**死亡效果:**

```gdscript
# HUD.gd
func character_hud_update(update: CharHudUpdate):
    if update.got_killed:
        environment = get_viewport().find_world_3d().environment
        if environment:
            environment.adjustment_enabled = true
            environment.adjustment_saturation = 0.2
            environment.adjustment_brightness = 1.3
            environment.adjustment_contrast = 1.3
    
    elif update.got_spawned and environment:
        environment.adjustment_enabled = false
```

**瞄准 vignette 效果:**

```gdscript
func character_hud_update(update: CharHudUpdate):
    if update.zoom:
        if update.zoom_amount > 0:
            $Overlays/Vignette.modulate = Color(Color.WHITE, 
                smoothstep(0, 1, update.zoom_amount))
        else:
            $Overlays/Vignette.modulate = Color(Color.WHITE, 0)
```

---

*(教程继续...)*
