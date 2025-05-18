# GoldPrice - 实时黄金价格状态栏应用

## 项目简介

GoldPrice 是一个 macOS 状态栏应用，用于实时显示黄金价格。应用直接在状态栏显示最新的黄金价格（人民币），数据来源于京东金融积存金实时金价和水贝黄金当日金价。

## 功能特点

- 在 macOS 状态栏实时显示黄金价格（人民币）
- 支持两种数据源（京东金融、水贝黄金）
- 右键点击可切换数据源或退出程序
- 自动定时刷新价格数据（每秒一次）

## 系统要求

- macOS 12.0 或更高版本
- Swift 5.5 或更高版本

## 构建与运行

### 克隆仓库
```bash
git clone https://github.com/Tespera/GoldPrice.git
```

### 使用 Makefile

项目提供了 Makefile 来简化构建和运行过程：

```bash
# 构建应用
make build

# 运行应用
make run

# 清理构建文件
make clean
```

### 手动构建

```bash
# 构建应用
swift build -c release

# 运行应用
./build/release/GoldPrice
```

## 项目结构

- `GoldPriceApp.swift` - 应用入口和主要结构
- `StatusBarController.swift` - 状态栏控制器，管理状态栏显示和菜单
- `GoldPriceService.swift` - 数据服务，负责从不同数据源获取黄金价格
- `GoldPriceView.swift` - 详情视图，显示更多信息和设置选项
- `Package.swift` - Swift Package Manager 配置文件
- `Makefile` - 构建和运行脚本

## 数据来源

应用从以下来源获取黄金价格数据：

- 京东金融（主要数据源）
- 水贝黄金（深圳水贝金价市场，备用数据源）

## 许可证

MIT License
