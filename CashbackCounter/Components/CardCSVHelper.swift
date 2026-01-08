import Foundation
import SwiftUI
import SwiftData

struct CardCSVHelper {
    
    // CSV V2 表头（新增 FTF/CBF/月度年度上限等字段）
    static let headerV2 = "银行名称,卡种名称,尾号,颜色1(Hex),颜色2(Hex),地区(Code),本币返现率(%),外币返现率(%),本币上限,外币上限,餐饮加成(%),超市加成(%),出行加成(%),数码加成(%),其他加成(%),餐饮上限,超市上限,出行上限,数码上限,其他上限,上限周期(monthly/yearly),还款日,FTF(%),CBF(%),免FTF币种,月度上限,年度上限,开启提醒"
    
    // CSV V1 表头（旧版本兼容）
    static let headerV1 = "银行名称,卡种名称,尾号,颜色1(Hex),颜色2(Hex),地区(Code),本币返现率(%),外币返现率(%),本币上限,外币上限,餐饮加成(%),超市加成(%),出行加成(%),数码加成(%),其他加成(%),餐饮上限,超市上限,出行上限,数码上限,其他上限,上限周期(monthly/yearly),还款日"
    
    // MARK: - 导出逻辑 (生成字符串) - V2 格式
    static func generateCSV(from cards: [CreditCard]) -> String {
        // \u{FEFF} 是 BOM 头，确保 Excel 打开中文不乱码
        var csvString = "\u{FEFF}" + headerV2 + "\n"
        
        for card in cards {
            // 1. 基础信息 (防止逗号破坏格式)
            let bank = card.bankName.replacingOccurrences(of: ",", with: "，")
            let type = card.type.replacingOccurrences(of: ",", with: "，")
            let endNum = card.endNum
            
            // 2. 颜色
            let c1 = card.colorHexes.first ?? "0000FF"
            let c2 = card.colorHexes.last ?? "000000"
            
            // 3. 地区 & 基础费率
            let region = card.issueRegion.rawValue
            let defRate = String(format: "%.2f", card.defaultRate * 100)
            let forRate = card.foreignCurrencyRate != nil ? String(format: "%.2f", card.foreignCurrencyRate! * 100) : ""
            let locCap = card.localBaseCap > 0 ? String(format: "%.0f", card.localBaseCap) : ""
            let forCap = card.foreignBaseCap > 0 ? String(format: "%.0f", card.foreignBaseCap) : ""
            
            // 4. 类别加成
            let diningRate = fmtRate(card.specialRates[.dining])
            let groceryRate = fmtRate(card.specialRates[.grocery])
            let travelRate = fmtRate(card.specialRates[.travel])
            let digitalRate = fmtRate(card.specialRates[.digital])
            let otherRate = fmtRate(card.specialRates[.other])
            
            // 5. 类别上限
            let diningCap = fmtCap(card.categoryCaps[.dining])
            let groceryCap = fmtCap(card.categoryCaps[.grocery])
            let travelCap = fmtCap(card.categoryCaps[.travel])
            let digitalCap = fmtCap(card.categoryCaps[.digital])
            let otherCap = fmtCap(card.categoryCaps[.other])
            
            // 6. 上限周期和还款日
            let rDay = card.repaymentDay > 0 ? String(card.repaymentDay) : ""
            let capPeriodStr: String
            switch card.capPeriod {
            case .monthly:
                capPeriodStr = "monthly"
            case .yearly:
                capPeriodStr = "yearly"
            }
            
            // 7. 新增字段：FTF/CBF/免FTF币种/月度年度上限/开启提醒
            let ftfStr = card.ftf > 0 ? String(format: "%.2f", card.ftf * 100) : ""
            let cbfStr = card.cbf > 0 ? String(format: "%.2f", card.cbf * 100) : ""
            let ftfExceptStr = card.ftfExceptCurrencyCodes.joined(separator: ";")
            let monthlyCapStr = card.monthlyBaseCap != nil ? String(format: "%.0f", card.monthlyBaseCap!) : ""
            let yearlyCapStr = card.yearlyBaseCap != nil ? String(format: "%.0f", card.yearlyBaseCap!) : ""
            let isRemindStr = card.isRemindOpen ? "是" : "否"
            
            let row = "\(bank),\(type),\(endNum),\(c1),\(c2),\(region),\(defRate),\(forRate),\(locCap),\(forCap),\(diningRate),\(groceryRate),\(travelRate),\(digitalRate),\(otherRate),\(diningCap),\(groceryCap),\(travelCap),\(digitalCap),\(otherCap),\(capPeriodStr),\(rDay),\(ftfStr),\(cbfStr),\(ftfExceptStr),\(monthlyCapStr),\(yearlyCapStr),\(isRemindStr)\n"
            csvString.append(row)
        }
        return csvString
    }
    
