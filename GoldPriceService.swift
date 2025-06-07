import Foundation
import Combine

enum GoldPriceSource: String, CaseIterable {
    case jdFinance = "京东金融"
    case shuibeiGold = "水贝黄金"
    case zhouDaFu = "周大福"
    case zhouLiuFu = "周六福"
    case zhouDaSheng = "周大生"
    case zhouShengSheng = "周生生"
    case chaoHongJi = "潮宏基"
    case laoFengXiang = "老凤祥"
    case liuFuJewelry = "六福珠宝"
    case laoMiao = "老庙黄金"
    case caiBai = "菜百黄金"
}

struct GoldBrand {
    let id: String
    let name: String
}

extension GoldPriceSource {
    // 获取金店名称的关键词，用于从API品牌列表中匹配
    var brandKeyword: String? {
        switch self {
        case .jdFinance, .shuibeiGold:
            return nil  // 这两个不使用品牌API
        case .zhouDaFu:
            return "周大福"
        case .zhouLiuFu:
            return "周六福"
        case .zhouDaSheng:
            return "周大生"
        case .zhouShengSheng:
            return "周生生"
        case .liuFuJewelry:
            return "六福"
        case .chaoHongJi:
            return "潮宏基"
        case .laoFengXiang:
            return "老凤祥"
        case .laoMiao:
            return "老庙"
        case .caiBai:
            return "菜百"
        }
    }
}

class GoldPriceService: ObservableObject {
    @Published var currentPrice: Double = 0.0
    @Published var currentSource: GoldPriceSource = .jdFinance
    @Published var lastUpdateTime: Date = Date()
    @Published var isLoading: Bool = false
    @Published var priceNotAvailable: Bool = false // 新增属性，标记价格是否不可用
    @Published var availableBrands: [GoldBrand] = []
    @Published var selectedBrand: GoldBrand?
    
    // 为所有数据源存储价格数据
    @Published var allSourcePrices: [GoldPriceSource: Double] = [:]
    @Published var allSourcePriceAvailability: [GoldPriceSource: Bool] = [:]
    
    private var timer: Timer?
    private let refreshInterval: TimeInterval = 1 // 每1s刷新一次
    private var currentFetchingSource: GoldPriceSource?
    
    init() {
        // 初始化时不做任何数据获取，等待startFetching调用
    }
    
