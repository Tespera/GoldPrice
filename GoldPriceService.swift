import Foundation
import Combine

enum GoldPriceSource: String, CaseIterable {
    case jdZsFinance = "京东浙商"
    case jdMsFinance = "京东民生"
    case shuibeiGold = "水贝黄金"
    case zhouDaFu = "周大福"
    case laoFengXiang = "老凤祥"
    case zhouLiuFu = "周六福"
    case zhouShengSheng = "周生生"
    case liuFuJewelry = "六福珠宝"
    case laoMiao = "老庙黄金"
    case jinZhiZun = "金至尊"
    case zhongGuoHuangJin = "中国黄金"
    case zhouDaSheng = "周大生"
    case chaoHongJi = "潮宏基"
    case baoQingYinLou = "宝庆银楼"
    case caiBai = "菜百黄金"
}

struct ShuibeiMarketPrice: Identifiable {
    let id = UUID()
    let name: String
    let price: Double
    let time: String
}

extension GoldPriceSource {
    /// 中国黄金网 API 对应的 JO_ 代码（仅品牌金店有）
    var cngoldCode: String? {
        switch self {
        case .jdZsFinance, .jdMsFinance, .shuibeiGold, .zhongGuoHuangJin:
            return nil
        case .zhouDaFu: return "JO_42660"
        case .laoFengXiang: return "JO_42657"
        case .zhouLiuFu: return "JO_42653"
        case .zhouShengSheng: return "JO_42625"
        case .liuFuJewelry: return "JO_42646"
        case .laoMiao: return "JO_42634"
        case .jinZhiZun: return "JO_42632"
        case .zhouDaSheng: return "JO_52678"
        case .chaoHongJi: return "JO_52670"
        case .baoQingYinLou: return "JO_52674"
        case .caiBai: return "JO_42638"
        }
    }

    /// 是否为品牌金店数据源
    var isBrandSource: Bool {
        return cngoldCode != nil
    }
}

class GoldPriceService: ObservableObject {
    @Published var currentSource: GoldPriceSource = .jdZsFinance
    @Published var lastUpdateTime: Date = Date()
    @Published var isLoading: Bool = false
    @Published var shuibeiDetailPrices: [ShuibeiMarketPrice] = []

    @Published var allSourcePrices: [GoldPriceSource: Double] = [:]
    @Published var allSourcePriceAvailability: [GoldPriceSource: Bool] = [:]
    @Published var lastNonJDUpdateTime: Date?

    private var timer: Timer?
    private let jdRefreshInterval: TimeInterval = 1        // 京东每1s刷新一次
    private let nonJDRefreshInterval: TimeInterval = 600   // 水贝和品牌金店每10分钟刷新一次
    private var lastNonJDFetchTime: Date = Date(timeIntervalSince1970: 0)

    init() {}

