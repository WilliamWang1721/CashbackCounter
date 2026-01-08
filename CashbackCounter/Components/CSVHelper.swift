//
//  CSVHelper.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/25/25.
//
import Foundation
import SwiftUI
import SwiftData
import ZIPFoundation

// MARK: - CSV 版本定义
/// CSV 格式版本，用于向后兼容
enum CSVVersion: String {
    case v1 = "1.0"  // 旧版本：9 列基础字段
    case v2 = "2.0"  // 新版本：包含扩展字段（支付方式、货币等）
    
    /// 当前导出使用的版本
    static let current: CSVVersion = .v2
}

// MARK: - CSVHelper 结构体
struct CSVHelper {
    
    // MARK: - Receipt filename helpers (shared by import/export)
    private static let receiptDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
    
    private static func sanitizedMerchantComponent(_ merchant: String) -> String {
        let sanitized = merchant
            .replacingOccurrences(of: "[^A-Za-z0-9_\\u4e00-\\u9fa5-]", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        
        // 限制最长 40 个字符，避免过长文件名导入时无法匹配
        let truncated = String(sanitized.prefix(40))
        return truncated.isEmpty ? "receipt" : truncated
    }
    
    fileprivate static func receiptFilename(for merchant: String, date: Date, index: Int) -> String {
        let dateString = receiptDateFormatter.string(from: date)
        let merchantComponent = sanitizedMerchantComponent(merchant)
        return "receipt_\(dateString)_\(merchantComponent)_\(index).jpg"
    }
    
    // MARK: - 新版 CSV 表头（V2）
    /// V2 版本的 CSV 表头，包含所有新字段
    static let v2Header = "交易时间,商户名称,消费类别,消费金额(原币),入账金额(本币),返现金额(本币),支付卡片,卡片尾号,消费地区,支付方式,消费货币,入账货币,CBF金额,是否网购,是否CBF,是否信用交易,CSV版本\n"
    
    /// V1 版本的 CSV 表头（旧版）
    static let v1Header = "交易时间,商户名称,消费类别,消费金额(原币),入账金额(本币),返现金额(本币),支付卡片,卡片尾号,消费地区\n"
    
    // MARK: - 导入 ZIP 备份
    static func importBackupZip(url: URL, context: ModelContext, allCards: [CreditCard]) throws {
        let fileManager = FileManager.default
        // 创建临时目录用于解压
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) } // 结束后清理
        
        // 1. 解压文件
        try fileManager.unzipItem(at: url, to: tempDir)
        
        // 2. 寻找 CSV 文件
        let csvURL = tempDir.appendingPathComponent("Transactions.csv")
        
        guard fileManager.fileExists(atPath: csvURL.path) else {
            throw NSError(domain: "CSVHelper", code: 404, userInfo: [NSLocalizedDescriptionKey: "ZIP 文件中未找到 Transactions.csv"])
        }
        
        // 3. 读取 CSV 内容
        let content = try String(contentsOf: csvURL, encoding: .utf8)
        
        // 4. 定位收据文件夹 (如果存在)
        let receiptsDir = tempDir.appendingPathComponent("Receipts")
        let receiptsURL = fileManager.fileExists(atPath: receiptsDir.path) ? receiptsDir : nil
        
        // 5. 调用核心解析逻辑，并传入收据路径
        let createdTransactions = try parseTransactionCSV(content: content, context: context, allCards: allCards, receiptsDirectory: receiptsURL)
        
