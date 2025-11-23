//
//  CreditCard.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import SwiftUI

struct CreditCard: Identifiable {
    let id = UUID()
    let bankName: String
    let type: String
    let endNum: String
    let colors: [Color]
    // --- 新增的核心逻辑 ---
        
    // 1. 保底返现率 (比如 0.01 代表 1%)
    let defaultRate: Double
        
    // 2. 特殊类别返现表 [类别图标名 : 返现率]
    // 比如 ["cart.fill": 0.05] 代表超市返 5%
    let specialRates: [String: Double]
        
    // 3. 一个“聪明”的方法：给我一个类别，我告诉你该返多少
    func getRate(for category: String) -> Double {
        // 语法糖复习：?? 是空合运算符
        // 意思：尝试在 specialRates 字典里找 category
        // 如果找到了(有值)，就用那个值；
        // 如果没找到(nil)，就用 ?? 后面的 defaultRate。
        return specialRates[category] ?? defaultRate
    }
}
