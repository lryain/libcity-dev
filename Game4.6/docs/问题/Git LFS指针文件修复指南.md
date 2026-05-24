# Git LFS 指针文件修复指南

## 问题描述

执行 `git restore .` 或 `git checkout` 时出现以下警告：

```
Encountered 2 files that should have been pointers, but weren't:
Legacy Assets/Props/BeerCan.glb
Legacy Assets/Props/Resonator/Lowpoly 04.glb
```

## 根本原因

这两个 `.glb` 文件是在 `.gitattributes` 配置 LFS 追踪 `*.glb` **之前**就已经以二进制形式提交到 Git 仓库的。因此，它们从未被转换为 LFS 指针文件，而是以完整的二进制内容存储在 Git 历史中。

当 `.gitattributes` 后来配置了 `*.glb filter=lfs diff=lfs merge=lfs -text` 后，Git 期望这些文件是 LFS 指针格式，但实际存储的是二进制数据，导致不一致。`git status` 会显示这些文件被修改（`M` 状态），即使你并未手动更改它们。

## 解决方法

### 方法一：`git lfs migrate import`（推荐，已验证有效）

此方法会重写提交历史，将二进制文件转换为 LFS 指针。

```bash
# 1. 确保工作区干净
git stash
git checkout -- .

# 2. 执行 LFS 迁移（--no-rewrite 模式，不重写历史，创建新提交）
git lfs migrate import --yes --no-rewrite --include="*.glb" "Legacy Assets/Props/BeerCan.glb" "Legacy Assets/Props/Resonator/Lowpoly 04.glb"

# 3. 验证文件是否已变为 LFS 指针
Get-Content "Legacy Assets/Props/BeerCan.glb" -TotalCount 5
# 应输出类似：
# version https://git-lfs.github.com/spec/v1
# oid sha256:xxxxxx...
# size xxxxxx

# 4. 推送到远程
git push
```

### 方法二：手动重新添加文件（适用于少量文件）

```bash
# 1. 从索引中移除文件
git rm --cached "Legacy Assets/Props/BeerCan.glb"
git rm --cached "Legacy Assets/Props/Resonator/Lowpoly 04.glb"

# 2. 重新添加（Git LFS 会自动将其转换为指针）
git add "Legacy Assets/Props/BeerCan.glb"
git add "Legacy Assets/Props/Resonator/Lowpoly 04.glb"

# 3. 提交
git commit -m "fix: convert glb files to LFS pointers"

# 4. 推送到远程
git push
```

### 方法三：`git lfs migrate import`（重写历史模式）

> ⚠️ 此方法会重写 Git 历史，仅在确认需要时使用

```bash
git lfs migrate import --include="*.glb"
```

## 验证修复

```bash
# 检查文件内容是否为 LFS 指针
Get-Content "Legacy Assets/Props/BeerCan.glb" -TotalCount 5

# 检查 LFS 状态
git lfs status

# 检查 LFS 文件列表
git lfs ls-files | Select-String "BeerCan|Lowpoly"
```

## 预防措施

1. **在项目初期就配置 `.gitattributes`**，确保 LFS 追踪规则在提交大文件之前就已生效
2. **提交前检查**：使用 `git lfs status` 确认大文件是否被 LFS 正确追踪
3. **使用 `git lfs track`** 添加新的文件类型追踪后，确保已有文件也被正确迁移

## 参考信息

- 问题文件：`Legacy Assets/Props/BeerCan.glb`、`Legacy Assets/Props/Resonator/Lowpoly 04.glb`
- `.gitattributes` 配置：`*.glb filter=lfs diff=lfs merge=lfs -text`
- 修复日期：2025年
