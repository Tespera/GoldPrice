import SwiftUI

struct GoldPriceView: View {
    @ObservedObject var dataService: GoldPriceService
    private let dateFormatter: DateFormatter
    
    init(dataService: GoldPriceService) {
        self.dataService = dataService
        
        // 初始化日期格式化器
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            Text("黄金价格")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
            
            Divider()
            
            // 价格信息
            HStack {
                Text("当前价格:")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                
                Spacer()
                
                if dataService.priceNotAvailable {
                    Text("G0.00")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.gray)
                } else {
                    // 根据数据源类型决定显示格式，界面中不需要固定宽度
                    let formatString = dataService.currentSource == .jdFinance ? "G%.2f" : "G%.0f"
                    Text(String(format: formatString, dataService.currentPrice))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                }
            }
            .padding(.horizontal, 16)
            
            // 数据源信息
            HStack {
                Text("数据来源:")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(dataService.currentSource.rawValue)
                    .font(.system(size: 14))
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 16)
            
            // 更新时间
            HStack {
                Text("更新时间:")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(dateFormatter.string(from: dataService.lastUpdateTime))
                    .font(.system(size: 14))
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 16)
            
            Divider()
            
            // 数据源选择
            Text("切换数据源:")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .padding(.horizontal, 16)
            
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(GoldPriceSource.allCases, id: \.self) { source in
                        Button(action: {
                            dataService.setDataSource(source)
                        }) {
                            HStack {
                                Text(source.rawValue)
                                    .font(.system(size: 14))
                                    .foregroundColor(.black)
                                
                                Spacer()
                                
                                if dataService.currentSource == source {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(dataService.currentSource == source ? Color.blue.opacity(0.1) : Color.clear)
                            .cornerRadius(4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .frame(maxHeight: 200)
            
            Spacer()
            
            // 刷新按钮
            Button(action: {
                dataService.fetchGoldPrice()
            }) {
                HStack {
                    Spacer()
                    
                    if dataService.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .padding(.trailing, 8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.white)
                            .padding(.trailing, 8)
                    }
                    
                    Text("刷新")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.vertical, 8)
                .background(Color.blue)
                .cornerRadius(8)
                .padding(.horizontal, 16)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.bottom, 16)
        }
        .frame(width: 300, height: 350)
        .background(Color.white)
    }
}

// 预览
struct GoldPriceView_Previews: PreviewProvider {
    static var previews: some View {
        GoldPriceView(dataService: GoldPriceService())
    }
}