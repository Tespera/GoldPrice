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
    case zhongGuoHuangJin = "中国黄金"
    case liuFuJewelry = "六福珠宝"
    case laoMiao = "老庙黄金"
    case caiBai = "菜百黄金"
}

struct GoldBrand {
    let id: String
    let name: String
}

struct ShuibeiMarketPrice: Identifiable {
    let id = UUID()
    let name: String
    let price: Double
    let time: String
}

extension GoldPriceSource {
    var brandKeyword: String? {
        switch self {
        case .jdFinance, .shuibeiGold:
            return nil
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
        case .zhongGuoHuangJin:
            return "中国黄金"
        }
    }
}

class GoldPriceService: ObservableObject {
    @Published var currentSource: GoldPriceSource = .jdFinance
    @Published var lastUpdateTime: Date = Date()
    @Published var isLoading: Bool = false
    @Published var availableBrands: [GoldBrand] = []
    @Published var selectedBrand: GoldBrand?
    @Published var shuibeiDetailPrices: [ShuibeiMarketPrice] = []
    
    @Published var allSourcePrices: [GoldPriceSource: Double] = [:]
    @Published var allSourcePriceAvailability: [GoldPriceSource: Bool] = [:]
    
    private var timer: Timer?
    private let jdRefreshInterval: TimeInterval = 1        // 京东每1s刷新一次
    private let shuibeiRefreshInterval: TimeInterval = 300  // 水贝每5分钟刷新一次
    private let brandStoreRefreshInterval: TimeInterval = 300    // 金店每5分钟刷新一次
    private var currentFetchingSource: GoldPriceSource?
    private var lastShuibeiFetchTime: Date = Date(timeIntervalSince1970: 0)
    private var lastBrandStoreFetchTime: Date = Date(timeIntervalSince1970: 0)
    
    init() {}
    
    func startFetching() {
        for source in GoldPriceSource.allCases {
            allSourcePriceAvailability[source] = false
        }
        
        fetchGoldPrice()
        
        if availableBrands.isEmpty {
            fetchBrandList { [weak self] in
                self?.fetchAllSourcesPricesParallel()
                // 初始化时立即获取所有数据源的价格
                self?.lastBrandStoreFetchTime = Date()
            }
        } else {
            fetchAllSourcesPricesParallel()
            // 初始化时立即获取所有数据源的价格
            // 更新水贝和金店刷新时间，确保下次正常刷新
            lastShuibeiFetchTime = Date()
            lastBrandStoreFetchTime = Date()
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: jdRefreshInterval, repeats: true) { [weak self] _ in
            self?.fetchAllSourcesPricesWithDifferentIntervals()
        }
    }
    
    func stopFetching() {
        timer?.invalidate()
        timer = nil
    }
    
    func setDataSource(_ source: GoldPriceSource) {
        self.currentSource = source
        fetchGoldPrice()
    }
    
    func fetchGoldPrice() {
        isLoading = true
        
        switch currentSource {
        case .jdFinance:
            fetchJDFinanceGoldPrice()
        case .shuibeiGold:
            fetchShuibeiGoldPrice()
        case .zhongGuoHuangJin:
            fetchZhongGuoHuangJinGoldPrice()
        case .zhouDaFu, .zhouLiuFu, .zhouDaSheng, .zhouShengSheng, 
             .liuFuJewelry, .chaoHongJi, .laoFengXiang, .laoMiao, .caiBai:
            fetchBrandGoldPrice(source: currentSource)
        }
    }
    
    func fetchAllSourcesPricesParallel() {
        for source in GoldPriceSource.allCases {
            fetchPriceForSource(source)
        }
    }
    
    // 强制刷新所有数据源（忽略时间限制）
    func forceRefreshAllSources(completion: (() -> Void)? = nil) {
        for source in GoldPriceSource.allCases {
            fetchPriceForSource(source)
        }
        // 更新金店刷新时间，确保下次正常刷新
        lastBrandStoreFetchTime = Date()
        
        // 如果有回调，立即调用（因为数据会异步更新，这里主要是为了触发UI刷新）
        DispatchQueue.main.async {
            completion?()
        }
    }
    
