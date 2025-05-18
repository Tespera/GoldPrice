import SwiftUI

struct GoldPriceView: View {
    @State private var goldPrice: Double?
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 20) {
            Text("黄金价格")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if isLoading {
                ProgressView("加载中...")
            } else if let price = goldPrice {
                Text("¥\(String(format: "%.2f", price))")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.yellow)
            } else {
                Text("无法获取价格")
                    .foregroundColor(.red)
            }
            
            Button("刷新") {
                refreshPrice()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
        .frame(width: 300, height: 200)
        .onAppear {
            refreshPrice()
        }
    }
    
    private func refreshPrice() {
        isLoading = true
        GoldPriceService.fetchGoldPrice { price in
            DispatchQueue.main.async {
                self.goldPrice = price
                self.isLoading = false
            }
        }
    }
}