        // 6. 如果存在 Income.csv，再解析收入数据
        let incomeURL = tempDir.appendingPathComponent("Income.csv")
        if fileManager.fileExists(atPath: incomeURL.path) {
            let incomeContent = try String(contentsOf: incomeURL, encoding: .utf8)
            parseIncomeCSV(content: incomeContent, context: context, transactions: createdTransactions)
        }
    }

    // MARK: - 导入 CSV 核心逻辑（兼容 V1 和 V2）
    static func parseTransactionCSV(content: String, context: ModelContext, allCards: [CreditCard], receiptsDirectory: URL? = nil) throws -> [Transaction] {
        let rows = content.components(separatedBy: .newlines)
        var createdTransactions: [Transaction] = []
        
        let categoryMap: [String: Category] = Dictionary(uniqueKeysWithValues: Category.allCases.map { ($0.displayName, $0) })
        let regionMap: [String: Region] = Dictionary(uniqueKeysWithValues: Region.allCases.map { ($0.rawValue, $0) })
        
        // 检测 CSV 版本（根据表头列数判断）
        var detectedVersion: CSVVersion = .v1
        if let headerRow = rows.first {
            let headerColumns = splitCSVLine(headerRow)
            if headerColumns.count >= 17 || headerRow.contains("CSV版本") {
                detectedVersion = .v2
            }
        }
        
        for (index, row) in rows.enumerated() {
            // index 0 是表头，index 1 是第一条数据
            if index == 0 || row.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            
            let columns = splitCSVLine(row)
            
            // V1 至少需要 9 列，V2 需要更多列
            if columns.count < 9 { continue }
            
            // 1. 解析基础字段（V1 和 V2 共有）
            let dateStr = columns[0]
            let merchant = cleanCSVField(columns[1])
            let categoryName = columns[2]
            let amount = Double(columns[3]) ?? 0.0
            let billing = Double(columns[4]) ?? 0.0
            let cashback = Double(columns[5]) ?? 0.0
            let cardNameRaw = cleanCSVField(columns[6])
            let cardEndNum = columns[7]
            let regionName = columns[8]
            
            let date = dateStr.toDate()
            let category = categoryMap[categoryName] ?? .other
            let cleanRegionName = regionName.trimmingCharacters(in: .whitespacesAndNewlines)
            let region = regionMap[cleanRegionName] ?? .cn
            
            // 2. 解析扩展字段（仅 V2）
            var paymentMethod = ""
            var spendingCurrency = "HKD"
            var billingCurrency = "HKD"
            var cbfAmount: Double = 0.0
            var isOnlineShopping = false
            var isCBFApplied = false
            var isCreditTransaction = false
            
            if detectedVersion == .v2 && columns.count >= 16 {
                paymentMethod = cleanCSVField(columns[9])
                spendingCurrency = cleanCSVField(columns[10])
                billingCurrency = cleanCSVField(columns[11])
                cbfAmount = Double(columns[12]) ?? 0.0
                isOnlineShopping = (columns[13].trimmingCharacters(in: .whitespacesAndNewlines) == "1")
                isCBFApplied = (columns[14].trimmingCharacters(in: .whitespacesAndNewlines) == "1")
                isCreditTransaction = (columns[15].trimmingCharacters(in: .whitespacesAndNewlines) == "1")
            }
            
            // 3. 尝试匹配收据图片
            var receiptData: Data? = nil
            if let receiptsDir = receiptsDirectory {
                let filename = receiptFilename(for: merchant, date: date, index: index)
                let fileURL = receiptsDir.appendingPathComponent(filename)
                
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    receiptData = try? Data(contentsOf: fileURL)
                }
            }
            
            // 4. 匹配卡片
            var matchedCard: CreditCard? = nil
            if cardEndNum != "无卡" && cardNameRaw != "已删除卡片" {
                matchedCard = allCards.first { card in
                    let dbCardName = "\(card.bankName) \(card.type)"
                    return card.endNum == cardEndNum && dbCardName == cardNameRaw
                }
                if matchedCard == nil {
                    matchedCard = allCards.first { $0.endNum == cardEndNum }
                }
            }
            
            // 5. 创建交易（使用新版初始化方法）
            let newTransaction = Transaction(
                merchant: merchant,
                category: category,
                location: region,
                spendingAmount: amount,
                date: date,
                card: matchedCard,
                paymentMethod: paymentMethod,
                isOnlineShopping: isOnlineShopping,
                isCBFApplied: isCBFApplied,
                isCreditTransaction: isCreditTransaction,
                receiptData: receiptData,
                billingAmount: billing,
                cashbackAmount: cashback,
                cbfAmount: cbfAmount,
                spendingCurrency: spendingCurrency,
                billingCurrency: billingCurrency
            )
            
            context.insert(newTransaction)
            createdTransactions.append(newTransaction)
        }
        return createdTransactions
    }
    
    /// 解析收入 CSV 并根据索引或字段关联到交易
    private static func parseIncomeCSV(content: String, context: ModelContext, transactions: [Transaction]) {
        let rows = content.components(separatedBy: .newlines)
        let regionMap: [String: Region] = Dictionary(uniqueKeysWithValues: Region.allCases.map { ($0.rawValue, $0) })
        
        for (index, row) in rows.enumerated() {
            if index == 0 || row.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            let columns = splitCSVLine(row)
            if columns.count < 11 { continue }
            
            let dateStr = columns[0]
            let amount = Double(columns[1]) ?? 0.0
            let regionRaw = columns[2].trimmingCharacters(in: .whitespacesAndNewlines)
            let detail = cleanCSVField(columns[3])
            let platform = cleanCSVField(columns[4])
            let isReceived = (columns[5].trimmingCharacters(in: .whitespacesAndNewlines) == "1")
            let transactionIndex = Int(columns[6])
            let txMerchant = cleanCSVField(columns[7])
            let txDateStr = columns[8]
            let txAmount = Double(columns[9]) ?? 0.0
            let txRegionRaw = columns[10].trimmingCharacters(in: .whitespacesAndNewlines)
            
            let date = dateStr.toDate()
            let region = regionMap[regionRaw] ?? .cn
            
            // 优先使用交易索引匹配
            var matchedTransaction: Transaction? = nil
            if let idx = transactionIndex, idx > 0, idx <= transactions.count {
                matchedTransaction = transactions[idx - 1]
            } else {
                // 兜底：按商户 + 日期 + 金额 + 地区匹配
                matchedTransaction = transactions.first(where: { t in
                    t.merchant == txMerchant &&
                    t.dateString == txDateStr &&
                    abs(t.spendingAmount - txAmount) < 0.0001 &&
                    t.location.rawValue == txRegionRaw
                })
            }
            
            let income = Income(
                amount: amount,
                date: date,
                location: region,
                transaction: matchedTransaction,
                detail: detail,
                platform: platform,
                isReceived: isReceived
            )
            context.insert(income)
        }
    }
    
    // MARK: - 辅助方法
    
    /// 清理 CSV 字段 (去引号 + 还原转义)
    private static func cleanCSVField(_ text: String) -> String {
        var s = text
        // 如果前后有引号，去掉它们
        if s.hasPrefix("\"") && s.hasSuffix("\"") {
            s.removeFirst()
            s.removeLast()
        }
        // 还原 CSV 的双引号转义 ("" -> ")
        return s.replacingOccurrences(of: "\"\"", with: "\"")
    }
    
    /// 智能分割 CSV 行 (核心算法)
    /// 能处理: 2025-01-01, "Starbucks, Inc.", Dining... 这种情况，不会在 Inc 后面的逗号切断
    private static func splitCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var insideQuotes = false
        
        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
                current.append(char) // 保留引号，交给 cleanCSVField 处理
            } else if char == "," && !insideQuotes {
                // 只有在不在引号内遇到逗号，才算分列
                result.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current)
        return result
    }
}

