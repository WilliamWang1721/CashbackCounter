//
//  AddCardView.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import SwiftUI
import SwiftData

struct AddCardView: View {
    @Environment(\.modelContext) var context
    @Environment(\.dismiss) var dismiss
    
    // 1. 接收要编辑的卡片 (如果是 nil 就是添加模式)
    var cardToEdit: CreditCard?
    private let template: CardTemplate?
    var onSaved: (() -> Void)? = nil
    
    // --- 表单状态 ---
    @State private var bankName: String
    @State private var cardType: String
    @State private var endNum: String
    
    @State private var color1: Color
    @State private var capPeriod: CapPeriod
    @State private var color2: Color
    @State private var region: Region
    
    @State private var defaultRateStr: String
    @State private var foreignRateStr: String
    @State private var diningRateStr: String = ""
    @State private var groceryRateStr: String = ""
    @State private var travelRateStr: String = ""
    @State private var digitalRateStr: String = ""
    @State private var otherRateStr: String = ""
    
    // 上限设置 (Cap) 变量
    @State private var localBaseCapStr: String = ""
    @State private var foreignBaseCapStr: String = ""
    
    // 新增：月度/年度上限
    @State private var monthlyBaseCapStr: String = ""
    @State private var yearlyBaseCapStr: String = ""
    
    // 各个类别的加成上限
    @State private var diningCapStr: String = ""
    @State private var groceryCapStr: String = ""
    @State private var travelCapStr: String = ""
    @State private var digitalCapStr: String = ""
    @State private var otherCapStr: String = ""
    
    // 还款日提醒
    @State private var repaymentDayStr: String = ""
    @State private var isRemindOpen: Bool = false
    
    // 新增：FTF/CBF 相关
    @State private var ftfStr: String = ""
    @State private var cbfStr: String = ""
    @State private var ftfExceptCurrencies: String = ""
    
    // 新增：卡面图片
    @State private var selectedCardImage: UIImage?
    @State private var showImagePicker = false
    
