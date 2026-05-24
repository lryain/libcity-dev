# Liblast Legacy 快速参考手册

## 常用命令和代码片段

### 场景管理

```gdscript
# 加载场景
var scene = preload("res://path/to/scene.tscn")
var instance = scene.instantiate()
add_child(instance)

# 异步加载
ResourceLoader.load_threaded_request("res://path/to/scene.tscn")
var status = ResourceLoader.load_threaded_get_status(path)
if status == ResourceLoader.THREAD_LOAD_LOADED:
    var scene = ResourceLoader.load_threaded_get(path)
```

### 节点操作

```gdscript
# 获取子节点
var node = $NodeName
var node = get_node("NodeName")
var node = get_node_or_null("NodeName")

# 检查节点存在
if has_node("NodeName"):
    var node = get_node("NodeName")

# 添加/移除节点
add_child(node)
remove_child(node)
node.queue_free()

# 等待节点就绪
await node.ready
```

### 信号连接

```gdscript
# 定义信号
signal my_signal(value: int)

# 发射信号
my_signal.emit(42)
emit_signal("my_signal", 42)

# 连接信号
node.my_signal.connect(_on_my_signal)

# 断开信号
node.my_signal.disconnect(_on_my_signal)

# 信号处理函数
func _on_my_signal(value: int):
    print("Received: ", value)
```

### 输入处理

```gdscript
# 键盘输入
func _input(event):
    if event is InputEventKey:
        if event.pressed and event.keycode == KEY_SPACE:
            print("Space pressed")

# 动作输入
func _physics_process(delta):
    if Input.is_action_pressed("move_forward"):
        velocity.z -= speed
    
    if Input.is_action_just_pressed("jump"):
        velocity.y = jump_force

# 鼠标输入
func _input(event):
    if event is InputEventMouseMotion:
        rotation.y += -event.relative.x * sensitivity
```

### 物理移动

```gdscript
# CharacterBody3D 移动
extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const GRAVITY = 9.8

func _physics_process(delta):
    # 应用重力
    if not is_on_floor():
        velocity.y -= GRAVITY * delta
    
    # 获取输入方向
    var direction = Input.get_vector("move_left", "move_right", 
                                     "move_forward", "move_backward")
    
    # 移动
    if direction:
        velocity.x = direction.x * SPEED
        velocity.z = direction.z * SPEED
    else:
        velocity.x = move_toward(velocity.x, 0, SPEED)
        velocity.z = move_toward(velocity.z, 0, SPEED)
    
    # 跳跃
    if Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = JUMP_VELOCITY
    
    move_and_slide()
```

### RPC 网络调用

```gdscript
# 定义 RPC
@rpc("authority", "call_remote", "reliable")
func sync_data(value: int):
    print("Received: ", value)

# 调用 RPC
sync_data.rpc(42)

# 发送到特定对等方
sync_data.rpc_id(peer_id, 42)

# 检查发送者
func some_rpc():
    var sender = multiplayer.get_remote_sender_id()
    print("Called by: ", sender)
```

### 定时器

```gdscript
# 一次性定时器
await get_tree().create_timer(1.0).timeout
print("1 second passed")

# 循环定时器
var timer = Timer.new()
timer.wait_time = 1.0
timer.one_shot = false
timer.timeout.connect(_on_timer_timeout)
add_child(timer)
timer.start()

func _on_timer_timeout():
    print("Timer ticked")

# Tween 动画
var tween = create_tween()
tween.tween_property(node, "position", Vector3(10, 0, 0), 1.0)
tween.set_ease(Tween.EASE_OUT)
tween.set_trans(Tween.TRANS_SINE)
tween.play()
```

### 资源管理

```gdscript
# 预加载(编译时)
const MY_SCENE = preload("res://scene.tscn")

# 动态加载(运行时)
var scene = load("res://scene.tscn")

# 实例化
var instance = MY_SCENE.instantiate()

# 保存/加载资源
var config = ConfigFile.new()
config.set_value("section", "key", "value")
config.save("user://config.cfg")

config.load("user://config.cfg")
var value = config.get_value("section", "key")
```

