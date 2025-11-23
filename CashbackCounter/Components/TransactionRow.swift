//
//  TransactionRow.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle().fill(transaction.color.opacity(0.1)).frame(width: 50, height: 50)
                Image(systemName: transaction.category).font(.title3).foregroundColor(transaction.color)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.merchant).font(.headline)
                Text(transaction.date).font(.caption).foregroundColor(.gray)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("- \(String(format: "%.2f", transaction.amount))").font(.system(.body, design: .rounded)).fontWeight(.semibold)
                HStack(spacing: 4) {
                    Image(systemName: "sparkles").font(.system(size: 10))
                    Text("返 ¥\(String(format: "%.2f", transaction.cashbackAmount))").font(.system(size: 10, weight: .bold))
                }
                .padding(.horizontal, 6).padding(.vertical, 3).background(Color.green.opacity(0.1)).foregroundColor(.green).cornerRadius(4)
            }
        }
        .padding()
        .background(Color.white).cornerRadius(15).shadow(color: .black.opacity(0.02), radius: 5, x: 0, y: 2)
    }
}
