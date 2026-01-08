//
//  CreditCard.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import SwiftUI
import SwiftData

enum CapPeriod: Codable {
    case yearly
    case monthly
}

@Model
class CreditCard: Identifiable {
    
    // MARK: - 基本信息
    
    var bankName: String
    
    /// 卡种类型（如 "Visa 白金卡"）
    var type: String
    
    /// 卡片尾号
    var endNum: String
    
    /// 还款日
    var repaymentDay: Int = 0
    
    /// 是否开启还款提醒
    var isRemindOpen: Bool = true
    
    // MARK: - 卡面颜色
    /// 卡面颜色 Hex 值数组（用于渐变）
    var colorHexes: [String]
    
    @Transient
    var colors: [Color] {
        return colorHexes.map { Color(hex: $0) }
    }
    
    // MARK: - 自定义卡面图片（新增）
    /// 自定义卡面图片数据
    @Attribute(.externalStorage) var cardImageData: Data?
    
    // MARK: - 返现率设置
    
    /// 基础返现率（例如：0.01 表示 1%）
    var defaultRate: Double
    
    /// 特殊类别返现率（加成部分，例如：餐饮额外 2%）
    var specialRates: [Category: Double]
    
    /// 发卡地区
    var issueRegion: Region
    
    /// 境外消费返现率
    var foreignCurrencyRate: Double?
    
    /// 模板来源标识（用于模板更新同步）
    var templateKey: String?
    
    // MARK: - 费用相关（新增）
    
    /// 外币交易兑换费（Foreign Transaction Fee）百分比
    var ftf: Double = 0.0
    
    /// 跨境港币交易费（Cross-Border HKD Fee）百分比
    var cbf: Double = 0.0
    
    /// FTF 免收币种（存 currencyCode，例如 "USD"）
    /// 规则：**选中的币种不收 FTF，其余币种都收 FTF**
    var ftfExceptCurrencyCodes: [String] = []
    
    // MARK: - 返现上限设置
    
    /// 本币基础返现上限
    var localBaseCap: Double
    
    /// 外币基础返现上限
    var foreignBaseCap: Double
    
    /// 返现上限结算周期
    var capPeriod: CapPeriod
    
    /// 基础返现月度上限（新增，nil 或 0 表示无上限）
    var monthlyBaseCap: Double?
    
    /// 基础返现年度上限（新增，nil 或 0 表示无上限）
    var yearlyBaseCap: Double?
    
    /// 类别加成上限（Key: 消费类别, Value: 该类别的上限）
    var categoryCaps: [Category: Double]
    
    /// 多返现条件支持（用于存储多个不同场景下的返现规则）
    var baseCashbackConditionsData: Data?
    
    // MARK: - 关联关系
    
    /// 关联的交易记录（删除卡片时，交易的 card 字段会被设为 nil）
    @Relationship(deleteRule: .nullify, inverse: \Transaction.card)
    var transactions: [Transaction]?
    
    // MARK: - 初始化方法
    
    init(bankName: String,
         type: String,
         endNum: String,
         colorHexes: [String],
         defaultRate: Double,
         specialRates: [Category: Double],
         issueRegion: Region,
         foreignCurrencyRate: Double? = nil,
         templateKey: String? = nil,
         localBaseCap: Double = 0,
         foreignBaseCap: Double = 0,
         categoryCaps: [Category: Double] = [:],
         capPeriod: CapPeriod = .yearly,
         monthlyBaseCap: Double? = nil,
         yearlyBaseCap: Double? = nil,
         repaymentDay: Int = 0,
         isRemindOpen: Bool = true,
         ftf: Double = 0.0,
         cbf: Double = 0.0,
         ftfExceptCurrencyCodes: [String] = [],
         cardImageData: Data? = nil
    ) {
        self.bankName = bankName
        self.type = type
        self.endNum = endNum
        self.colorHexes = colorHexes
        self.defaultRate = defaultRate
        self.specialRates = specialRates
        self.issueRegion = issueRegion
        self.foreignCurrencyRate = foreignCurrencyRate
        self.templateKey = templateKey
        self.localBaseCap = localBaseCap
        self.foreignBaseCap = foreignBaseCap
        self.capPeriod = capPeriod
        self.monthlyBaseCap = monthlyBaseCap
        self.yearlyBaseCap = yearlyBaseCap
        self.categoryCaps = categoryCaps
        self.repaymentDay = repaymentDay
        self.isRemindOpen = isRemindOpen
        self.ftf = ftf
        self.cbf = cbf
        self.ftfExceptCurrencyCodes = ftfExceptCurrencyCodes
        self.cardImageData = cardImageData
    }
    