### 文件操作

```gdscript
# 写入文件
var file = FileAccess.open("user://data.txt", FileAccess.WRITE)
file.store_line("Hello World")
file.close()

# 读取文件
var file = FileAccess.open("user://data.txt", FileAccess.READ)
while not file.eof_reached():
    var line = file.get_line()
    print(line)
file.close()

# 检查文件存在
if FileAccess.file_exists("user://data.txt"):
    print("File exists")

# 目录操作
if DirAccess.dir_exists_absolute("user://mydir"):
    print("Directory exists")

DirAccess.make_dir_recursive_absolute("user://mydir/subdir")
```

### 数学工具

```gdscript
# 向量操作
var a = Vector3(1, 2, 3)
var b = Vector3(4, 5, 6)

var sum = a + b
var dot = a.dot(b)
var cross = a.cross(b)
var length = a.length()
var normalized = a.normalized()

# 插值
var result = lerp(0, 10, 0.5)  # 5.0
var vector_result = lerp(a, b, 0.5)

# 角度转换
var radians = deg_to_rad(90)
var degrees = rad_to_deg(PI)

# 随机数
var rand_float = randf()  # 0.0 - 1.0
var rand_range = randf_range(1, 10)
var rand_int = randi() % 100  # 0 - 99
```

### 调试工具

```gdscript
# 打印
print("Debug message")
printerr("Error message")
push_warning("Warning")

# 格式化打印
prints("Value:", 42)  # "Value: 42"
printt("A", "B", "C")  # "A\tB\tC"

# 断言
assert(value > 0, "Value must be positive")

# 性能测量
var start_time = Time.get_ticks_msec()
# ... code ...
var elapsed = Time.get_ticks_msec() - start_time
print("Elapsed: ", elapsed, "ms")

# 调用栈
print_stack()
```

---

## Liblast 特定 API

### Globals 单例

```gdscript
# 获取游戏模式
var mode = MultiplayerState.game_config.game_mode

# 检查焦点
if Globals.focus == Globals.Focus.GAME:
    print("In game")

# 获取当前角色
var character = Globals.current_character

# 队伍颜色
var color = Globals.team_colors[Globals.Teams.LIME]

# 游戏状态
if Globals.game_state.current_match_phase == Globals.MatchPhase.GAME:
    print("Match in progress")
```

### Settings 单例

```gdscript
# 读取设置
var fov = Settings.get_var("render_fov")
var sensitivity = Settings.get_var("input_mouse_sensitivity")

# 修改设置
Settings.set_var("render_fov", 100)

# 监听设置变化
Settings.var_changed.connect(_on_setting_changed)

func _on_setting_changed(var_name: String, value):
    if var_name == "render_fov":
        update_camera(value)
```

### MultiplayerState 单例

```gdscript
# 检查角色
if MultiplayerState.role == MultiplayerState.MultiplayerRole.SERVER:
    print("I am the server")

# 启动服务器
MultiplayerState.start_server()

# 启动客户端
MultiplayerState.start_client("192.168.1.100")

# 停止
MultiplayerState.stop_server()
MultiplayerState.stop_client()

# 本地角色
var local_char = MultiplayerState.local_character
```

### GameState

```gdscript
# 获取游戏状态
var gs = Globals.game_state

# 得分
var score = gs.scores_by_team[1]

# 角色列表
for pid in gs.characters_by_pid.keys():
    var char = gs.characters_by_pid[pid]
    print("Character: ", char.profile.display_name)

# 生成角色
gs.spawn_character.rpc_id(1, player_id)

# 释放角色
gs.free_character.rpc(player_id)
```

### Character

```gdscript
# 获取角色状态
var health = character.state.health
var alive = character.state.alive
var team = character.state.team

# 应用伤害
var damage = DamageAttack.new()
damage.damage_amount = 50
damage.attacker = attacker
character.hurt.rpc(damage)

# 重生
character.respawn()

# 设置表情
character.set_face_expression(Character.CharacterFaceExpression.HURT, 2.0)

# 设置标识
character.set_banner_status.rpc(Character.CharacterBannerStatus.IDLE)
```

