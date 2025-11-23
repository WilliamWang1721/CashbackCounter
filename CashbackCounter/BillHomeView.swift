//
//  BillHomeView.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import SwiftUI

struct BillHomeView: View {
    // 模拟数据
    let transactions = [
        Transaction(merchant: "Apple Store", category: "applelogo", amount: 8999, cashbackRate: 0.03, date: "今天", color: .gray),
        Transaction(merchant: "星巴克", category: "cup.and.saucer.fill", amount: 38, cashbackRate: 0.05, date: "今天", color: .green),
        Transaction(merchant: "7-Eleven", category: "cart.fill", amount: 125, cashbackRate: 0.01, date: "昨天", color: .orange)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 统计条
                        HStack(spacing: 15) {
                            StatBox(title: "本月支出", amount: "¥9,316", icon: "arrow.down.circle.fill", color: .red)
                            StatBox(title: "累计返现", amount: "¥284.5", icon: "arrow.up.circle.fill", color: .green)
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // 列表头
                        HStack {
                            Text("近期账单")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        // 交易列表
                        LazyVStack(spacing: 15) {
                            ForEach(transactions) { item in
                                TransactionRow(transaction: item)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("账单流水")
        }
    }
}