    // MARK: - 导入逻辑 (解析字符串) - 兼容 V1 和 V2 格式
    static func parseCSV(content: String, into context: ModelContext) throws {
        let rows = content.components(separatedBy: .newlines)
        let templates = try context.fetch(FetchDescriptor<CardTemplate>())
        let templateMap = Dictionary(uniqueKeysWithValues: templates.map { ($0.templateKey, $0) })

        for (index, row) in rows.enumerated() {
            if index == 0 || row.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            
            let columns = row.components(separatedBy: ",")
            if columns.count < 21 { continue }
        
            // 解析基础字段
            let bankName = columns[0]
            let type = columns[1]
            let endNum = columns[2]
            let c1 = columns[3]
            let c2 = columns[4]
            let regionRaw = columns[5]
            let region = Region.allCases.first(where: { $0.rawValue == regionRaw }) ?? .cn
            
            let defRate = (Double(columns[6]) ?? 0) / 100.0
            let forRateStr = columns[7]
            let forRate = forRateStr.isEmpty ? nil : (Double(forRateStr) ?? 0) / 100.0
            let locCap = Double(columns[8]) ?? 0
            let forCap = Double(columns[9]) ?? 0
            
            var specialRates: [Category: Double] = [:]
            if let r = Double(columns[10]), r > 0 { specialRates[.dining] = r / 100.0 }
            if let r = Double(columns[11]), r > 0 { specialRates[.grocery] = r / 100.0 }
            if let r = Double(columns[12]), r > 0 { specialRates[.travel] = r / 100.0 }
            if let r = Double(columns[13]), r > 0 { specialRates[.digital] = r / 100.0 }
            if let r = Double(columns[14]), r > 0 { specialRates[.other] = r / 100.0 }
            
            var categoryCaps: [Category: Double] = [:]
            if let c = Double(columns[15]), c > 0 { categoryCaps[.dining] = c }
            if let c = Double(columns[16]), c > 0 { categoryCaps[.grocery] = c }
            if let c = Double(columns[17]), c > 0 { categoryCaps[.travel] = c }
            if let c = Double(columns[18]), c > 0 { categoryCaps[.digital] = c }
            if let c = Double(columns[19]), c > 0 { categoryCaps[.other] = c }
            
            // 解析上限周期和还款日
            let capPeriod: CapPeriod
            let rDay: Int
            if columns.count >= 22 {
                let capStr = columns[20].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                switch capStr {
                case "monthly", "month", "m", "按月":
                    capPeriod = .monthly
                case "yearly", "year", "y", "按年":
                    capPeriod = .yearly
                default:
                    capPeriod = .yearly
                }
                rDay = Int(columns[21]) ?? 0
            } else {
                capPeriod = .yearly
                rDay = Int(columns[20]) ?? 0
            }
            
            // V2 新增字段（兼容旧版本）
            var ftf: Double = 0
            var cbf: Double = 0
            var ftfExceptCodes: [String] = []
            var monthlyBaseCap: Double? = nil
            var yearlyBaseCap: Double? = nil
            var isRemindOpen: Bool = false
            
            if columns.count >= 28 {
                // V2 格式
                ftf = (Double(columns[22]) ?? 0) / 100.0
                cbf = (Double(columns[23]) ?? 0) / 100.0
                ftfExceptCodes = columns[24].split(separator: ";").map { String($0).trimmingCharacters(in: .whitespaces) }
                if let mc = Double(columns[25]), mc > 0 { monthlyBaseCap = mc }
                if let yc = Double(columns[26]), yc > 0 { yearlyBaseCap = yc }
                isRemindOpen = columns[27].trimmingCharacters(in: .whitespaces) == "是"
            }
            
            let newCard = CreditCard(
                bankName: bankName,
                type: type,
                endNum: endNum,
                colorHexes: [c1, c2],
                defaultRate: defRate,
                specialRates: specialRates,
                issueRegion: region,
                foreignCurrencyRate: forRate,
                localBaseCap: locCap,
                foreignBaseCap: forCap,
                categoryCaps: categoryCaps,
                capPeriod: capPeriod,
                repaymentDay: rDay,
                isRemindOpen: isRemindOpen,
                ftf: ftf,
                cbf: cbf,
                ftfExceptCurrencyCodes: ftfExceptCodes,
                monthlyBaseCap: monthlyBaseCap,
                yearlyBaseCap: yearlyBaseCap
            )

            let templateKey = CardTemplate.templateKey(bankName: bankName, type: type)
            if let template = templateMap[templateKey] {
                template.applyRules(to: newCard)
            }

            context.insert(newCard)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationManager.shared.scheduleNotification(for: newCard)
            }
        }
    }
    
    // 辅助格式化
    private static func fmtRate(_ val: Double?) -> String {
        guard let v = val else { return "" }
        return String(format: "%.2f", v * 100)
    }
    private static func fmtCap(_ val: Double?) -> String {
        guard let v = val, v > 0 else { return "" }
        return String(format: "%.0f", v)
    }
}

// 核心扩展：完全照抄 BillHomeView 的 exportCSVFile 模式
extension Array where Element == CreditCard {
    
    // 生成临时的 CSV 文件 URL (用于分享)
    func exportCSVFile() -> URL? {
        // 1. 生成内容
        let csvString = CardCSVHelper.generateCSV(from: self)
        
        // 2. 生成文件名 (带时间戳)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let dateString = formatter.string(from: Date())
        let fileName = "Cards_Backup_\(dateString).csv"
        
        // 3. 写入临时目录
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            print("卡片导出失败: \(error)")
            return nil
        }
    }
}
