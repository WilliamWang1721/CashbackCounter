//
//  TransactionRow.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction
    var exchangeRates: [String: Double] = [:]
    @AppStorage("mainCurrencyCode") private var mainCurrencyCode: String = "CNY"

    private var incomeDisplayText: String? {
        guard
            let incomes = transaction.incomes,
            !incomes.isEmpty,
            let expense = convertToMainCurrency(
                amount: transaction.billingAmount,
                currencyCode: transaction.card?.issueRegion.currencyCode ?? mainCurrencyCode
            )
        else { return nil }

        let totalIncome = incomes
            .compactMap { convertToMainCurrency(amount: $0.amount, currencyCode: $0.location.currencyCode) }
            .reduce(0, +)

        guard totalIncome > expense else { return nil }
        return (totalIncome-expense).formatted(.currency(code: mainCurrencyCode))
    }

    private func convertToMainCurrency(amount: Double, currencyCode: String) -> Double? {
        if currencyCode == mainCurrencyCode { return amount }
        guard let rate = exchangeRates[currencyCode], rate != 0 else { return nil }
        return amount / rate
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 12) {
            // 1. 左侧类别图标
            iconView
            
            // 2. 中间信息 (商户名 + 卡片名)
            mainInfoView
            
            Spacer(minLength: 8)
            
            // 3. 右侧金额与详情
            amountInfoView
        }
        .padding(12)
        .background(rowBackground)
        .cornerRadius(12)
        // 降低退款/还款记录的视觉权重
        .opacity(transaction.isCreditTransaction ? 0.8 : 1.0)
    }
}

// MARK: - Subviews

private extension TransactionRow {
    
    var iconView: some View {
        ZStack {
            Circle()
                .fill(transaction.category.color.opacity(0.2))
                .frame(width: 44, height: 44)
            
            Image(systemName: transaction.category.iconName)
                .font(.system(size: 20))
                .foregroundColor(transaction.category.color)
        }
    }
    
    var mainInfoView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(transaction.merchant)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                // CR 标记（还款/退款）
                if transaction.isCreditTransaction {
                    if transaction.paymentMethod == "返现" {
                        Text("返现CR")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .cornerRadius(3)
                    } else {
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
            
            if let cardName = cardDisplayName {
                Text(cardName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
            }
        }
    }
    
    var amountInfoView: some View {
        VStack(alignment: .trailing, spacing: 4) {
            // 消费金额
            Text(amountString)
                .fontWeight(.bold)
                .foregroundColor(amountColor)
                .monospacedDigit()
            
            // 日期 + 返现信息
            VStack(alignment: .trailing, spacing: 2) {
                Text(transaction.dateString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // 显示返现
                if shouldShowCashback {
                    Text(cashbackString)
                        .font(.caption2)
                        .foregroundColor(cashbackTextColor)
                        .monospacedDigit()
                }
                
                // 显示收入信息
                if let incomeText = incomeDisplayText {
                    Text("收入 \(incomeText)")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
    }
}

// MARK: - Helpers

private extension TransactionRow {
    
    var isRebate: Bool {
        transaction.paymentMethod == "返现"
    }
    
    var rowBackground: Color {
        if isRebate {
            return Color.green.opacity(0.05)
        } else if transaction.isCreditTransaction {
            return Color.orange.opacity(0.05)
        } else {
            return Color(uiColor: .secondarySystemGroupedBackground)
        }
    }
    
    var amountColor: Color {
        if isRebate { return .green }
        if transaction.isCreditTransaction { return .orange }
        return .primary
    }
    
    var cashbackTextColor: Color {
        if isRebate { return .green }
        if transaction.isCreditTransaction { return .orange }
        return .green
    }
    
    var cardDisplayName: String? {
        guard let card = transaction.card else { return nil }
        return card.bankName
    }
    
    var amountString: String {
        "\(transaction.billingCurrency)\(String(format: "%.2f", transaction.spendingAmount))"
    }
    
    var shouldShowCashback: Bool {
        if isRebate { return false }
        return transaction.isCreditTransaction || transaction.cashbackamount > 0
    }
    
    var cashbackString: String {
        let amount = transaction.isCreditTransaction ? 0 : transaction.cashbackamount
        return "返现 \(transaction.billingCurrency)\(String(format: "%.2f", amount))"
    }
}
