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
            
            do {
                // 解析JSON数据
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let resultData = json["resultData"] as? [String: Any],
                   let datas = resultData["datas"] as? [String: Any],
                   let priceStr = datas["price"] as? String,
                   let price = Double(priceStr) {
                    
                    DispatchQueue.main.async {
                        let sourceToUpdate = targetSource ?? .jdFinance
                        self.allSourcePrices[sourceToUpdate] = price
                        self.allSourcePriceAvailability[sourceToUpdate] = true
                        
                        if targetSource == nil || sourceToUpdate == self.currentSource {
                            self.currentPrice = price
                            self.lastUpdateTime = Date()
                            self.isLoading = false
                        }
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
    
    // 从水贝黄金获取黄金价格
    private func fetchShuibeiGoldPrice(for targetSource: GoldPriceSource? = nil) {
        let urlString = "http://www.jinrijinjia.cn/shuibei/"
        
        guard let url = URL(string: urlString) else {
            self.handleFetchError("无效的URL", source: .shuibeiGold, for: targetSource)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        
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
            
            if let htmlString = String(data: data, encoding: .utf8) {
                if let price = self.extractGoldPriceFromJinrijinjia(htmlString) {
                    DispatchQueue.main.async {
                        let sourceToUpdate = targetSource ?? .shuibeiGold
                        self.allSourcePrices[sourceToUpdate] = price
                        self.allSourcePriceAvailability[sourceToUpdate] = true
                        
                        if targetSource == nil || sourceToUpdate == self.currentSource {
                            self.currentPrice = price
                            self.lastUpdateTime = Date()
                            self.isLoading = false
                        }
                    }
                    return
                }
            }
            
            self.handleFetchError("无法从网站提取价格数据", source: .shuibeiGold, for: targetSource)
        }
        
        task.resume()
    }
    
    // 从品牌API获取黄金价格
    private func fetchBrandGoldPrice(source: GoldPriceSource, for targetSource: GoldPriceSource? = nil) {
        guard let keyword = source.brandKeyword else {
            handleFetchError("不支持的金店类型", source: source, for: targetSource)
            return
        }
        
        if availableBrands.isEmpty {
            fetchBrandList { [weak self] in
                self?.fetchBrandGoldPrice(source: source, for: targetSource)
            }
            return
        }
        
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
                        let sourceToUpdate = targetSource ?? source
                        self.allSourcePrices[sourceToUpdate] = goldPrice
                        self.allSourcePriceAvailability[sourceToUpdate] = true
                        
                        if targetSource == nil || sourceToUpdate == self.currentSource {
                            self.currentPrice = goldPrice
                            self.lastUpdateTime = Date()
                            self.isLoading = false
                        }
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
    func fetchBrandList(_ completion: (() -> Void)? = nil) {
        let urlString = "http://s3.ycny.com/2145-1?showapi_appid=1114978"
        
        guard let url = URL(string: urlString) else {
            print("无效的品牌列表URL")
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
            
            guard let data = data else {
                print("品牌列表没有返回数据")
                completion?()
                return
            }
            
            let brands = self.parseBrandList(from: String(data: data, encoding: .utf8) ?? "")
            
            DispatchQueue.main.async {
                self.availableBrands = brands
                completion?()
            }
        }
        
        task.resume()
    }
    
    // 解析品牌列表
    private func parseBrandList(from content: String) -> [GoldBrand] {
        var brands: [GoldBrand] = []
        
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
    
    // 从HTML中提取金价
    private func extractGoldPriceFromJinrijinjia(_ html: String) -> Double? {
        let patterns = [
            "<span class=\"price\">([0-9.]+)</span>",
            "水贝黄金.*?([0-9]+\\.?[0-9]*)",
            "价格.*?([0-9]+\\.?[0-9]*)"
        ]
        
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let nsString = html as NSString
                let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
                
                for match in matches {
                    if match.numberOfRanges >= 2 {
                        let priceString = nsString.substring(with: match.range(at: 1))
                        if let price = Double(priceString), price > 200 && price < 1000 {
                            return price
                        }
                    }
                }
            } catch {
                continue
            }
        }
        
        return nil
    }
    
    private func handleFetchError(_ message: String, source: GoldPriceSource? = nil, for targetSource: GoldPriceSource? = nil) {
        let sourceName = source?.rawValue ?? currentSource.rawValue
        print("获取黄金价格失败 [\(sourceName)]: \(message)")
        DispatchQueue.main.async {
            let sourceToUpdate = targetSource ?? source ?? self.currentSource
            self.allSourcePriceAvailability[sourceToUpdate] = false
            
            if targetSource == nil || sourceToUpdate == self.currentSource {
                self.isLoading = false
                self.priceNotAvailable = true
            }
        }
    }
    
    deinit {
        stopFetching()
    }
}