    // MARK: - 返现率计算
    
    func getRate(for category: Category, location: Region) -> Double {
        // 1. 获取类别带来的"额外"加成 (Category Bonus)
        let categoryBonus = specialRates[category] ?? 0.0
        
        // 2. 确定基础费率 (Base Rate)
        var baseRate = defaultRate
        
        // 如果消费地 != 发卡地，且设置了境外费率，则使用境外费率作为基础
        if location != issueRegion, let foreignRate = foreignCurrencyRate, foreignRate > 0 {
            baseRate = foreignRate
        }
        
        // 3. 核心修改：将基础费率与类别加成相加
        return baseRate + categoryBonus
    }
    
    // MARK: - 返现上限计算
    
    func calculateCappedCashback(amount: Double, category: Category, location: Region, date: Date, transactionToExclude: Transaction? = nil) -> Double {
        let isForeign = (location != issueRegion)
        
        // --- 第一步：准备费率和当笔理论值 ---
        var baseRate = defaultRate
        if isForeign, let fr = foreignCurrencyRate, fr > 0 {
            baseRate = fr
        }
        let potentialBaseReward = amount * baseRate
        
        let bonusRate = specialRates[category] ?? 0.0
        let potentialBonusReward = amount * bonusRate
        
        // --- 第二步：准备上限阈值 ---
        let baseCapLimit = isForeign ? foreignBaseCap : localBaseCap
        let categoryCapLimit = categoryCaps[category] ?? 0.0
        
        // --- 第三步：统计历史用量 ---
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: date)
        let currentMonth = calendar.component(.month, from: date)
        
        // 筛选同一张卡在同一结算周期内的交易（排除正在编辑的这一笔）
        let periodTransactions = (transactions ?? []).filter { t in
            let year = calendar.component(.year, from: t.date)
            guard year == currentYear else { return false }
            
            let isNotSelf = (t != transactionToExclude)
            guard isNotSelf else { return false }
            
            switch capPeriod {
            case .yearly:
                return true
            case .monthly:
                let month = calendar.component(.month, from: t.date)
                return month == currentMonth
            }
        }
        
        // A. 计算已用基础返现 (估算值)
        var usedBase: Double = 0
        if baseCapLimit > 0 {
            usedBase = periodTransactions
                .filter { ($0.location != self.issueRegion) == isForeign }
                .reduce(0) { sum, t in
                    let tBaseRate = ((t.location != self.issueRegion) && (foreignCurrencyRate ?? 0) > 0) ? (foreignCurrencyRate ?? 0) : defaultRate
                    return sum + (t.billingAmount * tBaseRate)
                }
        }
        
        // B. 计算已用加成返现 (估算值)
        var usedBonus: Double = 0
        if categoryCapLimit > 0 {
            usedBonus = periodTransactions
                .filter { $0.category == category }
                .reduce(0) { sum, t in
                    let tBonusRate = specialRates[t.category] ?? 0.0
                    return sum + (t.billingAmount * tBonusRate)
                }
        }
        
        // --- 第四步：结算 (Reward Cap 逻辑) ---
        var finalBase = potentialBaseReward
        if baseCapLimit > 0 {
            let remaining = max(0, baseCapLimit - usedBase)
            finalBase = min(potentialBaseReward, remaining)
        }
        
        var finalBonus = potentialBonusReward
        if categoryCapLimit > 0 {
            let remaining = max(0, categoryCapLimit - usedBonus)
            finalBonus = min(potentialBonusReward, remaining)
        }
        
        return finalBase + finalBonus
    }
    
    func calculateCappedCashback(amount: Double, category: Category, location: Region, date: Date) -> Double {
        return calculateCappedCashback(amount: amount, category: category, location: location, date: date, transactionToExclude: nil)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension Color {
    func toHex() -> String? {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        var a = Float(1.0)
        
        if components.count >= 4 {
            a = Float(components[3])
        }
        
        if a != Float(1.0) {
            return String(format: "%02lX%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255), lroundf(a * 255))
        } else {
            return String(format: "%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        }
    }
}
