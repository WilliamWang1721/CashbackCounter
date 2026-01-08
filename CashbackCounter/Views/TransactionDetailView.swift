//
//  TransactionDetailView.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import SwiftUI
import SwiftData

struct TransactionDetailView: View {
    let transaction: Transaction
    @Environment(\.dismiss) var dismiss
    @State private var showFullImage = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // 1. 顶部大图标和商家
                    HeaderView(transaction: transaction)
                    
                    // 2. 金额显示
                    AmountDisplayView(transaction: transaction)
                    
                    // 3. 详细信息列表
                    DetailListView(transaction: transaction)
                    
                    // 4. 返现高亮区域
                    if transaction.cashbackamount > 0 {
                        CashbackHighlightView(transaction: transaction)
                    }
                    
                    // 5. 实际成本显示（如果有 CBF）
                    if transaction.isCBFApplied && transaction.cbfAmount > 0 {
                        TotalCostView(transaction: transaction)
                    }
                    
                    // 6. 电子收据区域
                    if let data = transaction.receiptData, let uiImage = UIImage(data: data) {
                        ReceiptView(image: uiImage, showFullImage: $showFullImage)
                    }
                }
                .padding(.vertical)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(isPresented: $showFullImage) {
                if let data = transaction.receiptData, let uiImage = UIImage(data: data) {
                    ReceiptFullScreenView(image: uiImage)
                        .presentationDragIndicator(.visible)
                }
            }
        }
    }
}

// MARK: - Subviews

private struct HeaderView: View {
    let transaction: Transaction
    
    var body: some View {
        VStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(transaction.category.color.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: transaction.category.iconName)
                    .font(.system(size: 35))
                    .foregroundColor(transaction.category.color)
            }
            
            HStack(spacing: 6) {
                Text(transaction.merchant)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                // CR 标记（还款/退款）
                if transaction.isCreditTransaction {
                    Text("CR")
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .cornerRadius(3)
                }
            }
        }
        .padding(.top, 40)
    }
}

private struct AmountDisplayView: View {
    let transaction: Transaction
    
    var body: some View {
        let currency = transaction.spendingCurrency
        let amountStr = String(format: "%.2f", transaction.spendingAmount)
        
        Text("- \(currency)\(amountStr)")
            .font(.system(size: 40, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundColor(transaction.isCreditTransaction ? .orange : .primary)
    }
}

private struct DetailListView: View {
    let transaction: Transaction
    
    var cardName: String { transaction.card?.bankName ?? "未知银行" }
    var cardNumber: String { transaction.card?.endNum ?? "----" }
    var spendingCurrency: String { transaction.spendingCurrency }
    var billingCurrency: String { transaction.billingCurrency }
    
    var body: some View {
        VStack(spacing: 0) {
            DetailRow(title: "交易时间", value: transaction.date.formatted(date: .abbreviated, time: .shortened))
            Divider()
            DetailRow(title: "支付卡片", value: cardName)
            Divider()
            DetailRow(title: "卡片尾号", value: cardNumber)
            Divider()
            
            // 如果消费币种和入账币种不同，显示两个
            if spendingCurrency != billingCurrency {
                DetailRow(title: "消费金额", value: "\(spendingCurrency)\(String(format: "%.2f", transaction.spendingAmount))")
                Divider()
            }
            
            DetailRow(title: "入账金额", value: "\(billingCurrency)\(String(format: "%.2f", transaction.billingAmount))")
            Divider()
            DetailRow(title: "消费地区", value: "\(transaction.location.icon) \(transaction.location.rawValue)")
            Divider()
            DetailRow(title: "支付方式", value: transaction.paymentMethod.isEmpty ? "未选择" : transaction.paymentMethod)
            Divider()
            DetailRow(title: "网上购物", value: transaction.isOnlineShopping ? "是" : "否")
            Divider()
            DetailRow(title: "适用 CBF", value: transaction.isCBFApplied ? "是" : "否")
            
            if transaction.isCBFApplied && transaction.cbfAmount > 0 {
                Divider()
                DetailRowHighlight(
                    title: "CBF",
                    value: "-\(billingCurrency)\(String(format: "%.2f", transaction.cbfAmount))",
                    color: .orange
                )
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

private struct CashbackHighlightView: View {
    let transaction: Transaction
    
    var body: some View {
        let currency = transaction.billingCurrency
        let cashback = transaction.cashbackamount
        let rate = String(format: "%.1f", transaction.rate * 100)
        
        HStack {
            VStack(alignment: .leading) {
                Text("本单返现")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("\(currency)\(String(format: "%.2f", cashback)) (\(rate)%)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                    .monospacedDigit()
            }
            Spacer()
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundColor(.green.opacity(0.3))
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

private struct TotalCostView: View {
    let transaction: Transaction
    
    var body: some View {
        let currency = transaction.billingCurrency
        let total = transaction.billingAmount + transaction.cbfAmount
        
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("实际总成本")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 4) {
                        Text("入账")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(currency)\(String(format: "%.2f", transaction.billingAmount))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("+")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("CBF")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(currency)\(String(format: "%.2f", transaction.cbfAmount))")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                Spacer()
                Text("\(currency)\(String(format: "%.2f", total))")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                    .monospacedDigit()
            }
            
            Text("💡 CBF 费用不参与返现计算")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

private struct ReceiptView: View {
    let image: UIImage
    @Binding var showFullImage: Bool
    
    var body: some View {
        VStack(spacing: 15) {
            Divider()
            
            HStack {
                Text("电子收据")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
                .cornerRadius(12)
                .shadow(radius: 5)
                .onTapGesture {
                    showFullImage = true
                }
        }
        .padding(.horizontal)
        .padding(.bottom, 30)
    }
}

// MARK: - Helper Views

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title).foregroundColor(.gray)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .padding()
    }
}

private struct DetailRowHighlight: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                Text(title)
            }
            .foregroundColor(color)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .padding()
        .background(color.opacity(0.1))
    }
}
