import SwiftUI
import AppKit
import Combine

class StatusBarController: NSObject, NSMenuDelegate {
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var dataService: GoldPriceService
    private var timer: Timer?
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
        
        // 订阅价格更新
        dataService.$currentPrice
            .receive(on: RunLoop.main)
            .sink { [weak self] price in
                if let button = self?.statusItem.button {
                    if self?.dataService.priceNotAvailable == true {
                        button.title = "G0.00"
                    } else {
                        // 京东金融显示小数，其他金店显示整数
                        if self?.dataService.currentSource == .jdFinance {
                            button.title = "G\(String(format: "%.2f", price))"
                        } else {
                            button.title = "G\(Int(price))"
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        // 订阅价格可用性状态
        dataService.$priceNotAvailable
            .receive(on: RunLoop.main)
            .sink { [weak self] notAvailable in
                if let button = self?.statusItem.button {
                    if notAvailable {
                        button.title = "G0.00"
                    } else if let price = self?.dataService.currentPrice {
                        // 京东金融显示小数，其他金店显示整数
                        if self?.dataService.currentSource == .jdFinance {
                            button.title = "G\(String(format: "%.2f", price))"
                        } else {
                            button.title = "G\(Int(price))"
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        // 订阅数据源更新
        dataService.$currentSource
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.setupMenu()
            }
            .store(in: &cancellables)
        
        // 订阅所有数据源价格更新
        dataService.$allSourcePrices
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateMenuPrices()
            }
            .store(in: &cancellables)
        
        // 订阅所有数据源价格可用性更新
        dataService.$allSourcePriceAvailability
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateMenuPrices()
            }
            .store(in: &cancellables)
        

        // 开始获取数据
        dataService.startFetching()
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
            // G0.00状态
            let naAttr = NSAttributedString(string: "  G0.00", attributes: [
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
        // 当数据源菜单打开时，立即刷新一次数据
        if menu == statusItem.menu?.item(withTitle: "数据源")?.submenu {
            print("数据源菜单打开，立即刷新数据")
            dataService.forceRefreshAllSources()
        }
    }

}