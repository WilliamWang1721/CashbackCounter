//
//  CardListView.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import SwiftUI

struct CardListView: View {
    // 1. 拿仓库钥匙
    @EnvironmentObject var manager: DataManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 2. 变成动态循环
                    ForEach(manager.cards) { card in
                        CreditCardView(
                            bankName: card.bankName,
                            type: card.type,
                            endNum: card.endNum,
                            colors: card.colors
                        )
                    }
                }
                .padding(.top)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("我的卡包")
            // ...
        }
    }
}
#Preview {
    // 👇 补上这一句，给预览环境也注入一个 DataManager
    CardListView()
        .environmentObject(DataManager())
}
