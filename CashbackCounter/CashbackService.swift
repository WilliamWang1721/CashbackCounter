//
//  CashbackService.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import Foundation

// 这是一个“纯逻辑”的服务，不依赖 SwiftUI，甚至可以方便地写单元测试
struct CashbackService {
    
    // 1. 计算返现金额
    // 输入：一笔交易，和所有的卡片库
    // 输出：返现金额
    static func calculateCashback(for transaction: Transaction, in cards: [CreditCard]) -> Double {
        // 1. 找到对应的卡
        guard let card = cards.first(where: { $0.id == transaction.cardID }) else {
            return 0.0
        }
        
        // 2. 拿到费率 (调用 Card 自己的逻辑)
        let rate = card.getRate(for: transaction.category, location: transaction.location)
        
        // 3. 计算金额
        return transaction.amount * rate
    }
    
    // 2. 获取卡片名称
    static func getCardName(for transaction: Transaction, in cards: [CreditCard]) -> String {
        if let card = cards.first(where: { $0.id == transaction.cardID }) {
            return "\(card.bankName) \(card.type)"
        }
        return "未知卡片"
    }
    
    // 3. 获取费率 (用于显示百分比)
    static func getRate(for transaction: Transaction, in cards: [CreditCard]) -> Double {
        guard let card = cards.first(where: { $0.id == transaction.cardID }) else { return 0.0 }
        return card.getRate(for: transaction.category, location: transaction.location)
    }
    // 4.返回货币
    static func getCurrency(for transaction: Transaction, in cards: [CreditCard]) -> String {
            // 1. 找到这笔交易刷的卡
            if let card = cards.first(where: { $0.id == transaction.cardID }) {
                // 2. 返回这张卡发行地的货币符号
                return card.issueRegion.currencySymbol
            }
            // 3. 找不到卡？默认用人民币
            return "¥"
        }
    static func getCurrency(for card: CreditCard) -> String {
            return card.issueRegion.currencySymbol
        }
}