    func startFetching() {
        // 初始化所有数据源的价格可用性状态
        for source in GoldPriceSource.allCases {
            allSourcePriceAvailability[source] = false
        }
        
        // 确保品牌列表已加载，然后立即获取所有数据源的数据
        if availableBrands.isEmpty {
            fetchBrandList { [weak self] in
                self?.fetchAllSourcesPricesParallel()
            }
        } else {
            fetchAllSourcesPricesParallel()
        }
        
        // 设置定时器定期获取所有数据源的数据
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.fetchAllSourcesPricesParallel()
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
        case .zhouDaFu, .zhouLiuFu, .zhouDaSheng, .zhouShengSheng, 
             .liuFuJewelry, .chaoHongJi, .laoFengXiang, .laoMiao, .caiBai:
            fetchBrandGoldPrice(source: currentSource)
        }
    }
    
    // 并行获取所有数据源的价格
    func fetchAllSourcesPricesParallel() {
        // 同时获取所有数据源的价格
        for source in GoldPriceSource.allCases {
            fetchPriceForSource(source)
        }
    }
    
    // 循环获取所有数据源的价格（保留备用）
    func fetchAllSourcesPrices() {
        // 为了避免同时发起太多请求，我们按顺序获取，每次获取一个数据源
        let sources = GoldPriceSource.allCases
        if currentFetchingSource == nil {
            currentFetchingSource = sources.first
        }
        
        guard let sourceToFetch = currentFetchingSource else { return }
        
        // 获取指定数据源的价格
        fetchPriceForSource(sourceToFetch)
        
        // 移动到下一个数据源
        if let currentIndex = sources.firstIndex(of: sourceToFetch) {
            let nextIndex = (currentIndex + 1) % sources.count
            currentFetchingSource = sources[nextIndex]
        }
    }
    
    // 为指定数据源获取价格
    private func fetchPriceForSource(_ source: GoldPriceSource) {
        switch source {
        case .jdFinance:
            fetchJDFinanceGoldPrice(for: source)
        case .shuibeiGold:
            fetchShuibeiGoldPrice(for: source)
        case .zhouDaFu, .zhouLiuFu, .zhouDaSheng, .zhouShengSheng, 
             .liuFuJewelry, .chaoHongJi, .laoFengXiang, .laoMiao, .caiBai:
            fetchBrandGoldPrice(source: source, for: source)
        }
    }
    
    // 从京东金融获取黄金价格
    private func fetchJDFinanceGoldPrice(for targetSource: GoldPriceSource? = nil) {
        // 京东金融黄金价格API URL
        let urlString = "https://api.jdjygold.com/gw2/generic/jrm/h5/m/stdLatestPrice?productSku=1961543816"
        
        guard let url = URL(string: urlString) else {
            self.handleFetchError("无效的URL", source: .jdFinance, for: targetSource)
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.handleFetchError(error.localizedDescription, source: .jdFinance, for: targetSource)
                return
            }
            
            guard let data = data else {
                self.handleFetchError("没有返回数据", source: .jdFinance, for: targetSource)
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
                        // 更新所有数据源的价格信息
                        let sourceToUpdate = targetSource ?? .jdFinance
                        self.allSourcePrices[sourceToUpdate] = price
                        self.allSourcePriceAvailability[sourceToUpdate] = true
                        
                        // 如果是当前数据源，也更新主要的价格信息
                        if targetSource == nil || sourceToUpdate == self.currentSource {
                            self.currentPrice = price
                            self.lastUpdateTime = Date()
                            self.isLoading = false
                        }
                        print("京东金融金价获取成功: \(price)")
                    }
                } else {
                    self.handleFetchError("无法解析黄金价格数据", source: .jdFinance, for: targetSource)
                }
            } catch {
                self.handleFetchError("JSON解析错误: \(error.localizedDescription)", source: .jdFinance, for: targetSource)
            }
        }
        
        task.resume()
    }
    
    private func handleFetchError(_ message: String, source: GoldPriceSource? = nil, for targetSource: GoldPriceSource? = nil) {
        let sourceName = source?.rawValue ?? currentSource.rawValue
        print("获取黄金价格失败 [\(sourceName)]: \(message)")
        DispatchQueue.main.async {
            let sourceToUpdate = targetSource ?? source ?? self.currentSource
            self.allSourcePriceAvailability[sourceToUpdate] = false
            
            // 如果是当前数据源，也更新主要的状态
            if targetSource == nil || sourceToUpdate == self.currentSource {
                self.isLoading = false
                self.priceNotAvailable = true
            }
        }
    }
    
    // 从水贝黄金获取黄金价格
    private func fetchShuibeiGoldPrice(for targetSource: GoldPriceSource? = nil) {
        // 尝试从 jinrijinjia.cn 网站获取数据
        let urlString = "http://www.jinrijinjia.cn/shuibei/"
        
        guard let url = URL(string: urlString) else {
            self.handleFetchError("无效的URL", source: .shuibeiGold, for: targetSource)
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
                self.handleFetchError("获取网页失败: \(error.localizedDescription)", source: .shuibeiGold, for: targetSource)
                return
            }
            
            guard let data = data else {
                self.handleFetchError("没有返回数据", source: .shuibeiGold, for: targetSource)
                return
            }
            
            // 先尝试UTF-8编码
            if let htmlString = String(data: data, encoding: .utf8) {
                // 尝试解析HTML内容提取金价
                if let price = self.extractGoldPriceFromJinrijinjia(htmlString) {
                    DispatchQueue.main.async {
                        // 更新所有数据源的价格信息
                        let sourceToUpdate = targetSource ?? .shuibeiGold
                        self.allSourcePrices[sourceToUpdate] = price
                        self.allSourcePriceAvailability[sourceToUpdate] = true
                        
                        // 如果是当前数据源，也更新主要的价格信息
                        if targetSource == nil || sourceToUpdate == self.currentSource {
                            self.currentPrice = price
                            self.lastUpdateTime = Date()
                            self.isLoading = false
                        }
                        print("水贝金价获取成功: \(price)")
                    }
                    return
                }
                
                print("从 jinrijinjia.cn 未能提取金价")
            } else if let htmlString = String(data: data, encoding: .isoLatin1) {
                // 尝试其他编码，如isoLatin1
                if let price = self.extractGoldPriceFromJinrijinjia(htmlString) {
                    DispatchQueue.main.async {
                        // 更新所有数据源的价格信息
                        let sourceToUpdate = targetSource ?? .shuibeiGold
                        self.allSourcePrices[sourceToUpdate] = price
                        self.allSourcePriceAvailability[sourceToUpdate] = true
                        
                        // 如果是当前数据源，也更新主要的价格信息
                        if targetSource == nil || sourceToUpdate == self.currentSource {
                            self.currentPrice = price
                            self.lastUpdateTime = Date()
                            self.isLoading = false
                        }
                        print("水贝金价获取成功(isoLatin1编码): \(price)")
                    }
                    return
                }
                
                print("从 jinrijinjia.cn (isoLatin1编码) 未能提取金价")
            } else {
                self.handleFetchError("无法解析HTML编码", source: .shuibeiGold, for: targetSource)
                return
            }
            
            // 如果无法提取价格数据，返回N/A
            self.handleFetchError("无法从网站提取价格数据", source: .shuibeiGold, for: targetSource)
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
    
    // 获取品牌金店价格
    private func fetchBrandGoldPrice(source: GoldPriceSource, for targetSource: GoldPriceSource? = nil) {
        // 获取品牌关键词
        guard let keyword = source.brandKeyword else {
            handleFetchError("不支持的金店类型", source: source, for: targetSource)
            return
        }
        
        // 如果品牌列表为空，先获取品牌列表
        if availableBrands.isEmpty {
            fetchBrandList { [weak self] in
                self?.fetchBrandGoldPrice(source: source, for: targetSource)
            }
            return
        }
        
        // 根据关键词查找对应品牌
        guard let brand = availableBrands.first(where: { $0.name.contains(keyword) }) else {
            handleFetchError("找不到对应的品牌: \(keyword)", source: source, for: targetSource)
            return
        }
        
        let urlString = "http://s3.ycny.com/2145-2?showapi_appid=1114978&id=\(brand.id)"
        fetchGoldPriceFromAPI(urlString: urlString, source: source, for: targetSource)
    }
    
    private func fetchGoldPriceFromAPI(urlString: String, source: GoldPriceSource, for targetSource: GoldPriceSource? = nil) {
        
        guard let url = URL(string: urlString) else {
            self.handleFetchError("无效的URL", source: source, for: targetSource)
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.handleFetchError("获取品牌金价失败: \(error.localizedDescription)", source: source, for: targetSource)
                return
            }
            
            guard let data = data else {
                self.handleFetchError("没有返回数据", source: source, for: targetSource)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let resBody = json["showapi_res_body"] as? [String: Any],
                   let goldPrice = resBody["goldPrice"] as? Double {
                    
                    DispatchQueue.main.async {
                        // 更新所有数据源的价格信息
                        let sourceToUpdate = targetSource ?? source
                        self.allSourcePrices[sourceToUpdate] = goldPrice
                        self.allSourcePriceAvailability[sourceToUpdate] = true
                        
                        // 如果是当前数据源，也更新主要的价格信息
                        if targetSource == nil || sourceToUpdate == self.currentSource {
                            self.currentPrice = goldPrice
                            self.lastUpdateTime = Date()
                            self.isLoading = false
                        }
                        print("\(source.rawValue)金价获取成功: \(goldPrice)")
                    }
                } else {
                    self.handleFetchError("无法解析品牌金价数据", source: source, for: targetSource)
                }
            } catch {
                self.handleFetchError("JSON解析错误: \(error.localizedDescription)", source: source, for: targetSource)
            }
        }
        
        task.resume()
    }
    
    // 获取品牌列表
    func fetchBrandList(completion: (() -> Void)? = nil) {
        let urlString = "http://www.kdmoney.com/js/gold2024script.js"
        
        guard let url = URL(string: urlString) else {
            print("获取品牌列表失败: 无效的URL")
            completion?()
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("获取品牌列表失败: \(error.localizedDescription)")
                completion?()
                return
            }
            
            guard let data = data,
                  let content = String(data: data, encoding: .utf8) else {
                print("获取品牌列表失败: 无法解析数据")
                completion?()
                return
            }
            
            let brands = self.parseBrandList(from: content)
            
            DispatchQueue.main.async {
                self.availableBrands = brands
                
                // 如果没有选中的品牌，选择第一个包含功能清单中品牌的默认品牌
                if self.selectedBrand == nil {
                    // 优先选择功能清单中的品牌
                    let priorityBrands = ["周大福", "周六福", "周大生", "周生生", "老凤祥", "老庙", "菜百"]
                    for priorityBrand in priorityBrands {
                        if let brand = brands.first(where: { $0.name.contains(priorityBrand) }) {
                            self.selectedBrand = brand
                            break
                        }
                    }
                    
                    // 如果找不到优先品牌，选择第一个
                    if self.selectedBrand == nil && !brands.isEmpty {
                        self.selectedBrand = brands.first
                    }
                }
                
                print("品牌列表获取成功，共\(brands.count)个品牌")
                completion?()
            }
        }
        
        task.resume()
    }
    
    // 解析品牌列表
    private func parseBrandList(from content: String) -> [GoldBrand] {
        var brands: [GoldBrand] = []
        
        // 使用正则表达式匹配品牌信息
        let pattern = "\\{\"_id\":\\s*\"([^\"]+)\",\\s*\"brand\":\\s*\"([^\"]+)\"\\}"
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let nsString = content as NSString
            let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in matches {
                if match.numberOfRanges >= 3 {
                    let id = nsString.substring(with: match.range(at: 1))
                    let name = nsString.substring(with: match.range(at: 2))
                    brands.append(GoldBrand(id: id, name: name))
                }
            }
        } catch {
            print("解析品牌列表失败: \(error.localizedDescription)")
        }
        
        return brands
    }
    
    // 设置选中的品牌
    func setSelectedBrand(_ brand: GoldBrand) {
        self.selectedBrand = brand
        // 现在每个金店都是独立的数据源，不需要这个检查
        fetchGoldPrice() // 立即获取新品牌的价格
    }
    
    deinit {
        stopFetching()
    }
}