//
//  DataManager.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import SwiftUI
import Combine

// 1. 必须是用 class (类)，因为数据要是共享的引用
// 2. 必须遵守 ObservableObject 协议，这样 View 才能监听它的变化
class DataManager: ObservableObject {
    
    // @Published 的意思是：
    // "只要这个数组一变，所有用到了它的界面，统统自动刷新！"
    @Published var cards: [CreditCard] = [
        // 卡片 1: "饭卡" (餐饮 5%，其他 1%)
        CreditCard(
            bankName: "招商银行",
            type: "运通餐饮卡",
            endNum: "8888",
            colors: [.red, .orange],
            defaultRate: 0.01, // 基础 1%
            specialRates: [
                "cup.and.saucer.fill": 0.05, // 咖啡/餐饮 5%
                "cart.fill": 0.03            // 超市 3%
            ]
        ),
        
        // 卡片 2: "车卡" (出行 10%，其他 0.5%)
        CreditCard(
            bankName: "浦发银行",
            type: "车主白金",
            endNum: "1024",
            colors: [.blue, .black],
            defaultRate: 0.005, // 基础 0.5%
            specialRates: [
                "car.fill": 0.10,      // 打车/加油 10%
                "airplane": 0.05       // 飞机 5%
            ]
        )
        
    ]
    @Published var transactions: [Transaction] = [
            Transaction(merchant: "Apple Store", category: "applelogo", amount: 8999, cashbackRate: 0.03, date: "今天", color: .gray),
            Transaction(merchant: "星巴克", category: "cup.and.saucer.fill", amount: 38, cashbackRate: 0.05, date: "今天", color: .green)
        ]
    
    // 你以后可以在这里加功能，比如：
    // func addTransaction(...) { ... }
    // func deleteCard(...) { ... }
}
