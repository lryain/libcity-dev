# Liblast Legacy 系统开发教程

## 目录

1. [项目概述](#1-项目概述)
2. [环境搭建](#2-环境搭建)
3. [Godot 4 基础概念](#3-godot-4-基础概念)
4. [项目架构详解](#4-项目架构详解)
5. [核心系统分析](#5-核心系统分析)
6. [游戏逻辑实现](#6-游戏逻辑实现)
7. [网络与多人游戏](#7-网络与多人游戏)
8. [资源管理](#8-资源管理)
9. [UI 与 HUD 系统](#9-ui-与-hud-系统)
10. [武器系统](#10-武器系统)
11. [地图与关卡设计](#11-地图与关卡设计)
12. [角色系统](#12-角色系统)
13. [音效与视觉效果](#13-音效与视觉效果)
14. [配置与设置系统](#14-配置与设置系统)
15. [二次开发指南](#15-二次开发指南)
16. [常见问题与调试](#16-常见问题与调试)

---

## 1. 项目概述

### 1.1 什么是 Liblast?

Liblast 是一个使用 Godot 4 引擎开发的开源多人第一人称射击游戏(FPS)。项目名称来源于 "libre"(自由)和 "blast"(爆炸/射击)两个词的组合。

**项目特点:**
- 🎮 完全开源的 FPS 游戏
- 🌐 支持多人联机对战
- 🤖 内置 AI 机器人
- 🎨 使用完全自由的工具链开发
- 💻 跨平台支持(Windows、Linux、macOS、Web)
- 🔧 高度可定制和可扩展

### 1.2 项目目标

**主要目标:**
1. 创建一个有趣的开源游戏供所有人享受
2. 证明自由软件工具足以制作优质游戏
3. 在项目中共同成长,享受开发乐趣

**次要目标:**
1. 推动开源 FPS 游戏在设计、风格、技术和整体质量方面的发展
2. 支持低端电脑运行,同时为高端硬件提供高保真度
3. 允许通过网页浏览器快速加入游戏
4. 积极帮助 Godot 引擎和其他依赖的开源工具的发展
5. 通过模组支持第三方内容
6. 提供可选的在线账户以安全存储用户数据

### 1.3 项目结构

```
Liblast-legacy/
├── Game/                    # 主游戏项目
│   ├── Assets/             # 游戏资源(场景、脚本、材质等)
│   ├── AutomatedTests/     # 自动化测试
│   ├── ManualTests/        # 手动测试
│   └── project.godot       # Godot 项目配置文件
├── Asset Sources/          # 原始资源文件(Blender、SVG 等)
├── InfraServer/            # 基础设施服务器(账户系统等)
├── Testbed/                # 测试环境
├── Design/                 # 设计文档和概念图
├── Promo/                  # 宣传材料
└── Visual Identity/        # 视觉识别系统
```

---

## 2. 环境搭建

### 2.1 前置要求

**必需软件:**
1. **Godot 4.x 编辑器**
   - 下载地址:https://godotengine.org/download/
   - 推荐使用最新稳定版

2. **Git 和 Git LFS**
   - Git:版本控制系统
   - Git LFS:用于管理大型文件(纹理、模型、音频等)

**推荐工具:**
- 代码编辑器:VS Code、Godot 内置编辑器
- 3D 建模:Blender
- 图像处理:GIMP、Krita
- 音频编辑:Audacity

### 2.2 克隆项目

#### Windows 用户

```powershell
# 1. 安装 Git for Windows
# 访问 https://gitforwindows.org 下载并安装

# 2. 打开 Git Bash,克隆仓库
git clone https://codeberg.org/Liblast/Liblast-legacy.git

# 3. 进入项目目录
cd Liblast-legacy

# 4. 初始化 Git LFS
git lfs install

# 5. 拉取 LFS 文件
git lfs pull
git fetch
```

#### Linux 用户

```bash
# 1. 安装 git 和 git-lfs
sudo apt install git git-lfs  # Debian/Ubuntu

# 2. 克隆仓库
git clone https://codeberg.org/Liblast/Liblast-legacy.git

# 3. 进入项目目录
cd Liblast-legacy

# 4. 初始化并拉取 LFS 文件
git lfs install
git lfs pull
git fetch
```

#### macOS 用户

```bash
# 1. 使用 Homebrew 安装 git 和 git-lfs
brew install git git-lfs

# 2. 克隆仓库
git clone https://codeberg.org/Liblast/Liblast-legacy.git

# 3. 进入项目目录并初始化 LFS
cd Liblast-legacy
git lfs install
git lfs pull
git fetch
```

### 2.3 导入项目到 Godot

1. 打开 Godot 4 编辑器
2. 点击 "Import" 按钮
3. 浏览到 `Game/project.godot` 文件
4. 点击 "Import & Edit"
5. 等待资源导入完成(首次导入可能需要几分钟)

### 2.4 运行游戏

**在编辑器中运行:**
- 点击 Godot 编辑器右上角的 "Play Scene" 或 "Play Project" 按钮
- 或使用快捷键 F5/F6

**导出游戏:**
1. 点击菜单栏 "Project" → "Export"
2. 配置导出平台(Windows、Linux、macOS、Web 等)
3. 点击 "Export Project"

---

## 3. Godot 4 基础概念

在深入学习 Liblast 之前,我们需要了解 Godot 4 的核心概念。

### 3.1 节点(Node)系统

Godot 使用树状结构的节点系统来组织游戏对象。

**基本概念:**
- **节点(Node)**:游戏世界中的基本构建块
- **场景(Scene)**:由节点组成的可重用单元
- **场景树(Scene Tree)**:所有活动场景的层次结构

**示例:**
```
Root (Node)
├── Player (CharacterBody3D)
│   ├── Mesh (MeshInstance3D)
│   ├── Camera (Camera3D)
│   └── CollisionShape (CollisionShape3D)
└── Enemy (CharacterBody3D)
    ├── Mesh (MeshInstance3D)
    └── CollisionShape (CollisionShape3D)
```

### 3.2 常用节点类型

**3D 节点:**
- `Node3D`:所有 3D 节点的基类
- `CharacterBody3D`:用于角色控制(玩家、敌人)
- `MeshInstance3D`:显示 3D 模型
- `Camera3D`:3D 摄像机
- `Light3D`:光源
- `Area3D`:检测重叠区域
- `StaticBody3D`:静态物理物体
- `RigidBody3D`:刚体物理物体

**2D/UI 节点:**
- `Control`:UI 控件基类
- `Label`:文本标签
- `Button`:按钮
- `TextureRect`:显示纹理
- `Panel`:面板容器

**特殊节点:**
- `MultiplayerSpawner`:自动同步生成的节点
- `AnimationPlayer`:播放动画
- `AudioStreamPlayer`:播放音频

### 3.3 GDScript 基础

GDScript 是 Godot 的主要脚本语言,类似 Python。

**基本语法:**

```gdscript
# 类定义
extends Node3D  # 继承自 Node3D

# 变量声明
var health: int = 100
var name: String = "Player"
var position: Vector3 = Vector3.ZERO

# 常量
const MAX_HEALTH = 100
const SPEED = 5.0

# 信号
signal health_changed(new_health)
signal died

# 函数
func _ready():
    # 节点准备好时调用
    print("Node is ready!")

func _process(delta):
    # 每帧调用
    pass

func _physics_process(delta):
    # 每个物理帧调用(固定频率)
    pass

# RPC(远程过程调用)- 用于网络同步
@rpc("call_remote", "any_peer", "reliable")
func sync_data(data):
    # 在所有客户端上执行
    pass
```

### 3.4 信号(Signals)

信号是 Godot 的事件系统,用于节点间通信。

**定义和使用信号:**

```gdscript
# 定义信号
signal player_died
signal score_updated(score: int)

# 发射信号
emit_signal("player_died")
score_updated.emit(100)

# 连接信号
player_node.player_died.connect(_on_player_died)

# 信号处理函数
func _on_player_died():
    print("Player has died!")
```

### 3.5 场景实例化

```gdscript
# 加载场景
var scene = preload("res://Assets/Characters/Character.tscn")

# 实例化场景
var character = scene.instantiate()

# 添加到场景树
add_child(character)

# 设置位置
character.global_position = Vector3(0, 0, 0)
```

---

## 4. 项目架构详解

### 4.1 整体架构

Liblast 采用经典的客户端-服务器架构,支持以下模式:
- **本地单人模式**:无网络连接
- **局域网模式**:一个玩家作为主机,其他玩家加入
- **专用服务器模式**:独立的服务器进程
- **在线模式**:连接到公共服务器

### 4.2 核心单例(Autoloads)

Godot 的单例系统在项目启动时自动加载,全局可用。

**Liblast 的单例:**

| 单例名称 | 路径 | 功能 |
|---------|------|------|
| `Globals` | `Assets/Singletons/Globals.gd` | 全局常量、枚举、状态 |
| `Settings` | `Assets/Singletons/Settings.gd` | 游戏设置管理 |
| `MultiplayerState` | `Assets/Singletons/MultiplayerState.gd` | 多人游戏状态管理 |
| `InfraServer` | `Assets/Singletons/InfraServer.gd` | 基础设施服务器通信 |
| `Badges` | `Assets/Badges/Badges.gd` | 徽章系统 |
| `Storage` | `Assets/Singletons/Storage.gd` | 数据存储 |
| `PerformanceMonitor` | `Assets/Singletons/PerformanceMonitor.gd` | 性能监控 |
| `Logger` | `Assets/Singletons/Logger.gd` | 日志记录 |
| `LocalDiscovery` | `Assets/Singletons/LocalDiscovery.gd` | 局域网发现 |
| `Console` | `Assets/HUD/Console.tscn` | 开发者控制台 |

### 4.3 场景结构

**主场景流程:**

```
Startup.tscn (启动场景)
    ↓
Main.tscn (主场景)
    ├── UI (用户界面)
    │   ├── MainMenu (主菜单)
    │   ├── GameMenu (游戏菜单)
    │   └── HUD (游戏内界面)
    ├── BackgroundMap (背景地图 - 菜单用)
    └── GameState (游戏状态 - 动态加载)
        ├── Map (当前地图)
        ├── CharactersRoot (角色容器)
        ├── SpawnRoot (生成对象容器)
        └── CharacterSpawner (角色生成器)
```

### 4.4 关键类和组件

**核心类:**

1. **GameState** (`Assets/Game/GameState.gd`)
   - 管理游戏会话
   - 处理地图加载
   - 管理角色生成和销毁
   - 处理得分和游戏结束逻辑

2. **Character** (`Assets/Characters/Character.gd`)
   - 玩家和 AI 角色的基类
   - 处理移动、战斗、死亡
   - 管理武器和装备
   - 网络同步

3. **MultiplayerState** (`Assets/Singletons/MultiplayerState.gd`)
   - 管理网络连接
   - 处理服务器/客户端角色
   - 管理认证和握手

4. **Globals** (`Assets/Singletons/Globals.gd`)
   - 定义全局常量和枚举
   - 管理游戏焦点状态
   - 跟踪当前控制的角色

---

*(教程继续...)*
