//
//  DataManager.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import SwiftUI
import Combine
import SwiftData

// 1. 必须是用 class (类)，因为数据要是共享的引用
// 2. 必须遵守 ObservableObject 协议，这样 View 才能监听它的变化
class DataManager: ObservableObject {
    
    // @Published 的意思是：
    // "只要这个数组一变，所有用到了它的界面，统统自动刷新！"
    @Published var cards: [CreditCard] = [
        // 卡片 1
        CreditCard(
            bankName: "HSBC HK",
            type: "Pulse",
            endNum: "4896",
            colors: [.red, .black],
            issueRegion: .hk,
            foreignCurrencyRate: 0.044,
            defaultRate: 0.004, // 基础 0.4%
            specialRates: [.dining: 0.094]
        ),
        
        // 卡片 2
        CreditCard(
            bankName: "农业银行",
            type: "Visa精粹白",
            endNum: "2723",
            colors: [.white, .blue],
            issueRegion: .cn,
            foreignCurrencyRate: 0.03,
            defaultRate: 0, // 基础 0%
            specialRates: [:]
        ),
        
        // 卡片 3
        CreditCard(
            bankName: "HSBC US",
            type: "Elite Master",
            endNum: "0444",
            colors: [.black, .white],
            issueRegion: .us,
            foreignCurrencyRate: 0.013,
            defaultRate: 0.013, 
            specialRates: [.travel:0.069,.dining:0.027]
        )
        
    ]
}

extension String {
    func toDate() -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd" // 必须按照这个格式写
        return formatter.date(from: self) ?? Date() // 如果格式错了，默认返回今天
    }
}

// Fake data

@MainActor // 👈 因为要操作数据库 UI 线程，加这个比较安全
class SampleData {
    
    // 把数据插入到数据库 context 中
    static func load(context: ModelContext, manager: DataManager) {
        // 1. 先检查数据库里有没有数据
        let descriptor = FetchDescriptor<Transaction>()
        do {
            let count = try context.fetchCount(descriptor)
            if count > 0 {
                print("数据库里已经有数据了，跳过加载。")
                return // 如果有数据，就什么都不做，防止重复添加
            }
        } catch {
            print("查询失败")
        }
        
        // 2. 准备卡片引用 (为了拿到 ID)
        let cards = manager.cards
        if cards.isEmpty { return }
        
        // 3. 你的那坨数据 (稍微改写成数组遍历)
        let samples = [
            Transaction(merchant: "Apple Store", category: .digital, location: .cn, amount: 8999, date: Date(), cardID: cards[0].id),
            Transaction(merchant: "星巴克", category: .dining, location: .cn, amount: 38, date: Date(), cardID: cards[0].id),
            Transaction(merchant: "滴滴出行", category: .travel, location: .cn, amount: 56, date: "2025-11-20".toDate(), cardID: cards[1].id),
            Transaction(merchant: "CDF免税店", category: .other, location: .cn, amount: 2000, date: "2025-11-20".toDate(), cardID: cards[0].id),
            Transaction(merchant: "Uber", category: .travel, location: .us, amount: 30, date: "2025-11-20".toDate(), cardID: cards[1].id)
        ]
        
        // 4. 循环插入数据库
        for item in samples {
            context.insert(item)
        }
        
        print("🎉 假数据已成功写入数据库！")
    }
}
