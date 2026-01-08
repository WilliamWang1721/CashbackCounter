import SwiftUI
import SwiftData

@Model
class Transaction: Identifiable {
    var merchant: String
    var category: Category
    var location: Region
    
    // MARK: - 金额相关字段
    /// 原币消费金额（兼容旧版本的 amount 字段）
    var spendingAmount: Double
    /// 入账金额（本币）
    var billingAmount: Double
    /// 消费货币代码（如 USD, JPY），默认 HKD
    var spendingCurrency: String = "HKD"
    /// 入账货币代码，默认 HKD
    var billingCurrency: String = "HKD"
    /// CBF（跨境港币交易费）金额
    var cbfAmount: Double = 0.0
    
    var date: Date
    var cashbackamount: Double
    var rate: Double
    
    // MARK: - 支付方式相关字段
    /// 支付方式（如：网购 / Apple Pay / 银联二维码 / 线下购物 / 其他）
    /// 为空表示未填写（兼容旧数据）
    var paymentMethod: String = ""
    
    /// 是否为网上购物（与 paymentMethod 可独立；用于未来规则扩展）
    var isOnlineShopping: Bool = false
    
    /// 是否适用 CBF（重要：必须手动选择；不做自动推断）
    var isCBFApplied: Bool = false
    
    /// 是否为信用交易（还款/退款/调整）—— 这类交易不计算返现
    var isCreditTransaction: Bool = false
    
    var card: CreditCard?
    
    @Attribute(.externalStorage) var receiptData: Data?
    
    // MARK: - Income 关联（保留原有功能）
    @Relationship(deleteRule: .cascade, inverse: \Income.transaction)
    var incomes: [Income]?
    
    // MARK: - 兼容性计算属性
    /// 兼容旧版本的 amount 字段访问
    var amount: Double {
        get { spendingAmount }
        set { spendingAmount = newValue }
    }
    
    // MARK: - 初始化方法
    /// 新版初始化方法（完整参数）
    init(merchant: String,
         category: Category,
         location: Region,
         spendingAmount: Double,
         date: Date,
         card: CreditCard?,
         paymentMethod: String = "",
         isOnlineShopping: Bool = false,
         isCBFApplied: Bool = false,
         isCreditTransaction: Bool = false,
         receiptData: Data? = nil,
         billingAmount: Double? = nil,
         cashbackAmount: Double? = nil,
         cbfAmount: Double = 0.0,
         spendingCurrency: String = "HKD",
         billingCurrency: String = "HKD"
    ) {
        self.merchant = merchant
        self.category = category
        self.location = location
        self.spendingAmount = spendingAmount
        self.date = date
        self.card = card
        self.paymentMethod = paymentMethod
        self.isOnlineShopping = isOnlineShopping
        self.isCBFApplied = isCBFApplied
        self.isCreditTransaction = isCreditTransaction
        self.receiptData = receiptData
        self.billingAmount = billingAmount ?? spendingAmount
        self.cbfAmount = cbfAmount
        self.spendingCurrency = spendingCurrency
        self.billingCurrency = billingCurrency
        
        let finalBilling = billingAmount ?? spendingAmount
        
        // 1. 记录名义费率 (用于界面显示，比如 "5%")
        // 这里依然调用 getRate，得到的是 "基础+加成" 的理论总费率
        let nominalRate = card?.getRate(for: category, location: location) ?? 0
        self.rate = nominalRate
        
        // 2. 确定实际返现额 (优先使用传入的计算结果)
        // 🔥 如果是信用交易（还款/退款），返现金额强制为 0
        if isCreditTransaction {
            self.cashbackamount = 0.0
        } else if let providedCashback = cashbackAmount {
            // 如果外部传了（也就是经过了上限计算），就用外部的
            self.cashbackamount = providedCashback
        } else {
            // 兜底：如果没传，就按简单的 费率*金额 算 (兼容旧代码)
            self.cashbackamount = finalBilling * nominalRate
        }
    }
    
    /// 兼容旧版本的初始化方法（使用 amount 参数名）
    convenience init(merchant: String,
                     category: Category,
                     location: Region,
                     amount: Double,
                     date: Date,
                     card: CreditCard?,
                     receiptData: Data? = nil,
                     billingAmount: Double? = nil,
                     cashbackAmount: Double? = nil
    ) {
        self.init(
            merchant: merchant,
            category: category,
            location: location,
            spendingAmount: amount,
            date: date,
            card: card,
            paymentMethod: "",
            isOnlineShopping: false,
            isCBFApplied: false,
            isCreditTransaction: false,
            receiptData: receiptData,
            billingAmount: billingAmount,
            cashbackAmount: cashbackAmount,
            cbfAmount: 0.0,
            spendingCurrency: "HKD",
            billingCurrency: "HKD"
        )
    }
    
    var color: Color { category.color }
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