    func fetchAllSourcesPricesWithDifferentIntervals() {
        let currentTime = Date()
        
        // 京东每次都刷新（因为定时器间隔就是京东的刷新间隔）
        fetchPriceForSource(.jdFinance)
        
        // 水贝：检查是否已经过了指定的刷新间隔
        if currentTime.timeIntervalSince(lastShuibeiFetchTime) >= shuibeiRefreshInterval {
            fetchPriceForSource(.shuibeiGold)
            lastShuibeiFetchTime = currentTime
        }
        
        // 金店类型的数据源：检查是否已经过了指定的刷新间隔
        if currentTime.timeIntervalSince(lastBrandStoreFetchTime) >= brandStoreRefreshInterval {
            let brandSources: [GoldPriceSource] = [.zhouDaFu, .zhouLiuFu, .zhouDaSheng, .zhouShengSheng, 
                                                   .chaoHongJi, .laoFengXiang, .zhongGuoHuangJin, .liuFuJewelry, 
                                                   .laoMiao, .caiBai]
            
            for source in brandSources {
                fetchPriceForSource(source)
            }
            
            lastBrandStoreFetchTime = currentTime
        }
    }
    

    private func fetchPriceForSource(_ source: GoldPriceSource) {
        switch source {
        case .jdFinance:
            fetchJDFinanceGoldPrice(for: source)
        case .shuibeiGold:
            fetchShuibeiGoldPrice(for: source)
        case .zhongGuoHuangJin:
            fetchZhongGuoHuangJinGoldPrice(for: source)
        case .zhouDaFu, .zhouLiuFu, .zhouDaSheng, .zhouShengSheng, 
             .liuFuJewelry, .chaoHongJi, .laoFengXiang, .laoMiao, .caiBai:
            fetchBrandGoldPrice(source: source, for: source)
        }
    }
    
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
            