    // --- 2. 核心：自定义初始化 ---
    init(template: CardTemplate? = nil, cardToEdit: CreditCard? = nil, onSaved: (() -> Void)? = nil) {
        self.cardToEdit = cardToEdit
        self.template = template
        self.onSaved = onSaved
        
        // 逻辑 A: 如果是编辑模式 (cardToEdit 有值) -> 填充旧数据
        if let card = cardToEdit {
            _bankName = State(initialValue: card.bankName)
            _cardType = State(initialValue: card.type)
            _endNum = State(initialValue: card.endNum)
            if card.repaymentDay > 0 {
                _repaymentDayStr = State(initialValue: String(card.repaymentDay))
            }
            _isRemindOpen = State(initialValue: card.isRemindOpen)
            
            // 颜色回填
            if card.colors.count >= 2 {
                _color1 = State(initialValue: card.colors[0])
                _color2 = State(initialValue: card.colors[1])
            } else {
                _color1 = State(initialValue: .blue)
                _color2 = State(initialValue: .purple)
            }
            
            _region = State(initialValue: card.issueRegion)
            _capPeriod = State(initialValue: card.capPeriod)
            
            // 费率回填
            _defaultRateStr = State(initialValue: String(card.defaultRate * 100))
            
            if let foreignRate = card.foreignCurrencyRate {
                _foreignRateStr = State(initialValue: String(foreignRate * 100))
            } else {
                _foreignRateStr = State(initialValue: "")
            }
            if let rate = card.specialRates[.dining] {
                _diningRateStr = State(initialValue: String(rate * 100))
            }
            if let rate = card.specialRates[.grocery] {
                _groceryRateStr = State(initialValue: String(rate * 100))
            }
            if let rate = card.specialRates[.travel] {
                _travelRateStr = State(initialValue: String(rate * 100))
            }
            if let rate = card.specialRates[.digital] {
                _digitalRateStr = State(initialValue: String(rate * 100))
            }
            if let rate = card.specialRates[.other] {
                _otherRateStr = State(initialValue: String(rate * 100))
            }
            
            // 回填上限数据
            if card.localBaseCap > 0 { _localBaseCapStr = State(initialValue: String(format: "%.0f", card.localBaseCap)) }
            if card.foreignBaseCap > 0 { _foreignBaseCapStr = State(initialValue: String(format: "%.0f", card.foreignBaseCap)) }
            if let monthCap = card.monthlyBaseCap, monthCap > 0 { _monthlyBaseCapStr = State(initialValue: String(format: "%.0f", monthCap)) }
            if let yearCap = card.yearlyBaseCap, yearCap > 0 { _yearlyBaseCapStr = State(initialValue: String(format: "%.0f", yearCap)) }
            
            // 回填类别上限
            if let cap = card.categoryCaps[.dining], cap > 0 { _diningCapStr = State(initialValue: String(format: "%.0f", cap)) }
            if let cap = card.categoryCaps[.grocery], cap > 0 { _groceryCapStr = State(initialValue: String(format: "%.0f", cap)) }
            if let cap = card.categoryCaps[.travel], cap > 0 { _travelCapStr = State(initialValue: String(format: "%.0f", cap)) }
            if let cap = card.categoryCaps[.digital], cap > 0 { _digitalCapStr = State(initialValue: String(format: "%.0f", cap)) }
            if let cap = card.categoryCaps[.other], cap > 0 { _otherCapStr = State(initialValue: String(format: "%.0f", cap)) }
            
            // 回填 FTF/CBF
            if card.ftf > 0 { _ftfStr = State(initialValue: String(format: "%.2f", card.ftf * 100)) }
            if card.cbf > 0 { _cbfStr = State(initialValue: String(format: "%.2f", card.cbf * 100)) }
            if !card.ftfExceptCurrencyCodes.isEmpty {
                _ftfExceptCurrencies = State(initialValue: card.ftfExceptCurrencyCodes.joined(separator: ", "))
            }
            
            // 回填卡面图片
            if let imageData = card.cardImageData {
                _selectedCardImage = State(initialValue: UIImage(data: imageData))
            }
            
        }
        // 逻辑 B: 如果是模板模式 -> 填充模板数据
        else if let template = template {
            _bankName = State(initialValue: template.bankName)
            _cardType = State(initialValue: template.type)
            _endNum = State(initialValue: "8888")
            _isRemindOpen = State(initialValue: false)
            
            if template.localBaseCap > 0 {
                _localBaseCapStr = State(initialValue: String(format: "%.0f", template.localBaseCap))
            }
            if template.foreignBaseCap > 0 {
                _foreignBaseCapStr = State(initialValue: String(format: "%.0f", template.foreignBaseCap))
            }
            
            if template.colors.count >= 2 {
                _color1 = State(initialValue: Color(hex: template.colors[0]))
                _color2 = State(initialValue: Color(hex: template.colors[1]))
            } else {
                _color1 = State(initialValue: .blue)
                _color2 = State(initialValue: .purple)
            }
            
            if let cap = template.categoryCaps[.dining], cap > 0 {
                _diningCapStr = State(initialValue: String(format: "%.0f", cap))
            }
            if let cap = template.categoryCaps[.grocery], cap > 0 {
                _groceryCapStr = State(initialValue: String(format: "%.0f", cap))
            }
            if let cap = template.categoryCaps[.travel], cap > 0 {
                _travelCapStr = State(initialValue: String(format: "%.0f", cap))
            }
            if let cap = template.categoryCaps[.digital], cap > 0 {
                _digitalCapStr = State(initialValue: String(format: "%.0f", cap))
            }
            if let cap = template.categoryCaps[.other], cap > 0 {
                _otherCapStr = State(initialValue: String(format: "%.0f", cap))
            }

            _region = State(initialValue: template.region)
            _capPeriod = State(initialValue: template.capPeriod)
            let defStr = String(format: "%.1f", template.defaultRate)
            _defaultRateStr = State(initialValue: defStr.replacingOccurrences(of: ".0", with: ""))

            if let fr = template.foreignCurrencyRate {
                let frStr = String(format: "%.1f", fr)
                _foreignRateStr = State(initialValue: frStr.replacingOccurrences(of: ".0", with: ""))
            } else {
                _foreignRateStr = State(initialValue: "")
            }
            
            // 填充特殊返现率
            if let dining = template.specialRate[.dining] {
                let s = String(format: "%.1f", dining).replacingOccurrences(of: ".0", with: "")
                _diningRateStr = State(initialValue: s)
            }
            if let grocery = template.specialRate[.grocery] {
                let s = String(format: "%.1f", grocery).replacingOccurrences(of: ".0", with: "")
                _groceryRateStr = State(initialValue: s)
            }
            if let travel = template.specialRate[.travel] {
                let s = String(format: "%.1f", travel).replacingOccurrences(of: ".0", with: "")
                _travelRateStr = State(initialValue: s)
            }
            if let digital = template.specialRate[.digital] {
                let s = String(format: "%.1f", digital).replacingOccurrences(of: ".0", with: "")
                _digitalRateStr = State(initialValue: s)
            }
            if let other = template.specialRate[.other] {
                let s = String(format: "%.1f", other).replacingOccurrences(of: ".0", with: "")
                _otherRateStr = State(initialValue: s)
            }
        }
        // 逻辑 C: 纯新建模式 -> 全部给空值/默认值
        else {
            _bankName = State(initialValue: "")
            _cardType = State(initialValue: "")
            _endNum = State(initialValue: "")
            _color1 = State(initialValue: .blue)
            _color2 = State(initialValue: .purple)
            _region = State(initialValue: .cn)
            _capPeriod = State(initialValue: .monthly)
            _defaultRateStr = State(initialValue: "1.0")
            _foreignRateStr = State(initialValue: "")
            _isRemindOpen = State(initialValue: false)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                // 1. 实时预览
                Section {
                    if let image = selectedCardImage {
                        // 显示自定义卡面图片
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(1.586, contentMode: .fit)
                            .cornerRadius(12)
                            .overlay(
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        Text(endNum.isEmpty ? "8888" : endNum)
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(8)
                                            .background(Color.black.opacity(0.5))
                                            .cornerRadius(4)
                                    }
                                }
                                .padding(8)
                            )
                    } else {
                        CreditCardView(
                            bankName: bankName.isEmpty ? "银行名称" : bankName,
                            type: cardType.isEmpty ? "卡种" : cardType,
                            endNum: endNum.isEmpty ? "8888" : endNum,
                            colors: [color1, color2]
                        )
                    }
                }
                .listRowInsets(EdgeInsets())
                .padding(.vertical)
                .background(Color(uiColor: .systemGroupedBackground))
                