    func startFetching() {
        for source in GoldPriceSource.allCases {
            allSourcePriceAvailability[source] = false
        }

        fetchGoldPrice()
        fetchAllSourcesPricesParallel()
        lastNonJDFetchTime = Date()
        lastNonJDUpdateTime = Date()

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
        case .jdZsFinance:
            fetchJDZsFinanceGoldPrice()
        case .jdMsFinance:
            fetchJDMsFinanceGoldPrice()
        case .shuibeiGold:
            fetchShuibeiGoldPrice()
        case .zhongGuoHuangJin:
            fetchZhongGuoHuangJinGoldPrice()
        default:
            if currentSource.isBrandSource {
                fetchCngoldBrandPrices()
            }
        }
    }

    func fetchAllSourcesPricesParallel() {
        fetchPriceForSource(.jdZsFinance)
        fetchPriceForSource(.jdMsFinance)
        fetchPriceForSource(.shuibeiGold)
        fetchPriceForSource(.zhongGuoHuangJin)
        fetchCngoldBrandPrices()
    }

    // 强制刷新所有数据源（忽略时间限制）
    func forceRefreshAllSources(completion: (() -> Void)? = nil) {
        fetchAllSourcesPricesParallel()
        lastNonJDFetchTime = Date()
        lastNonJDUpdateTime = Date()

        DispatchQueue.main.async {
            completion?()
        }
    }

    func fetchAllSourcesPricesWithDifferentIntervals() {
        let currentTime = Date()

        // 京东每次都刷新（因为定时器间隔就是京东的刷新间隔）
        fetchPriceForSource(.jdZsFinance)
        fetchPriceForSource(.jdMsFinance)

        // 水贝和品牌金店：统一每10分钟刷新一次
        if currentTime.timeIntervalSince(lastNonJDFetchTime) >= nonJDRefreshInterval {
            fetchPriceForSource(.shuibeiGold)
            fetchCngoldBrandPrices()
            fetchPriceForSource(.zhongGuoHuangJin)
            lastNonJDFetchTime = currentTime
            lastNonJDUpdateTime = currentTime
        }
    }

    private func fetchPriceForSource(_ source: GoldPriceSource) {
        switch source {
        case .jdZsFinance:
            fetchJDZsFinanceGoldPrice(for: source)
        case .jdMsFinance:
            fetchJDMsFinanceGoldPrice(for: source)
        case .shuibeiGold:
            fetchShuibeiGoldPrice(for: source)
        case .zhongGuoHuangJin:
            fetchZhongGuoHuangJinGoldPrice(for: source)
        default:
            break // 品牌金店通过 fetchCngoldBrandPrices 批量获取
        }
    }

    // MARK: - 中国黄金网 API（品牌金店批量获取）

    private func fetchCngoldBrandPrices() {
        // 收集所有品牌金店的 JO_ 代码
        let brandSources = GoldPriceSource.allCases.filter { $0.isBrandSource }
        let codes = brandSources.compactMap { $0.cngoldCode }.joined(separator: ",")

        let urlString = "https://api.jijinhao.com/quoteCenter/realTime.htm?codes=\(codes)"

        guard let url = URL(string: urlString) else {
            for source in brandSources {
                handleFetchError("无效的URL", source: source, for: source)
            }
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("https://quote.cngold.org/", forHTTPHeaderField: "Referer")

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                for source in brandSources {
                    self.handleFetchError("获取品牌金价失败: \(error.localizedDescription)", source: source, for: source)
                }
                return
            }

            guard let data = data,
                  let responseString = String(data: data, encoding: .utf8) else {
                for source in brandSources {
                    self.handleFetchError("没有返回数据", source: source, for: source)
                }
                return
            }

            // 响应格式: var quote_json = {...}
            // 去掉 "var quote_json = " 前缀
            let jsonString: String
            if let prefixRange = responseString.range(of: "var quote_json = ") {
                jsonString = String(responseString[prefixRange.upperBound...])
            } else {
                jsonString = responseString
            }

            guard let jsonData = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                for source in brandSources {
                    self.handleFetchError("无法解析API响应", source: source, for: source)
                }
                return
            }

            DispatchQueue.main.async {
                for source in brandSources {
                    guard let code = source.cngoldCode,
                          let quoteData = json[code] as? [String: Any],
                          let price = quoteData["q63"] as? Double,
                          price > 0 else {
                        self.allSourcePriceAvailability[source] = false
                        continue
                    }

                    self.allSourcePrices[source] = price
                    self.allSourcePriceAvailability[source] = true

                    if source == self.currentSource {
                        self.lastUpdateTime = Date()
                        self.isLoading = false
                    }
                    print("\(source.rawValue)金价获取成功: \(price)")
                }
            }
        }

        task.resume()
    }

    // MARK: - 京东浙商

    private func fetchJDZsFinanceGoldPrice(for targetSource: GoldPriceSource? = nil) {
        let urlString = "https://api.jdjygold.com/gw2/generic/jrm/h5/m/stdLatestPrice?productSku=1961543816"

        guard let url = URL(string: urlString) else {
            self.handleFetchError("无效的URL", source: .jdZsFinance, for: targetSource)
            return
        }

        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                self.handleFetchError(error.localizedDescription, source: .jdZsFinance, for: targetSource)
                return
            }

            guard let data = data else {
                self.handleFetchError("没有返回数据", source: .jdZsFinance, for: targetSource)
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let resultData = json["resultData"] as? [String: Any],
                   let datas = resultData["datas"] as? [String: Any],
                   let priceStr = datas["price"] as? String,
                   let price = Double(priceStr) {

                    DispatchQueue.main.async {
                        let sourceToUpdate = targetSource ?? .jdZsFinance
                        self.allSourcePrices[sourceToUpdate] = price
                        self.allSourcePriceAvailability[sourceToUpdate] = true

                        if targetSource == nil || sourceToUpdate == self.currentSource {
                            self.lastUpdateTime = Date()
                            self.isLoading = false
                        }
                        print("京东浙商金价获取成功: \(price)")
                    }
                } else {
                    self.handleFetchError("无法解析黄金价格数据", source: .jdZsFinance, for: targetSource)
                }
            } catch {
                self.handleFetchError("JSON解析错误: \(error.localizedDescription)", source: .jdZsFinance, for: targetSource)
            }
        }

        task.resume()
    }

    // MARK: - 京东民生

    private func fetchJDMsFinanceGoldPrice(for targetSource: GoldPriceSource? = nil) {
        let urlString = "https://api.jdjygold.com/gw/generic/hj/h5/m/latestPrice?reqData={}"

        guard let url = URL(string: urlString) else {
            self.handleFetchError("无效的URL", source: .jdMsFinance, for: targetSource)
            return
        }

        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                self.handleFetchError(error.localizedDescription, source: .jdMsFinance, for: targetSource)
                return
            }

            guard let data = data else {
                self.handleFetchError("没有返回数据", source: .jdMsFinance, for: targetSource)
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let resultData = json["resultData"] as? [String: Any],
                   let datas = resultData["datas"] as? [String: Any],
                   let priceStr = datas["price"] as? String,
                   let price = Double(priceStr) {

                    DispatchQueue.main.async {
                        let sourceToUpdate = targetSource ?? .jdMsFinance
                        self.allSourcePrices[sourceToUpdate] = price
                        self.allSourcePriceAvailability[sourceToUpdate] = true

                        if targetSource == nil || sourceToUpdate == self.currentSource {
                            self.lastUpdateTime = Date()
                            self.isLoading = false
                        }
                        print("京东民生银行金价获取成功: \(price)")
                    }
                } else {
                    self.handleFetchError("无法解析黄金价格数据", source: .jdMsFinance, for: targetSource)
                }
            } catch {
                self.handleFetchError("JSON解析错误: \(error.localizedDescription)", source: .jdMsFinance, for: targetSource)
            }
        }

        task.resume()
    }

    // MARK: - 水贝黄金

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
                    let total = prices.reduce(0.0) { $0 + $1.price }
                    let average = total / Double(prices.count)
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

    private func extractShuibeiGoldPricesFromCnGoldPrice(_ html: String) -> [ShuibeiMarketPrice] {
        var prices: [ShuibeiMarketPrice] = []

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

    // MARK: - 中国黄金

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

            var htmlString: String?
            let gb2312Encoding = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_2312_80.rawValue))
            if let gbString = String(data: data, encoding: String.Encoding(rawValue: gb2312Encoding)) {
                htmlString = gbString
            } else if let utf8String = String(data: data, encoding: .utf8) {
                htmlString = utf8String
            } else if let latinString = String(data: data, encoding: .isoLatin1) {
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
        let patterns = [
            "<div class=\"number\">(\\d+)</div>\\s*<div class=\"text\">999[^<]*黄金价格</div>",
            "<div class=\"number\">(\\d+)</div>[\\s\\S]*?999[^<]*黄金价格",
            "999[^<]*黄金价格[\\s\\S]*?<div class=\"number\">(\\d+)</div>",
            "<div class=\"number\">(\\d+)</div>\\s*<div class=\"text\">[^<]*999[^<]*</div>",
            "<div class=\"priceinfo confirm\">[\\s\\S]*?<div class=\"number\">(\\d+)</div>",
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
                        return price
                    }
                }
            }
        }

        return nil
    }

    // MARK: - 错误处理

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

    deinit {
        stopFetching()
    }
}
