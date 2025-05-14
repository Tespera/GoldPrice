import SwiftUI
import AppKit

@main
struct GoldPriceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarItem: NSStatusItem!
    private var statusBarController: StatusBarController!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 初始化状态栏控制器
        statusBarController = StatusBarController()
    }
}