                // 2. 基本信息
                Section(header: Text("基本信息")) {
                    TextField("银行 (如: 招商银行)", text: $bankName)
                    TextField("卡种 (如: 运通白金)", text: $cardType)
                    TextField("尾号 (后四位)", text: $endNum)
                        .keyboardType(.numberPad)
                        .onChange(of: endNum) { oldValue, newValue in
                            if newValue.count > 4 { endNum = String(newValue.prefix(4)) }
                        }
                    
                    Picker("发行地区", selection: $region) {
                        ForEach(Region.allCases, id: \.self) { r in
                            Text("\(r.icon) \(r.rawValue)").tag(r)
                        }
                    }
                }
                
                // 还款日提醒
                Section(header: Text("还款提醒")) {
                    HStack {
                        Text("还款日 (每月)")
                        Spacer()
                        TextField("无", text: $repaymentDayStr)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 50)
                        Text("日")
                            .foregroundColor(.secondary)
                    }
                    
                    Toggle("开启还款提醒", isOn: $isRemindOpen)
                    
                    if isRemindOpen && !repaymentDayStr.isEmpty {
                        Text("将在每月 \(repaymentDayStr) 日发送提醒")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 卡面设置
                Section(header: Text("卡面管理")) {
                    if selectedCardImage != nil {
                        Button {
                            showImagePicker = true
                        } label: {
                            Label("更换卡面", systemImage: "photo.on.rectangle")
                        }
                        
                        Button(role: .destructive) {
                            selectedCardImage = nil
                        } label: {
                            Label("移除自定义卡面", systemImage: "trash")
                        }
                    } else {
                        Button {
                            showImagePicker = true
                        } label: {
                            Label("添加卡面图片", systemImage: "photo.on.rectangle")
                        }
                        
                        // 渐变色设置（仅在没有自定义图片时显示）
                        ColorPicker("渐变色 1", selection: $color1)
                        ColorPicker("渐变色 2", selection: $color2)
                    }
                }
                
                // FTF/CBF 设置
                Section(header: Text("外币交易费")) {
                    HStack {
                        Text("FTF (外币交易费)")
                        Spacer()
                        TextField("0", text: $ftfStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("%")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("免 FTF 币种")
                        Spacer()
                        TextField("如: USD, EUR", text: $ftfExceptCurrencies)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                    
                    HStack {
                        Text("CBF (跨境港币交易费)")
                        Spacer()
                        TextField("0", text: $cbfStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("%")
                            .foregroundColor(.secondary)
                    }
                }
                
                // 返现上限周期
                Section(header: Text("返现上限周期")){
                    Picker("返现上限周期", selection: $capPeriod) {
                        Text("按月").tag(CapPeriod.monthly)
                        Text("按年").tag(CapPeriod.yearly)
                    }
                    .pickerStyle(.segmented)
                }
                
                // 基础返现设置
                Section(header: Text("基础返现 (所有消费)")) {
                    // 本币基础
                    HStack {
                        Text("本币返现率 (%)")
                        Spacer()
                        TextField("1.0", text: $defaultRateStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 50)
                    }
                    HStack {
                        Text("本币\(capPeriod == .monthly ? "月" : "年")上限")
                            .font(.caption).foregroundColor(.secondary)
                        Spacer()
                        TextField("无上限", text: $localBaseCapStr)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    // 外币基础
                    HStack {
                        Text("外币返现率 (%)")
                        Spacer()
                        TextField("同本币", text: $foreignRateStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 50)
                    }
                    HStack {
                        Text("外币\(capPeriod == .monthly ? "月" : "年")上限")
                            .font(.caption).foregroundColor(.secondary)
                        Spacer()
                        TextField("无上限", text: $foreignBaseCapStr)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    // 新版上限（月度/年度）
                    HStack {
                        Text("月度总上限")
                            .font(.caption).foregroundColor(.secondary)
                        Spacer()
                        TextField("无上限", text: $monthlyBaseCapStr)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("年度总上限")
                            .font(.caption).foregroundColor(.secondary)
                        Spacer()
                        TextField("无上限", text: $yearlyBaseCapStr)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
                
                // 类别加成
                Section(header: Text("类别加成 (额外叠加)")) {
                    CategoryInputRow(name: "餐饮", rate: $diningRateStr, cap: $diningCapStr)
                    CategoryInputRow(name: "超市", rate: $groceryRateStr, cap: $groceryCapStr)
                    CategoryInputRow(name: "出行", rate: $travelRateStr, cap: $travelCapStr)
                    CategoryInputRow(name: "数码", rate: $digitalRateStr, cap: $digitalCapStr)
                    CategoryInputRow(name: "其他", rate: $otherRateStr, cap: $otherCapStr)
                }
                
            }
            .navigationTitle(cardToEdit == nil ? "添加信用卡" : "编辑卡片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveCard() }
                        .disabled(bankName.isEmpty || cardType.isEmpty)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: $selectedCardImage, sourceType: .photoLibrary)
            }
        }
    }
    
    // --- 3. 核心保存逻辑 ---
    func saveCard() {
        // 1. 处理费率
        let defaultRate = (Double(defaultRateStr) ?? 0) / 100.0
        let rDay = Int(repaymentDayStr) ?? 0
        var foreignRate: Double? = nil
        if !foreignRateStr.isEmpty {
            foreignRate = (Double(foreignRateStr) ?? 0) / 100.0
        }
        
        // 2. 处理颜色
        let c1Hex = color1.toHex() ?? "0000FF"
        let c2Hex = color2.toHex() ?? "000000"
        
        // 3. 处理类别加成率
        var specialRates: [Category: Double] = [:]
        if let rate = Double(diningRateStr), rate > 0 { specialRates[.dining] = rate / 100.0 }
        if let rate = Double(groceryRateStr), rate > 0 { specialRates[.grocery] = rate / 100.0 }
        if let rate = Double(travelRateStr), rate > 0 { specialRates[.travel] = rate / 100.0 }
        if let rate = Double(digitalRateStr), rate > 0 { specialRates[.digital] = rate / 100.0 }
        if let rate = Double(otherRateStr), rate > 0 { specialRates[.other] = rate / 100.0 }
        
        // 4. 处理上限
        let locBaseCap = Double(localBaseCapStr) ?? 0
        let forBaseCap = Double(foreignBaseCapStr) ?? 0
        let monthCap: Double? = Double(monthlyBaseCapStr)
        let yearCap: Double? = Double(yearlyBaseCapStr)
        
        var catCaps: [Category: Double] = [:]
        if let cap = Double(diningCapStr), cap > 0 { catCaps[.dining] = cap }
        if let cap = Double(groceryCapStr), cap > 0 { catCaps[.grocery] = cap }
        if let cap = Double(travelCapStr), cap > 0 { catCaps[.travel] = cap }
        if let cap = Double(digitalCapStr), cap > 0 { catCaps[.digital] = cap }
        if let cap = Double(otherCapStr), cap > 0 { catCaps[.other] = cap }
        
        // 5. 处理 FTF/CBF
        let ftfValue = (Double(ftfStr) ?? 0) / 100.0
        let cbfValue = (Double(cbfStr) ?? 0) / 100.0
        let ftfExceptCodes = ftfExceptCurrencies
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty }
        
        // 6. 处理卡面图片
        let cardImageData = selectedCardImage?.jpegData(compressionQuality: 0.8)
        
        if let existingCard = cardToEdit {
            // 编辑模式
            existingCard.bankName = bankName
            existingCard.type = cardType
            existingCard.endNum = endNum
            existingCard.colorHexes = [c1Hex, c2Hex]
            existingCard.defaultRate = defaultRate
            existingCard.issueRegion = region
            existingCard.foreignCurrencyRate = foreignRate
            existingCard.capPeriod = capPeriod
            existingCard.specialRates = specialRates
            
            existingCard.localBaseCap = locBaseCap
            existingCard.foreignBaseCap = forBaseCap
            existingCard.monthlyBaseCap = monthCap
            existingCard.yearlyBaseCap = yearCap
            existingCard.categoryCaps = catCaps
            existingCard.repaymentDay = rDay
            existingCard.isRemindOpen = isRemindOpen
            
            existingCard.ftf = ftfValue
            existingCard.cbf = cbfValue
            existingCard.ftfExceptCurrencyCodes = ftfExceptCodes
            existingCard.cardImageData = cardImageData
            
            NotificationManager.shared.scheduleNotification(for: existingCard)
            
        } else {
            // 新建模式
            let newCard = CreditCard(
                bankName: bankName,
                type: cardType,
                endNum: endNum,
                colorHexes: [c1Hex, c2Hex],
                defaultRate: defaultRate,
                specialRates: specialRates,
                issueRegion: region,
                foreignCurrencyRate: foreignRate,
                templateKey: template?.templateKey,
                localBaseCap: locBaseCap,
                foreignBaseCap: forBaseCap,
                categoryCaps: catCaps,
                capPeriod: capPeriod,
                repaymentDay: rDay,
                isRemindOpen: isRemindOpen,
                ftf: ftfValue,
                cbf: cbfValue,
                ftfExceptCurrencyCodes: ftfExceptCodes,
                monthlyBaseCap: monthCap,
                yearlyBaseCap: yearCap,
                cardImageData: cardImageData
            )
            context.insert(newCard)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationManager.shared.scheduleNotification(for: newCard)
            }
        }
        
        dismiss()
        onSaved?()
    }
    
    struct CategoryInputRow: View {
        let name: String
        @Binding var rate: String
        @Binding var cap: String
        
        var body: some View {
            VStack(spacing: 8) {
                HStack {
                    Text(name)
                        .fontWeight(.medium)
                    Spacer()
                    // 费率输入
                    Text("加成%")
                        .font(.caption).foregroundColor(.gray)
                    TextField("0", text: $rate)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 40)
                        .padding(5)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(5)
                    
                    // 上限输入
                    Text("上限")
                        .font(.caption).foregroundColor(.gray)
                    TextField("无", text: $cap)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        .padding(5)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(5)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
