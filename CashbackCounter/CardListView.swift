//
//  CardListView.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import SwiftUI

struct CardListView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 卡片 1 (蓝紫渐变)
                    CreditCardView(bankName: "招商银行", type: "运通白金卡", endNum: "8881", colors: [.blue, .purple])
                    
                    // 卡片 2 (黑金风格)
                    CreditCardView(bankName: "浦发银行", type: "超白金", endNum: "1024", colors: [.black, .gray])
                    
                    // 卡片 3 (红色喜庆)
                    CreditCardView(bankName: "中国银行", type: "冬奥主题卡", endNum: "6666", colors: [.red, .orange])
                }
                .padding(.top)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("我的卡包")
            .toolbar {
                Button(action: {}) {
                    Image(systemName: "plus")
                }
            }
        }
    }
}
