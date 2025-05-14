import SwiftUI
import AppKit
import Combine

class StatusBarController {
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var dataService: GoldPriceService
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        
        // 初始化数据服务
        dataService = GoldPriceService()
        
        // 创建弹出窗口
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 300)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: GoldPriceView(dataService: dataService))
        
        // 设置状态栏按钮
        if let button = statusItem.button {
            button.title = "N/A"
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        
        // 设置右键菜单
        setupMenu()
        
        // 订阅价格更新
        dataService.$currentPrice
            .receive(on: RunLoop.main)
            .sink { [weak self] price in
                if let button = self?.statusItem.button {
                    if self?.dataService.priceNotAvailable == true {
                        button.title = "N/A"
                    } else {
                        button.title = String(format: "G%.2f", price)
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
                        button.title = "N/A"
                    } else if let price = self?.dataService.currentPrice {
                        button.title = String(format: "G%.2f", price)
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

        // 数据源子菜单
        let sourcesMenu = NSMenu()

        // 添加京东金融选项
        let jdFinanceItem = NSMenuItem(title: "京东金融", action: #selector(selectJDFinance), keyEquivalent: "")
        jdFinanceItem.target = self
        if dataService.currentSource == .jdFinance {
            jdFinanceItem.state = .on
        }
        sourcesMenu.addItem(jdFinanceItem)

        // 添加水贝黄金选项
        let shuibeiBankItem = NSMenuItem(title: "水贝黄金", action: #selector(selectShuibeiBank), keyEquivalent: "")
        shuibeiBankItem.target = self
        if dataService.currentSource == .shuibeiGold {
            shuibeiBankItem.state = .on
        }
        sourcesMenu.addItem(shuibeiBankItem)
        
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
    
    @objc func selectJDFinance() {
        dataService.setDataSource(.jdFinance)
    }
    
    @objc func selectShuibeiBank() {
        dataService.setDataSource(.shuibeiGold)
    }
}