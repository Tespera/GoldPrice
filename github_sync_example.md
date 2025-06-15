# GitHub 同步脚本使用示例

## 脚本说明

项目中提供了两个 GitHub 同步脚本：

1. **sync_to_github.sh** - 基础版本，需要手动配置分支
2. **sync_to_github_auto.sh** - 自动版本，自动检测当前分支

## 快速开始

### 1. 配置脚本

编辑脚本文件，设置您的 GitHub 信息：

```bash
# 在脚本顶部修改这些配置
GITHUB_USERNAME="your_username"     # 您的GitHub用户名
GITHUB_REPO="your_repository"       # 您的仓库名称
GITHUB_BRANCH="main"                # 目标分支（仅基础版本需要）
```

### 2. 使用自动版本（推荐）

```bash
./sync_to_github_auto.sh
```

这个版本会：
- 自动检测当前所在分支
- 如果不在任何分支上，会自动切换到 main 分支
- 自动设置上游分支（如果需要）

### 3. 使用基础版本

```bash
./sync_to_github.sh
```

这个版本使用固定的分支配置。

## 使用流程示例

```
$ ./sync_to_github_auto.sh

===== GitHub 代码同步工具 (自动分支检测) =====
当前分支: dev
检测到以下变更:
 M Sources/GoldPriceService.swift
 M build_app.sh
?? sync_to_github_auto.sh

请输入提交信息 (直接回车使用默认信息):
提交信息: 添加GitHub同步脚本
提交信息: 添加GitHub同步脚本
即将同步到: https://github.com/Tespera/GoldPrice (分支: dev)
确认继续? (Y/n): y
正在添加文件到暂存区...
✓ 文件已添加到暂存区
正在提交变更...
✓ 变更已提交
正在推送到GitHub (分支: dev)...
✓ 推送成功
===== 同步完成 =====
仓库地址: https://github.com/Tespera/GoldPrice
分支: dev
最新提交: 添加GitHub同步脚本
提交哈希: a1b2c3d
```

## 开发工作流建议

1. **开发阶段**：在 dev 分支上开发
   ```bash
   git checkout dev
   # 进行开发...
   ./sync_to_github_auto.sh
   ```

2. **发布阶段**：合并到 main 分支
   ```bash
   git checkout main
   git merge dev
   ./sync_to_github_auto.sh
   ```

3. **构建发布**：
   ```bash
   ./build_app.sh
   ./sync_to_github_auto.sh
   ```

## 注意事项

- 首次使用需要配置 GitHub 认证（Personal Access Token 或 SSH 密钥）
- 脚本会自动处理大部分 Git 操作错误
- 强制推送功能请谨慎使用
- 建议在重要变更前先备份代码 