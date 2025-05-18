import Cocoa
import SwiftUI

class StatusBarController {
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    private var timer: Timer?
    private var currentPrice: Double?
    
    init() {
        statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.title = "加载中..."
        }
        
        setupMenu()
        startTimer()
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "刷新", action: #selector(refreshPrice), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(timeInterval: 300, target: self, selector: #selector(refreshPrice), userInfo: nil, repeats: true)
        refreshPrice()
    }
    
    @objc private func refreshPrice() {
        GoldPriceService.fetchGoldPrice { [weak self] price in
            guard let self = self, let price = price else { return }
            
            DispatchQueue.main.async {
                self.currentPrice = price
                if let button = self.statusItem.button {
                    button.title = "¥\(String(format: "%.2f", price))"
                }
            }
        }
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    deinit {
        timer?.invalidate()
    }
}