// MARK: - String Extension for Date Parsing
extension String {
    /// 将日期字符串转换为 Date 对象
    func toDate() -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: self) ?? Date()
    }
}

// MARK: - Transaction Array Extension
extension Array where Element == Transaction {
    
    /// 生成 CSV 文本内容（V2 格式，包含所有新字段）
    func generateCSV() -> String {
        // 1. 表头（V2 格式）
        var csvString = CSVHelper.v2Header
        
        // 2. 遍历
        for t in self {
            let date = t.dateString
            let safeMerchant = t.merchant.replacingOccurrences(of: "\"", with: "\"\"")
            let merchant = "\"\(safeMerchant)\""
            
            let category = t.category.displayName
            let amount = String(format: "%.2f", t.spendingAmount)
            let billing = String(format: "%.2f", t.billingAmount)
            let cashback = String(format: "%.2f", t.cashbackamount)
            let cardNumber = t.card?.endNum ?? "无卡"
            let cardName = t.card != nil ? "\"\(t.card!.bankName) \(t.card!.type)\"" : "已删除卡片"
            let region = t.location.rawValue
            
            // 新增字段
            let paymentMethod = "\"\(t.paymentMethod.replacingOccurrences(of: "\"", with: "\"\""))\""
            let spendingCurrency = t.spendingCurrency
            let billingCurrency = t.billingCurrency
            let cbfAmount = String(format: "%.2f", t.cbfAmount)
            let isOnlineShopping = t.isOnlineShopping ? "1" : "0"
            let isCBFApplied = t.isCBFApplied ? "1" : "0"
            let isCreditTransaction = t.isCreditTransaction ? "1" : "0"
            let csvVersion = CSVVersion.current.rawValue
            
