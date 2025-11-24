import SwiftUI
import SwiftData

struct BillHomeView: View {
    // 1. 拿到数据库上下文 (用来删除)
    @Environment(\.modelContext) var context
    
    @Query(sort: \Transaction.date, order: .reverse) var dbTransactions: [Transaction]
    
    // 2. 控制详情页弹窗
    @State private var selectedTransaction: Transaction? = nil
    
    // 3. 控制编辑页弹窗
    @State private var transactionToEdit: Transaction?
    
    // 4. 汇率表 [币种: 对CNY汇率] (例如: ["USD": 0.14])
    @State private var exchangeRates: [String: Double] = [:]
    
    // --- 计算总支出 (CNY) ---
    var totalExpense: Double {
        if exchangeRates.isEmpty { return 0.0 } // 或者简单的累加
        
        return dbTransactions.reduce(0) { total, transaction in
            // A. 获取交易币种 (例如 USD)
            let code = transaction.card?.issueRegion.currencyCode ?? "CNY"
            // B. 获取该币种对 CNY 的汇率 (例如 0.14)
            let rate = exchangeRates[code] ?? 1.0
            // C. 换算: 美元金额 / 汇率 = 人民币金额
            let amountInCNY = transaction.billingAmount / rate
            
            return total + amountInCNY
        }
    }
    
    // --- 计算总返现 (CNY) ---
    var totalCashback: Double {
        if exchangeRates.isEmpty { return 0.0 }
        
        return dbTransactions.reduce(0) { total, transaction in
            // A. 先算出原币种返现 (例如返 $10)
            let cashbackForeign = transaction.cashbackamount
            
            // B. 获取汇率
            let code = transaction.card?.issueRegion.currencyCode ?? "CNY"
            let rate = exchangeRates[code] ?? 1.0
            
            // C. 换算成人民币
            let cashbackInCNY = cashbackForeign / rate
            
            return total + cashbackInCNY
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // --- 统计条 ---
                        HStack(spacing: 15) {
                            StatBox(
                                title: "本月支出 (CNY)",
                                // 如果汇率还没好，显示计算中
                                amount: exchangeRates.isEmpty ? "..." : "¥\(String(format: "%.2f", totalExpense))",
                                icon: "arrow.down.circle.fill",
                                color: .red
                            )
                            
                            StatBox(
                                title: "累计返现 (CNY)",
                                amount: exchangeRates.isEmpty ? "..." : "¥\(String(format: "%.2f", totalCashback))",
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
                                    // 1. 单击 -> 查看详情
                                    .onTapGesture {
                                        selectedTransaction = item
                                    }
                                    // 2. 长按 -> 弹出菜单
                                    .contextMenu {
                                        Button {
                                            transactionToEdit = item
                                        } label: {
                                            Label("编辑", systemImage: "pencil")
                                        }
                                        
                                        Button(role: .destructive) {
                                            context.delete(item)
                                        } label: {
                                            Label("删除", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Cashback Counter")
            .navigationBarTitleDisplayMode(.inline)
            
            // 弹窗 1: 详情页
            .sheet(item: $selectedTransaction) { item in
                TransactionDetailView(transaction: item)
                    .presentationDetents([.large])
            }
            
            // 弹窗 2: 编辑页
            .sheet(item: $transactionToEdit) { item in
                AddTransactionView(transaction: item)
            }
        }
        // 👇👇👇 核心：页面显示时拉取汇率和假数据
        .task {
            
            // 2. 拉取汇率 (后台进行)
            do {
                let rates = await CurrencyService.getRates(base: "CNY")

                await MainActor.run {
                    self.exchangeRates = rates
                }
            } catch {
                print("汇率获取失败")
            }
        }
    }
}

