import Foundation
import Combine

enum GoldPriceSource: String {
    case jdFinance = "京东金融"
    case shuibeiGold = "水贝黄金"
}

class GoldPriceService: ObservableObject {
    @Published var currentPrice: Double = 0.0
    @Published var currentSource: GoldPriceSource = .jdFinance
    @Published var lastUpdateTime: Date = Date()
    @Published var isLoading: Bool = false
    @Published var priceNotAvailable: Bool = false // 新增属性，标记价格是否不可用
    
    private var timer: Timer?
    private let refreshInterval: TimeInterval = 1 // 每1s刷新一次
    
    init() {
        // 初始化时不做任何数据获取，等待startFetching调用
    }
    
    func startFetching() {
        // 立即获取一次数据
        fetchGoldPrice()
        
        // 设置定时器定期获取数据
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.fetchGoldPrice()
        }
    }
    
    func stopFetching() {
        timer?.invalidate()
        timer = nil
    }
    
    func setDataSource(_ source: GoldPriceSource) {
        self.currentSource = source
        self.priceNotAvailable = false // 重置状态
        fetchGoldPrice() // 切换数据源后立即获取新数据
    }
    
    func fetchGoldPrice() {
        isLoading = true
        priceNotAvailable = false // 重置状态
        
        // 尝试从API获取真实数据
        switch currentSource {
        case .jdFinance:
            fetchJDFinanceGoldPrice()
        case .shuibeiGold:
            fetchShuibeiGoldPrice()
        }
    }
    
    // 从京东金融获取黄金价格
    private func fetchJDFinanceGoldPrice() {
        // 京东金融黄金价格API URL
        let urlString = "https://api.jdjygold.com/gw2/generic/jrm/h5/m/stdLatestPrice?productSku=1961543816"
        
        guard let url = URL(string: urlString) else {
            self.handleFetchError("无效的URL", source: .jdFinance)
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.handleFetchError(error.localizedDescription, source: .jdFinance)
                return
            }
            
            guard let data = data else {
                self.handleFetchError("没有返回数据", source: .jdFinance)
                return
            }
            
            // 打印原始响应数据用于调试
            if let responseString = String(data: data, encoding: .utf8) {
                print("京东金融原始响应: \(responseString)")
            }
            
            do {
                // 解析JSON数据
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let resultData = json["resultData"] as? [String: Any],
                   let datas = resultData["datas"] as? [String: Any],
                   let priceStr = datas["price"] as? String,
                   let price = Double(priceStr) {
                    
                    DispatchQueue.main.async {
                        self.currentPrice = price
                        self.lastUpdateTime = Date()
                        self.isLoading = false
                        print("京东金融金价获取成功: \(price)")
                    }
                } else {
                    self.handleFetchError("无法解析黄金价格数据", source: .jdFinance)
                }
            } catch {
                self.handleFetchError("JSON解析错误: \(error.localizedDescription)", source: .jdFinance)
            }
        }
        
        task.resume()
    }
    
    private func handleFetchError(_ message: String, source: GoldPriceSource? = nil) {
        let sourceName = source?.rawValue ?? currentSource.rawValue
        print("获取黄金价格失败 [\(sourceName)]: \(message)")
        DispatchQueue.main.async {
            self.isLoading = false
            self.priceNotAvailable = true
            // 不再使用模拟数据，设置为N/A（在UI层处理显示）
        }
    }
    
    // 从水贝黄金获取黄金价格
    private func fetchShuibeiGoldPrice() {
        // 尝试从 jinrijinjia.cn 网站获取数据
        let urlString = "http://www.jinrijinjia.cn/shuibei/"
        
        guard let url = URL(string: urlString) else {
            self.handleFetchError("无效的URL", source: .shuibeiGold)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.handleFetchError("获取网页失败: \(error.localizedDescription)", source: .shuibeiGold)
                return
            }
            
            guard let data = data else {
                self.handleFetchError("没有返回数据", source: .shuibeiGold)
                return
            }
            
            // 先尝试UTF-8编码
            if let htmlString = String(data: data, encoding: .utf8) {
                // 尝试解析HTML内容提取金价
                if let price = self.extractGoldPriceFromJinrijinjia(htmlString) {
                    DispatchQueue.main.async {
                        self.currentPrice = price
                        self.lastUpdateTime = Date()
                        self.isLoading = false
                        print("水贝金价获取成功: \(price)")
                    }
                    return
                }
                
                print("从 jinrijinjia.cn 未能提取金价")
            } else if let htmlString = String(data: data, encoding: .isoLatin1) {
                // 尝试其他编码，如isoLatin1
                if let price = self.extractGoldPriceFromJinrijinjia(htmlString) {
                    DispatchQueue.main.async {
                        self.currentPrice = price
                        self.lastUpdateTime = Date()
                        self.isLoading = false
                        print("水贝金价获取成功(isoLatin1编码): \(price)")
                    }
                    return
                }
                
                print("从 jinrijinjia.cn (isoLatin1编码) 未能提取金价")
            } else {
                self.handleFetchError("无法解析HTML编码", source: .shuibeiGold)
                return
            }
            
            // 如果无法提取价格数据，返回N/A
            self.handleFetchError("无法从网站提取价格数据", source: .shuibeiGold)
        }
        
        task.resume()
    }
    
    // 从 jinrijinjia.cn 网站HTML中提取金价
    private func extractGoldPriceFromJinrijinjia(_ html: String) -> Double? {
        print("开始从jinrijinjia网站提取金价数据")
        
        // 尝试直接匹配页面中的金价数字
        // 1. 查找"足金999价格XXX元克"格式
        if let regex = try? NSRegularExpression(pattern: "足金999价格(\\d+)元克", options: []) {
            let nsString = html as NSString
            let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
            
            if let match = matches.first, match.numberOfRanges > 1 {
                let priceString = nsString.substring(with: match.range(at: 1))
                print("找到足金999价格: \(priceString)元/克")
                if let price = Double(priceString) {
                    return price
                }
            }
        }
        
        // 2. 查找"元/克"格式
        if let regex = try? NSRegularExpression(pattern: "(\\d+)\\s*元/克", options: []) {
            let nsString = html as NSString
            let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
            
            if let match = matches.first, match.numberOfRanges > 1 {
                let priceString = nsString.substring(with: match.range(at: 1))
                print("找到价格: \(priceString)元/克")
                if let price = Double(priceString) {
                    return price
                }
            }
        }
        
        // 3. 查找"黄金价格 XXX元/克"格式（表格中常见）
        if let regex = try? NSRegularExpression(pattern: "黄金价格\\s*(\\d+)元/克", options: []) {
            let nsString = html as NSString
            let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
            
            if let match = matches.first, match.numberOfRanges > 1 {
                let priceString = nsString.substring(with: match.range(at: 1))
                print("找到表格价格: \(priceString)元/克")
                if let price = Double(priceString) {
                    return price
                }
            }
        }
        
        // 4. 尝试匹配H1标题中可能包含的价格
        if let regex = try? NSRegularExpression(pattern: "深圳水贝今日黄金最新价[\\s\\n]*#?\\s*(\\d+)", options: []) {
            let nsString = html as NSString
            let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
            
            if let match = matches.first, match.numberOfRanges > 1 {
                let priceString = nsString.substring(with: match.range(at: 1))
                print("找到标题价格: \(priceString)元/克")
                if let price = Double(priceString) {
                    return price
                }
            }
        }
        
        // 5. 尝试在表格中查找当天日期和价格
        do {
            let pattern = "水贝\\s*黄金价格\\s*(\\d+)元/克\\s*\\d{4}-\\d{1,2}-\\d{1,2}"
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let nsString = html as NSString
            let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
            
            if let match = matches.first, match.numberOfRanges > 1 {
                let priceString = nsString.substring(with: match.range(at: 1))
                print("找到表格中的当天价格: \(priceString)元/克")
                if let price = Double(priceString) {
                    return price
                }
            }
        } catch {
            print("正则表达式错误: \(error.localizedDescription)")
        }
        
        // 如果网页内容较长，尝试截取部分内容打印出来辅助调试
        if html.count > 1000 {
            let startIndex = html.index(html.startIndex, offsetBy: 0)
            let endIndex = html.index(startIndex, offsetBy: min(1000, html.count))
            let previewContent = String(html[startIndex..<endIndex])
            print("HTML内容预览（前1000字符）: \(previewContent)")
        } else {
            print("完整HTML内容: \(html)")
        }
        
        print("未能从jinrijinjia网站提取到金价数据")
        return nil
    }
    
    deinit {
        stopFetching()
    }
}