---

## 快捷键参考

### Godot 编辑器

| 快捷键 | 功能 |
|--------|------|
| F5 | 运行项目 |
| F6 | 运行当前场景 |
| Ctrl+S | 保存场景 |
| Ctrl+Shift+S | 保存所有场景 |
| Ctrl+Z | 撤销 |
| Ctrl+Y | 重做 |
| Ctrl+F | 查找 |
| Ctrl+Shift+F | 在文件中查找 |
| Space | 播放/暂停动画 |
| Delete | 删除选中节点 |
| Ctrl+D | 复制节点 |
| Shift+A | 添加子节点 |
| F | 聚焦选中节点 |
| T | 切换变换模式 |
| R | 旋转模式 |
| S | 缩放模式 |

### 游戏内控制

| 按键 | 功能 |
|------|------|
| W/A/S/D | 移动 |
| 鼠标 | 瞄准 |
| 左键 | 主武器射击 |
| 右键 | 副武器射击 |
| R | 装填 |
| 空格(地面) | 跳跃 |
| 空格(空中按住) | 喷气背包 |
| 1/2/3 | 切换武器 |
| T | 队伍聊天 |
| Y | 全局聊天 |
| Z | 瞄准缩放 |
| C | 第三人称相机 |
| M | 静音 |
| ESC | 菜单 |
| ~ | 控制台 |
| F10 | 退出游戏 |

---

## 常见错误速查

### 错误信息 → 解决方案

**"Node not found"**
- 检查节点路径
- 使用 `@onready` 确保节点已加载
- 使用 `get_node_or_null()` 安全检查

**"Invalid call to function"**
- 检查函数签名是否匹配
- 确认对象不为 null
- 检查函数是否存在

**"RPC failed"**
- 确认有多人对等方
- 检查 RPC 注解参数
- 确认函数有 `@rpc` 注解

**"Resource load failed"**
- 检查文件路径
- 确认文件存在
- 检查文件格式

**"Signal already connected"**
- 使用 `disconnect()` 先断开
- 检查是否重复连接
- 使用 `is_connected()` 检查

---

## 性能优化清单

### ✅ 渲染优化
- [ ] 使用 LOD (Level of Detail)
- [ ] 启用遮挡剔除
- [ ] 合批相同材质的物体
- [ ] 限制阴影质量
- [ ] 使用光照烘焙

### ✅ 代码优化
- [ ] 避免在 `_process` 中创建对象
- [ ] 使用对象池
- [ ] 减少字符串拼接
- [ ] 缓存频繁访问的节点
- [ ] 使用信号而非每帧检查

### ✅ 内存优化
- [ ] 及时释放不用的资源
- [ ] 使用 `queue_free()` 而非立即删除
- [ ] 避免循环引用
- [ ] 监控内存使用
- [ ] 定期清理缓存

### ✅ 网络优化
- [ ] 使用不可靠传输发送高频数据
- [ ] 批量发送 RPC
- [ ] 压缩数据包
- [ ] 限制更新频率
- [ ] 实现客户端预测

---

## 资源链接

### 官方资源
- Godot 官网: https://godotengine.org/
- Godot 文档: https://docs.godotengine.org/
- Godot 社区: https://godotengine.org/community/

### Liblast 资源
- Codeberg 仓库: https://codeberg.org/Liblast/Liblast-legacy
- YouTube 频道: https://www.youtube.com/channel/UC1Oi1eXwdr8RlqIslyht5AQ
- 聊天室: https://chat.unfa.xyz/channel/liblast

### 学习资源
- GDScript 参考: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/index.html
- 多人游戏教程: https://docs.godotengine.org/en/stable/tutorials/networking/index.html
- 最佳实践: https://docs.godotengine.org/en/stable/tutorials/best_practices/index.html

---

**祝开发顺利! 🚀**
