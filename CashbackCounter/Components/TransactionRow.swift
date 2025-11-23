//
//  TransactionRow.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction
    
    // 1. 安装传感器
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 15) {
            // 图标背景
            ZStack {
                Circle()
                    .fill(transaction.color.opacity(0.1))
                    .frame(width: 50, height: 50)
                Image(systemName: transaction.category)
                    .font(.title3)
                    .foregroundColor(transaction.color)
            }
            
            // 商家和日期
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.merchant)
                    .font(.headline)
                    // 标题色自动适配
                Text(transaction.date)
                    .font(.caption)
                    .foregroundColor(.secondary) // 次级色自动适配
            }
            
            Spacer()
            
            // 金额和返现
            VStack(alignment: .trailing, spacing: 4) {
                Text("- \(String(format: "%.2f", transaction.amount))")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.semibold)
                
                // 返现提示 (这个不用改，绿色底色在深色模式下也很好看)
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                    Text("返 ¥\(String(format: "%.2f", transaction.cashbackAmount))")
                        .font(.system(size: 10, weight: .bold))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.1))
                .foregroundColor(.green)
                .cornerRadius(4)
            }
        }
        .padding()
        // 2. 背景色升级
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(15)
        // 3. 阴影处理
        .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.02), radius: 5, x: 0, y: 2)
        // 4. 深色模式专属描边
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.gray.opacity(0.2), lineWidth: colorScheme == .dark ? 0.5 : 0)
        )
    }
}
