# GitHub 代码同步脚本使用说明

## 功能介绍

`sync_to_github.sh` 是一个一键同步代码到 GitHub 仓库的脚本，可以自动处理以下操作：

- 检查和初始化 Git 仓库
- 添加所有变更文件到暂存区
- 提交变更并推送到 GitHub
- 处理推送冲突和错误情况
- 提供友好的交互界面和状态反馈

## 首次使用配置

### 1. 编辑脚本配置

打开 `sync_to_github.sh` 文件，在文件顶部找到配置区域，填入您的信息：

```bash
# 配置信息
GITHUB_USERNAME="your_username"     # 替换为您的GitHub用户名
GITHUB_REPO="your_repository"       # 替换为您的仓库名称
GITHUB_BRANCH="main"                # 分支名称，通常是main或master
```

### 2. 确保 Git 已配置

确保您的系统已安装 Git 并配置了用户信息：

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### 3. GitHub 认证设置

#### 方法一：使用 Personal Access Token (推荐)

1. 在 GitHub 上生成 Personal Access Token：
   - 访问 GitHub Settings > Developer settings > Personal access tokens
   - 点击 "Generate new token"
   - 选择适当的权限（至少需要 `repo` 权限）
   - 复制生成的 token

2. 配置 Git 使用 token：
   ```bash
   git config --global credential.helper store
   ```

3. 首次推送时，使用用户名和 token 作为密码

#### 方法二：使用 SSH 密钥

1. 生成 SSH 密钥：
   ```bash
   ssh-keygen -t ed25519 -C "your.email@example.com"
   ```

2. 将公钥添加到 GitHub 账户

3. 修改脚本中的仓库地址格式为 SSH：
   ```bash
   # 在脚本中将 HTTPS 地址改为 SSH 地址
   git remote set-url origin "git@github.com:${GITHUB_USERNAME}/${GITHUB_REPO}.git"
   ```

## 使用方法

### 基本使用

在项目根目录执行：

```bash
./sync_to_github.sh
```

### 脚本执行流程

1. **配置检查**：验证 GitHub 用户名和仓库名是否已配置
2. **仓库检查**：检查当前目录是否为 Git 仓库，如果不是则自动初始化
3. **变更检查**：检查工作区是否有未提交的变更
4. **提交信息**：提示输入提交信息（可使用默认的时间戳信息）
5. **确认操作**：显示即将同步的仓库信息，等待用户确认
6. **执行同步**：依次执行 `git add`、`git commit`、`git push`
7. **结果显示**：显示同步结果和仓库信息

### 交互示例

```
===== GitHub 代码同步工具 =====
检测到以下变更:
 M Sources/GoldPriceService.swift
 M build_app.sh
?? sync_to_github.sh

请输入提交信息 (直接回车使用默认信息):
提交信息: 添加GitHub同步脚本和优化构建脚本
提交信息: 添加GitHub同步脚本和优化构建脚本
即将同步到: https://github.com/yourusername/GoldPrice
确认继续? (Y/n): y
正在添加文件到暂存区...
✓ 文件已添加到暂存区
正在提交变更...
✓ 变更已提交
正在推送到GitHub...
✓ 推送成功
===== 同步完成 =====
仓库地址: https://github.com/yourusername/GoldPrice
分支: main
最新提交: 添加GitHub同步脚本和优化构建脚本
提交哈希: a1b2c3d
```

## 错误处理

### 推送失败处理

如果推送失败（通常是由于远程仓库有新的提交），脚本会：

1. 提示推送失败
2. 询问是否进行强制推送
3. 警告强制推送会覆盖远程历史记录
4. 根据用户选择执行相应操作

### 常见问题解决

1. **认证失败**：
   - 检查 GitHub 用户名和密码/token 是否正确
   - 确认 Personal Access Token 权限是否足够

2. **仓库不存在**：
   - 确认 GitHub 仓库名称是否正确
   - 确认仓库是否已在 GitHub 上创建

3. **分支不存在**：
   - 检查分支名称是否正确（main vs master）
   - 确认远程仓库是否有该分支

## 安全注意事项

1. **不要在脚本中硬编码密码**
2. **使用 Personal Access Token 而不是密码**
3. **定期更新 Access Token**
4. **谨慎使用强制推送功能**

## 自定义配置

您可以根据需要修改脚本中的以下配置：

- `GITHUB_BRANCH`：默认分支名称
- 提交信息格式
- 颜色主题
- 错误处理逻辑

## 集成到工作流

建议将此脚本集成到您的开发工作流中：

1. 开发完成后运行 `./build_app.sh` 构建应用
2. 测试应用功能正常
3. 运行 `./sync_to_github.sh` 同步代码到 GitHub
4. 在 GitHub 上创建 Release（如需要） 