            if targetSource == nil || sourceToUpdate == self.currentSource {
                self.isLoading = false
            }
        }
    }
    
    private func fetchShuibeiGoldPrice(for targetSource: GoldPriceSource? = nil) {
        let urlString = "https://cngoldprice.com/"
        
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
                self.handleFetchError("获取水贝金价失败: \(error.localizedDescription)", source: .shuibeiGold, for: targetSource)
                return
            }
            
            guard let data = data else {
                self.handleFetchError("没有返回数据", source: .shuibeiGold, for: targetSource)
                return
            }
            
            if let htmlString = String(data: data, encoding: .utf8) {
                let prices = self.extractShuibeiGoldPricesFromCnGoldPrice(htmlString)
                
                if !prices.isEmpty {
                    // 计算均价
                    let total = prices.reduce(0.0) { $0 + $1.price }
                    let average = total / Double(prices.count)
                    // 保留两位小数
                    let roundedAverage = (average * 100).rounded() / 100
                    
                    DispatchQueue.main.async {
                        self.shuibeiDetailPrices = prices
                        
                        let sourceToUpdate = targetSource ?? .shuibeiGold
                        self.allSourcePrices[sourceToUpdate] = roundedAverage
                        self.allSourcePriceAvailability[sourceToUpdate] = true
                        
                        if targetSource == nil || sourceToUpdate == self.currentSource {
                            self.lastUpdateTime = Date()
                            self.isLoading = false
                        }
                        print("水贝金价获取成功: 均价 \(roundedAverage), 共 \(prices.count) 个市场数据")
                    }
                    return
                }
            }
            
            self.handleFetchError("无法从网站提取价格数据", source: .shuibeiGold, for: targetSource)
        }
        
        task.resume()
    }
    
    private func extractGoldPriceFromJinrijinjia(_ html: String) -> Double? {
        let patterns = [
            "足金999价格(\\d+)元克",
            "(\\d+)\\s*元/克",
            "黄金价格\\s*(\\d+)元/克",
            "深圳水贝今日黄金最新价[\\s\\n]*#?\\s*(\\d+)",
            "水贝\\s*黄金价格\\s*(\\d+)元/克\\s*\\d{4}-\\d{1,2}-\\d{1,2}",
            "水贝首饰金\\s*(\\d+)元/克\\s*\\d{4}-\\d{1,2}-\\d{1,2}"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let nsString = html as NSString
                let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
                
                if let match = matches.first, match.numberOfRanges > 1 {
                    let priceString = nsString.substring(with: match.range(at: 1))
                    if let price = Double(priceString) {
                        return price
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractShuibeiGoldPricesFromCnGoldPrice(_ html: String) -> [ShuibeiMarketPrice] {
        var prices: [ShuibeiMarketPrice] = []
        
        // 匹配表格行：
        // <td ...>水贝特力</td> <td ...>1105</td> <td ...>938</td> <td ...>2025...</td>
        // 使用宽松的正则匹配
        let pattern = "<td[^>]*>\\s*(水贝[^<]+)\\s*</td>\\s*<td[^>]*>\\s*(\\d+(?:\\.\\d+)?)\\s*</td>\\s*<td[^>]*>\\s*.*?\\s*</td>\\s*<td[^>]*>\\s*([^<]+)\\s*</td>"
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) {
            let nsString = html as NSString
            let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in matches {
                if match.numberOfRanges >= 4 {
                    let name = nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                    let priceString = nsString.substring(with: match.range(at: 2))
                    let time = nsString.substring(with: match.range(at: 3)).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if let price = Double(priceString) {
                        prices.append(ShuibeiMarketPrice(name: name, price: price, time: time))
                    }
                }
            }
        }
        
        return prices
    }
    
    private func fetchZhongGuoHuangJinGoldPrice(for targetSource: GoldPriceSource? = nil) {
        let urlString = "http://www.huangjinjiage.cn/zghj/"
        
        guard let url = URL(string: urlString) else {
            self.handleFetchError("无效的URL", source: .zhongGuoHuangJin, for: targetSource)
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
                self.handleFetchError("获取品牌金价失败: \(error.localizedDescription)", source: .zhongGuoHuangJin, for: targetSource)
                return
            }
            
            guard let data = data else {
                self.handleFetchError("没有返回数据", source: .zhongGuoHuangJin, for: targetSource)
                return
            }
            
            // 尝试多种编码方式解析HTML
            var htmlString: String?
            
            // 首先尝试GB2312编码（网页明确标注为gb2312）
            let gb2312Encoding = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_2312_80.rawValue))
            if let gbString = String(data: data, encoding: String.Encoding(rawValue: gb2312Encoding)) {
                htmlString = gbString
            }
            // 备用UTF-8
            else if let utf8String = String(data: data, encoding: .utf8) {
                htmlString = utf8String
            }
            // 最后尝试ISO Latin1
            else if let latinString = String(data: data, encoding: .isoLatin1) {
                htmlString = latinString
            }
            
            if let html = htmlString,
               let price = self.extractZhongGuoHuangJinPrice(html) {
                DispatchQueue.main.async {
                    let sourceToUpdate = targetSource ?? .zhongGuoHuangJin
                    self.allSourcePrices[sourceToUpdate] = price
                    self.allSourcePriceAvailability[sourceToUpdate] = true
                    
                    if targetSource == nil || sourceToUpdate == self.currentSource {
                        self.lastUpdateTime = Date()
                        self.isLoading = false
                    }
                    print("中国黄金金价获取成功: \(price)")
                }
            } else if htmlString != nil {
                self.handleFetchError("无法从网站提取价格数据", source: .zhongGuoHuangJin, for: targetSource)
            } else {
                self.handleFetchError("无法解析HTML编码", source: .zhongGuoHuangJin, for: targetSource)
            }
        }
        
        task.resume()
    }
    
    private func extractZhongGuoHuangJinPrice(_ html: String) -> Double? {
        // 根据实际HTML结构提取999黄金价格
        let patterns = [
            // 基于实际HTML结构：<div class="number">993</div><div class="text">999黄金价格</div>
            "<div class=\"number\">(\\d+)</div>\\s*<div class=\"text\">999[^<]*黄金价格</div>",
            "<div class=\"number\">(\\d+)</div>[\\s\\S]*?999[^<]*黄金价格",
            "999[^<]*黄金价格[\\s\\S]*?<div class=\"number\">(\\d+)</div>",
            // 支持GB2312编码的匹配（可能显示为乱码）
            "<div class=\"number\">(\\d+)</div>\\s*<div class=\"text\">[^<]*999[^<]*</div>",
            // 通用数字匹配，在价格区域内
            "<div class=\"priceinfo confirm\">[\\s\\S]*?<div class=\"number\">(\\d+)</div>",
            // 简单的数字匹配作为后备
            "999.*?(\\d{3})",
            "(\\d{3}).*?999"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) {
                let nsString = html as NSString
                let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
                
                if let match = matches.first, match.numberOfRanges > 1 {
                    let priceString = nsString.substring(with: match.range(at: 1))
                    if let price = Double(priceString), price > 500 && price < 2000 {
                        // 价格范围合理性检查
                        return price
                    }
                }
            }
        }
        
        return nil
    }
    
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
                
                if self.selectedBrand == nil {
                    let priorityBrands = ["周大福", "周六福", "周大生", "周生生", "老凤祥", "老庙", "菜百"]
                    for priorityBrand in priorityBrands {
                        if let brand = brands.first(where: { $0.name.contains(priorityBrand) }) {
                            self.selectedBrand = brand
                            break
                        }
                    }
                    
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
