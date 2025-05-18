import Foundation

class GoldPriceService {
    static func fetchGoldPrice(completion: @escaping (Double?) -> Void) {
        let url = URL(string: "https://api.example.com/gold-price")
        
        guard let requestUrl = url else {
            completion(nil)
            return
        }
        
        let task = URLSession.shared.dataTask(with: requestUrl) { (data, response, error) in
            if let error = error {
                print("Error fetching gold price: \(error)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                completion(nil)
                return
            }
            
            // 模拟解析数据，实际应用中应根据API返回格式解析
            // 这里简单返回一个模拟的黄金价格
            completion(1923.45)
        }
        
        task.resume()
    }
}
