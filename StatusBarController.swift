import SwiftUI
import AppKit
import Combine

class StatusBarController: NSObject, NSMenuDelegate {
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var dataService: GoldPriceService
    private var statusBarUpdateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var sourceMenuItems: [GoldPriceSource: NSMenuItem] = [:]
    
    override init() {
        statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: 60)  // 设置状态栏固定宽度
        
        // 初始化数据服务
        dataService = GoldPriceService()
        
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 450)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: GoldPriceView(dataService: dataService))
        
        super.init()
        
        // 设置状态栏按钮
        if let button = statusItem.button {
            button.title = "G0.00"
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        
        dataService.fetchBrandList()
        setupMenu()
        
        // 订阅数据源更新
        dataService.$currentSource
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.setupMenu()
                self?.updateStatusBarDisplay()
            }
            .store(in: &cancellables)
        
        // 订阅所有数据源价格更新
        dataService.$allSourcePrices
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateMenuPrices()
                self?.updateStatusBarDisplay()
            }
            .store(in: &cancellables)
        
        // 订阅所有数据源价格可用性更新
        dataService.$allSourcePriceAvailability
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateMenuPrices()
                self?.updateStatusBarDisplay()
            }
            .store(in: &cancellables)
        
        // 开始获取数据
        dataService.startFetching()
        
        // 启动状态栏实时更新定时器（每100毫秒更新一次，确保实时显示）
        startStatusBarUpdateTimer()
    }
    
    deinit {
        stopStatusBarUpdateTimer()
    }
    
    private func startStatusBarUpdateTimer() {
        statusBarUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateStatusBarDisplay()
        }
    }
    
    private func stopStatusBarUpdateTimer() {
        statusBarUpdateTimer?.invalidate()
        statusBarUpdateTimer = nil
    }
    
    private func updateStatusBarDisplay() {
        guard let button = statusItem.button else { return }
        
        // 检查当前数据源的价格是否可用
        let currentSource = dataService.currentSource
        let isAvailable = dataService.allSourcePriceAvailability[currentSource] ?? false
        
        if !isAvailable {
            button.title = "G0.00"
        } else if let price = dataService.allSourcePrices[currentSource] {
            // 京东金融显示小数，其他金店显示整数
            if currentSource == .jdFinance {
                button.title = "G\(String(format: "%.2f", price))"
            } else {
                button.title = "G\(Int(price))"
            }
        } else {
            button.title = "G0.00"
        }
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(sender)
        }
    }
    
    func showPopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
        }
    }
    
    func closePopover(_ sender: AnyObject?) {
        popover.performClose(sender)
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        menu.delegate = self

        // 数据源子菜单
        let sourcesMenu = NSMenu()
        sourcesMenu.delegate = self

        // 添加所有数据源选项（按照枚举顺序）
        for source in GoldPriceSource.allCases {
            let sourceItem = NSMenuItem(title: "", action: #selector(selectGoldSource(_:)), keyEquivalent: "")
            sourceItem.target = self
            sourceItem.representedObject = source
            
            // 设置带样式的标题
            setMenuItemAttributedTitle(sourceItem, for: source)
            
            // 如果当前选中的是这个数据源，则显示选中状态
            if dataService.currentSource == source {
                sourceItem.state = NSControl.StateValue.on
            }
            sourcesMenu.addItem(sourceItem)
            
            // 保存菜单项引用，用于后续更新
            sourceMenuItems[source] = sourceItem
            
            // 在水贝黄金后添加分隔符
            if source == .shuibeiGold {
                sourcesMenu.addItem(NSMenuItem.separator())
            }
        }
        
        // 数据源菜单项
        let dataSourceItem = NSMenuItem(title: "数据源", action: nil, keyEquivalent: "d")
        dataSourceItem.submenu = sourcesMenu
        menu.addItem(dataSourceItem)
        
        menu.addItem(NSMenuItem.separator())

        // 退出选项
        let quitItem = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        // 设置右键菜单
        statusItem.menu = menu
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    @objc func selectGoldSource(_ sender: NSMenuItem) {
        if let source = sender.representedObject as? GoldPriceSource {
            dataService.setDataSource(source)
        }
    }
    
    // 获取指定数据源的价格属性字符串
    private func getPriceAttributedString(for source: GoldPriceSource) -> NSAttributedString {
        // 定义字体样式
        let priceFont = NSFont.systemFont(ofSize: 13, weight: .regular)
        let unitFont = NSFont.systemFont(ofSize: 12, weight: .regular)
        let priceColor = NSColor.labelColor
        let unitColor = NSColor.secondaryLabelColor
        
        let attributedString = NSMutableAttributedString()
        
        // 添加制表符间距
        attributedString.append(NSAttributedString(string: "\t\t\t"))
        
        // 检查价格是否可用
        if let isAvailable = dataService.allSourcePriceAvailability[source], isAvailable,
           let price = dataService.allSourcePrices[source] {
            
            // 价格数字部分
            let priceString: String
            if source == .jdFinance {
                priceString = String(format: "%.2f", price)
            } else {
                priceString = String(format: "%d", Int(price))
            }
            
            let priceAttr = NSAttributedString(string: priceString, attributes: [
                .font: priceFont,
                .foregroundColor: priceColor
            ])
            attributedString.append(priceAttr)
            
            // 单位部分
            let unitAttr = NSAttributedString(string: "  元/克", attributes: [
                .font: unitFont,
                .foregroundColor: unitColor
            ])
            attributedString.append(unitAttr)
            
        } else {
            // 无数据状态
            let naAttr = NSAttributedString(string: "  0.00 元/克", attributes: [
                .font: priceFont,
                .foregroundColor: NSColor.secondaryLabelColor
            ])
            attributedString.append(naAttr)
        }
        
        return attributedString
    }
    
    // 设置菜单项的属性标题
    private func setMenuItemAttributedTitle(_ menuItem: NSMenuItem, for source: GoldPriceSource) {
        // 定义数据源名称的字体样式
        let sourceFont = NSFont.systemFont(ofSize: 13, weight: .regular)
        let sourceColor = NSColor.labelColor
        
        let attributedTitle = NSMutableAttributedString()
        
        // 数据源名称部分
        let sourceAttr = NSAttributedString(string: source.rawValue, attributes: [
            .font: sourceFont,
            .foregroundColor: sourceColor
        ])
        attributedTitle.append(sourceAttr)
        
        // 价格部分
        let priceAttr = getPriceAttributedString(for: source)
        attributedTitle.append(priceAttr)
        
        menuItem.attributedTitle = attributedTitle
    }
    
    // 更新菜单中的价格显示
    private func updateMenuPrices() {
        for (source, menuItem) in sourceMenuItems {
            setMenuItemAttributedTitle(menuItem, for: source)
        }
    }
    
    // MARK: - NSMenuDelegate
    func menuWillOpen(_ menu: NSMenu) {
        // 当数据源菜单打开时，立即刷新一次数据并更新菜单显示
        if menu == statusItem.menu?.item(withTitle: "数据源")?.submenu {
            print("数据源菜单打开，立即刷新数据")
            
            // 立即更新一次菜单显示（显示当前缓存的数据）
            updateMenuPrices()
            
            // 开始刷新数据
            dataService.forceRefreshAllSources()
            
            // 延迟一小段时间后再次更新菜单，让新数据有时间加载
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.updateMenuPrices()
            }
            
            // 再延迟一点时间再次更新（处理较慢的网络请求）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.updateMenuPrices()
            }
        }
    }
    
    func menuDidClose(_ menu: NSMenu) {
        // 菜单关闭后可以进行一些清理工作（如果需要）
    }

}
