import SwiftUI
import SwiftData

struct BillHomeView: View {
    @EnvironmentObject var manager: DataManager
    @Environment(\.modelContext) var context
    @Query(sort: \Transaction.date, order: .reverse) var dbTransactions: [Transaction]
    
    // 1. 自动计算总支出
    // reduce 是一个高阶函数：把数组里的每一项 ($1) 的 amount 加到初始值 0 ($0) 上
    var totalExpense: Double {
            dbTransactions.reduce(0) { $0 + $1.amount }
        }
        
    // 2. 计算总返现
    var totalCashback: Double {
            dbTransactions.reduce(0) {
                $0 + CashbackService.calculateCashback(for: $1, in: manager.cards)
            }
        }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // --- 3. 消失的统计条 (这里加回来了！) ---
                        // 而且现在它是动态的，数字会随着你记账自动变！
                        HStack(spacing: 15) {
                            StatBox(
                                title: "本月支出",
                                amount: "¥\(String(format: "%.2f", totalExpense))", // 显示真数据
                                icon: "arrow.down.circle.fill",
                                color: .red
                            )
                            
                            StatBox(
                                title: "累计返现",
                                amount: "¥\(String(format: "%.2f", totalCashback))", // 显示真数据
                                icon: "arrow.up.circle.fill",
                                color: .green
                            )
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // --- 列表标题 ---
                        HStack {
                            Text("近期账单")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        // --- 交易列表 ---
                        LazyVStack(spacing: 15) {
                                         ForEach(dbTransactions) { item in
                                             TransactionRow(transaction: item)
                                         }
                                     }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Cashback Counter")
            .navigationBarTitleDisplayMode(.inline)
        
        }.onAppear {
            // 当页面显示时，尝试加载假数据
            SampleData.load(context: context, manager: manager)
        }
    }
}

#Preview {
    BillHomeView()
        .environmentObject(DataManager()) // 👈 必须加！为了喂饱里面的子页面
}