            let row = "\(date),\(merchant),\(category),\(amount),\(billing),\(cashback),\(cardName),\(cardNumber),\(region),\(paymentMethod),\(spendingCurrency),\(billingCurrency),\(cbfAmount),\(isOnlineShopping),\(isCBFApplied),\(isCreditTransaction),\(csvVersion)\n"
            csvString.append(row)
        }
        return csvString
    }
    
    /// 生成旧版 CSV 文本内容（V1 格式，用于兼容旧版本导入）
    func generateCSVv1() -> String {
        // 1. 表头（V1 格式）
        var csvString = CSVHelper.v1Header
        
        // 2. 遍历
        for t in self {
            let date = t.dateString
            let safeMerchant = t.merchant.replacingOccurrences(of: "\"", with: "\"\"")
            let merchant = "\"\(safeMerchant)\""
            
            let category = t.category.displayName
            let amount = String(format: "%.2f", t.spendingAmount)
            let billing = String(format: "%.2f", t.billingAmount)
            let cashback = String(format: "%.2f", t.cashbackamount)
            let cardNumber = t.card?.endNum ?? "无卡"
            let cardName = t.card != nil ? "\"\(t.card!.bankName) \(t.card!.type)\"" : "已删除卡片"
            let region = t.location.rawValue
            
            let row = "\(date),\(merchant),\(category),\(amount),\(billing),\(cashback),\(cardName),\(cardNumber),\(region)\n"
            csvString.append(row)
        }
        return csvString
    }

    /// 导出带收据图片的压缩包，文件名中会包含交易日期与商户，便于识别。
    /// - Returns: 生成的 zip 文件 URL，如果当前没有收据则返回 nil。
    func exportReceiptsZip() -> URL? {
        let fileManager = FileManager.default
        let timestampFormatter = DateFormatter()
        timestampFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = timestampFormatter.string(from: Date())
        
        // 1. 创建临时导出根目录 (例如: tmp/Cashback_Export_20251212_101010)
        let rootFolderName = "Cashback_Export_\(timestamp)"
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(rootFolderName)
        
        // 最终的 Zip 路径
        let zipURL = fileManager.temporaryDirectory.appendingPathComponent("\(rootFolderName).zip")
        
        do {
            // 清理旧文件
            if fileManager.fileExists(atPath: rootURL.path) {
                try fileManager.removeItem(at: rootURL)
            }
            if fileManager.fileExists(atPath: zipURL.path) {
                try fileManager.removeItem(at: zipURL)
            }
            
            // 创建根目录
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
            
            // --- A. 写入 CSV（使用 V2 格式）---
            let bom = "\u{FEFF}"
            let csvString = bom + self.generateCSV()
            let csvURL = rootURL.appendingPathComponent("Transactions.csv")
            try csvString.write(to: csvURL, atomically: true, encoding: .utf8)
            
            // 记录收入行
            var incomeRows: [String] = []
            let incomeHeader = "收入日期,收入金额,收入地区,交易内容,交易平台,是否收款,交易索引,关联商户,关联交易日期,关联交易金额,关联交易地区\n"
            incomeRows.append(incomeHeader)
            
            // --- B. 写入收据图片 ---
            // 创建 Receipts 子文件夹
            let receiptsDir = rootURL.appendingPathComponent("Receipts")
            try fileManager.createDirectory(at: receiptsDir, withIntermediateDirectories: true)
            
            // 遍历并保存图片
            for (index, transaction) in self.enumerated() {
                if let data = transaction.receiptData {
                    let filename = CSVHelper.receiptFilename(
                        for: transaction.merchant,
                        date: transaction.date,
                        index: index + 1
                    )
                    let fileURL = receiptsDir.appendingPathComponent(filename)
                    try? data.write(to: fileURL)
                }
                
                if let incomes = transaction.incomes {
                    for income in incomes {
                        let row = Self.incomeCSVRow(for: income, transaction: transaction, transactionIndex: index + 1)
                        incomeRows.append(row)
                    }
                }
            }
            
            // 写入 Income.csv
            let incomeContent = "\u{FEFF}" + incomeRows.joined()
            let incomeURL = rootURL.appendingPathComponent("Income.csv")
            try incomeContent.write(to: incomeURL, atomically: true, encoding: .utf8)
            
            // --- C. 压缩整个根目录 ---
            try fileManager.zipItem(at: rootURL, to: zipURL, shouldKeepParent: false)
            
            // 清理临时目录
            try? fileManager.removeItem(at: rootURL)
            
            return zipURL
            
        } catch {
            print("打包导出失败: \(error)")
            return nil
        }
    }
    
    private static func incomeCSVRow(for income: Income, transaction: Transaction, transactionIndex: Int) -> String {
        let incomeDate = income.dateString
        let incomeAmount = String(format: "%.2f", income.amount)
        let incomeRegion = income.location.rawValue
        let detail = "\"\(income.detail.replacingOccurrences(of: "\"", with: "\"\""))\""
        let platform = "\"\(income.platform.replacingOccurrences(of: "\"", with: "\"\""))\""
        let receivedFlag = income.isReceived ? "1" : "0"
        
        let txMerchant = "\"\(transaction.merchant.replacingOccurrences(of: "\"", with: "\"\""))\""
        let txDate = transaction.dateString
        let txAmount = String(format: "%.2f", transaction.spendingAmount)
        let txRegion = transaction.location.rawValue
        
        return "\(incomeDate),\(incomeAmount),\(incomeRegion),\(detail),\(platform),\(receivedFlag),\(transactionIndex),\(txMerchant),\(txDate),\(txAmount),\(txRegion)\n"
    }
}
