# GoldPrice - 黄金价格 MacOS 状态栏应用

## 项目简介

GoldPrice 是一个 MacOS 状态栏应用，用于实时显示黄金价格。应用直接在状态栏显示最新的黄金价格（人民币），京东涵盖京东金融实时金价、水贝黄金当天金价和全国各大知名品牌金店的当天金价。



## 功能特点

- 🏅 **实时价格显示** - 在 MacOS 状态栏实时显示黄金价格（人民币）
- 📊 **多数据源支持** - 支持11个数据源，包括京东金融（实时）、水贝黄金（当天）和9大品牌金店（当天）
- ⚡ **金价实时对比** - 通过数据源菜单列表对比各个数据源的金价，且支持切换状态栏显示的金价数据源
- 🔄 **自动定时刷新** - 每秒自动刷新价格数据，保持数据最新

## 系统要求

- MacOS 12.0 或更高版本
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
./.build/release/GoldPrice
```



## 项目结构

- `GoldPriceApp.swift` - 应用入口和主要结构
- `StatusBarController.swift` - 状态栏控制器，管理状态栏显示和智能菜单系统
- `GoldPriceService.swift` - 数据获取服务，负责从各个数据源获取黄金价格
- `GoldPriceView.swift` - 详情视图，显示价格信息、数据源选择和设置选项
- `Package.swift` - Swift Package Manager 配置文件
- `Makefile` - 构建和运行脚本
- `build_app.sh` / `build_app_simple.sh` - 应用打包脚本



## 技术特性

- **响应式设计** - 支持 macOS 深色/浅色模式自动适配
- **并发处理** - 使用 Swift Combine 框架实现响应式数据绑定
- **错误处理** - 完善的网络错误处理和降级显示机制
- **内存优化** - 高效的数据缓存和定时器管理
- **网络适配** - 智能处理不同API的数据格式和编码



## 许可证

MIT License