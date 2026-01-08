//
//  AddTransactionView.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import SwiftUI
import SwiftData

struct AddTransactionView: View {
    // 1. 数据库与环境
    @Environment(\.modelContext) var context
    @Environment(\.dismiss) var dismiss
    @Query var cards: [CreditCard]
    
    // 2. 回调与编辑对象
    var onSaved: (() -> Void)? = nil
    var transactionToEdit: Transaction?
    
    // --- 表单的状态变量 ---
    @State private var merchant: String = ""
    @State private var spendingAmount: String = ""
    @State private var selectedCategory: Category = .dining
    @State private var date: Date = Date()
    @State private var selectedCardIndex: Int = 0
    @State private var location: Region = .cn
    @State private var billingAmountStr: String = ""
    @State private var receiptImage: UIImage?
    
    // --- 新增：消费/入账币种 ---
    @State private var spendingCurrency: Region = .cn
    
    // --- 新增：交易属性字段 ---
    @State private var paymentMethod: String = ""
    @State private var isOnlineShopping: Bool = false
    @State private var isCBFApplied: Bool = false
    @State private var cbfAmount: Double = 0.0
    
    // --- AI 分析与图片选择 ---
    @State private var isAnalyzing: Bool = false
    @State private var showFullImage = false
    @State private var showImagePicker: Bool = false
    
    // --- 支付方式选项 ---
    private let paymentMethodOptions = ["", "SALE", "网购", "Apple Pay", "银联二维码", "线下购物", "退款", "还款", "其他"]

    
    // --- 3. 自定义初始化 ---
    init(transaction: Transaction? = nil, image: UIImage? = nil, onSaved: (() -> Void)? = nil) {
        self.transactionToEdit = transaction
        self.onSaved = onSaved
        
        if let t = transaction {
            // 编辑模式
            _merchant = State(initialValue: t.merchant)
            _spendingAmount = State(initialValue: String(t.spendingAmount))
            _billingAmountStr = State(initialValue: String(t.billingAmount))
            _selectedCategory = State(initialValue: t.category)
            _date = State(initialValue: t.date)
            _location = State(initialValue: t.location)
            
            // 加载消费币种
            if let matchedRegion = Region.allCases.first(where: { $0.currencyCode == t.spendingCurrency }) {
                _spendingCurrency = State(initialValue: matchedRegion)
            } else {
                _spendingCurrency = State(initialValue: t.location)
            }
            
            // 加载交易属性
            _paymentMethod = State(initialValue: t.paymentMethod)
            _isOnlineShopping = State(initialValue: t.isOnlineShopping)
            _isCBFApplied = State(initialValue: t.isCBFApplied)
            _cbfAmount = State(initialValue: t.cbfAmount)
            
            if let data = t.receiptData {
                _receiptImage = State(initialValue: UIImage(data: data))
            }
        } else {
            // 新建模式 (可能带图)
            _receiptImage = State(initialValue: image)
        }
    }
    
    var currentCurrencySymbol: String {
        if cards.indices.contains(selectedCardIndex) {
            let card = cards[selectedCardIndex]
            return card.issueRegion.currencySymbol
        }
        return "¥"
    }
    
    var body: some View {
        NavigationView {
            Form {
                // --- 第一组：消费详情 ---
                Section(header: Text("消费详情")) {
                    TextField("商户名称 (例如：星巴克)", text: $merchant)
                    
                    // 消费币种选择
                    Picker("消费币种", selection: $spendingCurrency) {
                        ForEach(Region.allCases, id: \.self) { r in
                            Text("\(r.icon) \(r.currencyCode)").tag(r)
                        }
                    }
                    
                    // 消费金额
                    HStack {
                        Text(spendingCurrency.currencySymbol)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        
                        TextField("消费金额", text: $spendingAmount)
                            .keyboardType(.decimalPad)
                    }
                    
                    Picker("消费类别", selection: $selectedCategory) {
                        ForEach(Category.allCases, id: \.self) { c in
                            HStack {
                                Image(systemName: c.iconName).foregroundColor(c.color)
                                Text(c.displayName)
                            }
                            .tag(c)
                        }
                    }
                    
                    Picker("消费地区", selection: $location) {
                        ForEach(Region.allCases, id: \.self) { r in
                            Text("\(r.icon) \(r.rawValue)").tag(r)
                        }
                    }
                    
                    // 币种与地区不一致提示
                    if spendingCurrency != location {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("消费币种(\(spendingCurrency.currencyCode))与地区(\(location.rawValue))不一致")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // --- 第二组：交易属性 ---
                Section(header: Text("交易属性")) {
                    Picker("支付方式", selection: $paymentMethod) {
                        Text("未选择").tag("")
                        ForEach(paymentMethodOptions.filter { !$0.isEmpty }, id: \.self) { method in
                            Text(method).tag(method)
                        }
                    }
                    
                    Toggle("网上购物", isOn: $isOnlineShopping)
                    Toggle("适用CBF？", isOn: $isCBFApplied)
                    
                    // 如果适用 CBF，显示 CBF 金额输入
                    if isCBFApplied {
                        HStack {
                            Text("CBF 金额")
                                .foregroundColor(.orange)
                            Spacer()
                            TextField("0.00", value: $cbfAmount, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                
                // --- 第三组：收据图片预览 + 上传/删除  ---
                Section(header: Text("收据凭证")) {
                    if let image = receiptImage {
                        ZStack {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .cornerRadius(10)
                                .opacity(isAnalyzing ? 0.5 : 1.0)
                                .onTapGesture {
                                    showFullImage = true
                                }
                            if isAnalyzing {
                                ProgressView("AI 分析中...")
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(10)
                            }
                        }
                        .sheet(isPresented: $showFullImage){
                            ReceiptFullScreenView(image: image)
                                .presentationDragIndicator(.visible)
                        }
                        Button(role: .destructive) {
                            receiptImage = nil
                        } label: {
                            Label("删除图片", systemImage: "trash")
                        }
                        
                        Button {
                            showImagePicker = true
                        } label: {
                            Label("重新上传", systemImage: "arrow.triangle.2.circlepath")
                        }
                    } else {
                        Button {
                            showImagePicker = true
                        } label: {
                            Label("上传收据图片", systemImage: "photo.on.rectangle")
                        }
                        
                    }
                }
            
                
                // --- 第四组：支付方式 ---
                Section(header: Text("支付卡片")) {
                    if cards.isEmpty {
                        Text("请先添加信用卡").foregroundColor(.secondary)
                    } else {
                        Picker("选择信用卡", selection: $selectedCardIndex) {
                            ForEach(0..<cards.count, id: \.self) { index in
                                Text(cards[index].bankName + " " + cards[index].type).tag(index)
                            }
                        }
                    }
                    
                    // 入账金额（当消费币种与卡片币种不同时显示）
                    if cards.indices.contains(selectedCardIndex) {
                        let card = cards[selectedCardIndex]
                        if spendingCurrency.currencyCode != card.issueRegion.currencyCode {
                            HStack {
                                Text(card.issueRegion.currencySymbol)
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                                TextField("入账金额", text: $billingAmountStr)
                                    .keyboardType(.decimalPad)
                            }
                        }
                    }
                    
                    DatePicker("消费日期", selection: $date, in: ...Date(), displayedComponents: .date)
                }
                
                // --- 第五组：实时预算返现 ---
                Section {
                    HStack {
                        Text("预计返现")
                        Spacer()
                        if let amountDouble = Double(spendingAmount),
                           cards.indices.contains(selectedCardIndex) {
                            
                            let card = cards[selectedCardIndex]
                            let finalAmount = Double(billingAmountStr) ?? amountDouble
                            
                            // 检查是否为不计返现的交易类型
                            let isNonCashbackTransaction = ["退款", "还款"].contains(paymentMethod)
                            
                            let cashback: Double
                            if isNonCashbackTransaction {
                                cashback = 0.0
                            } else {
                                cashback = card.calculateCappedCashback(
                                    amount: finalAmount,
                                    category: selectedCategory,
                                    location: location,
                                    date: date,
                                    transactionToExclude: transactionToEdit
                                )
                            }
                            
                            let theoretical = finalAmount * card.getRate(for: selectedCategory, location: location)
                            
                            HStack(spacing: 4) {
                                if isNonCashbackTransaction {
                                    Text("此类交易不计算返现")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                } else {
                                    Text("\(currentCurrencySymbol)\(String(format: "%.2f", cashback))")
                                        .foregroundColor(cashback < theoretical - 0.01 ? .orange : .green)
                                        .fontWeight(.bold)
                                    
                                    if cashback < theoretical - 0.01 {
                                        Image(systemName: "exclamationmark.circle")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                        } else {
                            Text("¥0.00").foregroundColor(.gray)
                        }
                    }
                    
                    // 如果有 CBF，显示实际成本
                    if isCBFApplied && cbfAmount > 0 {
                        HStack {
                            Text("实际成本 (含 CBF)")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Spacer()
                            if let billing = Double(billingAmountStr) ?? Double(spendingAmount) {
                                Text("\(currentCurrencySymbol)\(String(format: "%.2f", billing + cbfAmount))")
                                    .foregroundColor(.orange)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
            .navigationTitle(transactionToEdit == nil ? "记一笔" : "编辑账单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveTransaction() }
                        .disabled(merchant.isEmpty || spendingAmount.isEmpty || cards.isEmpty)
                }
            }
            .onAppear {
                if let t = transactionToEdit, let card = t.card,
                   let index = cards.firstIndex(of: card) {
                    selectedCardIndex = index
                }
                else if receiptImage != nil && spendingAmount.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        analyzeReceipt()
                    }
                }
            }
            .onChange(of: receiptImage) { oldValue, newImage in
                if newImage != nil {
                    analyzeReceipt()
                }
            }
            .onChange(of: spendingAmount) { updateBillingAmount() }
            .onChange(of: spendingCurrency) { updateBillingAmount() }
            .onChange(of: location) { updateBillingAmount() }
            .onChange(of: selectedCardIndex) { updateBillingAmount() }
            .onChange(of: paymentMethod) { _, newValue in
                // 如果选择了网购，自动勾选网上购物
                if newValue == "网购" {
                    isOnlineShopping = true
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: $receiptImage, sourceType: .photoLibrary)
            }
        }
    }
    
    // --- 4. AI 分析逻辑 ---
    func analyzeReceipt() {
        guard let image = receiptImage else { return }
        
        if !merchant.isEmpty || !spendingAmount.isEmpty { return }
        
        isAnalyzing = true
        
        Task {
            let metadata = await OCRService.analyzeImage(image)
            
            await MainActor.run {
                isAnalyzing = false
                
                if let data = metadata {
                    if let amt = data.totalAmount {
                        self.spendingAmount = String(format: "%.2f", abs(amt))
                    }
                    if let merch = data.merchant {
                        self.merchant = merch
                    }
                    if let dateStr = data.dateString {
                        self.date = dateStr.toDate()
                    }
                    
                    if let last4 = data.cardLast4 {
                        if let index = cards.firstIndex(where: { $0.endNum == last4 }) {
                            self.selectedCardIndex = index
                        }
                    }
                    
                    if let cat = data.category {
                        self.selectedCategory = cat
                    }
                    
                    // 识别币种并设置消费币种
                    if let currency = data.currency {
                        if let matchedRegion = Region.allCases.first(where: { $0.currencyCode == currency }) {
                            self.spendingCurrency = matchedRegion
                            self.location = matchedRegion
                        } else {
                            if currency.contains("CNY") { self.spendingCurrency = .cn; self.location = .cn }
                            else if currency.contains("USD") { self.spendingCurrency = .us; self.location = .us }
                            else if currency.contains("HKD") { self.spendingCurrency = .hk; self.location = .hk }
                            else if currency.contains("JPY") { self.spendingCurrency = .jp; self.location = .jp }
                            else if currency.contains("NZD") { self.spendingCurrency = .nz; self.location = .nz }
                            else if currency.contains("TWD") { self.spendingCurrency = .tw; self.location = .tw }
                            else { self.spendingCurrency = .other; self.location = .other }
                        }
                    }
                }
            }
        }
    }
    
    // --- 核心保存逻辑 ---
    func saveTransaction() {
        guard let amountDouble = Double(spendingAmount) else { return }
        let billingDouble = Double(billingAmountStr) ?? amountDouble
        
        if cards.indices.contains(selectedCardIndex) {
            let card = cards[selectedCardIndex]
            let imageData = receiptImage?.jpegData(compressionQuality: 0.5)
            
            // 检查是否为不计返现的交易类型
            let isNonCashbackTransaction = ["退款", "还款"].contains(paymentMethod)
            let isCreditTransaction = isNonCashbackTransaction
            
            let finalCashback: Double
            let nominalRate: Double
            
            if isNonCashbackTransaction {
                finalCashback = 0.0
                nominalRate = 0.0
            } else {
                finalCashback = card.calculateCappedCashback(
                    amount: billingDouble,
                    category: selectedCategory,
                    location: location,
                    date: date,
                    transactionToExclude: transactionToEdit
                )
                nominalRate = card.getRate(for: selectedCategory, location: location)
            }
            
            if let t = transactionToEdit {
                // --- 编辑模式 ---
                t.merchant = merchant
                t.spendingAmount = amountDouble
                t.location = location
                t.date = date
                t.paymentMethod = paymentMethod
                t.isOnlineShopping = isOnlineShopping
                t.isCBFApplied = isCBFApplied
                t.isCreditTransaction = isCreditTransaction
                t.spendingCurrency = spendingCurrency.currencyCode
                t.billingCurrency = card.issueRegion.currencyCode
                t.cbfAmount = cbfAmount
                
                if t.card != card || t.billingAmount != billingDouble || t.category != selectedCategory || t.date != date {
                    t.card = card
                    t.billingAmount = billingDouble
                    t.category = selectedCategory
                    t.rate = nominalRate
                    t.cashbackamount = finalCashback
                }
                
                if let img = imageData { t.receiptData = img }
                
            } else {
                // --- 新建模式 ---
                let newTransaction = Transaction(
                    merchant: merchant,
                    category: selectedCategory,
                    location: location,
                    spendingAmount: amountDouble,
                    date: date,
                    card: card,
                    paymentMethod: paymentMethod,
                    isOnlineShopping: isOnlineShopping,
                    isCBFApplied: isCBFApplied,
                    isCreditTransaction: isCreditTransaction,
                    receiptData: imageData,
                    billingAmount: billingDouble,
                    cashbackAmount: finalCashback,
                    cbfAmount: cbfAmount,
                    spendingCurrency: spendingCurrency.currencyCode,
                    billingCurrency: card.issueRegion.currencyCode
                )
                context.insert(newTransaction)
            }
            
            dismiss()
            onSaved?()
        }
    }
    
    func updateBillingAmount() {
        guard let amountDouble = Double(spendingAmount) else { return }

        guard cards.indices.contains(selectedCardIndex) else {
            billingAmountStr = spendingAmount
            return
        }

        let sourceCurrency = spendingCurrency.currencyCode
        let card = cards[selectedCardIndex]
        let targetCurrency = card.issueRegion.currencyCode
        
        if sourceCurrency == targetCurrency || sourceCurrency == "TWD" || sourceCurrency == "EUR" {
            billingAmountStr = spendingAmount
            return
        }
        
        guard transactionToEdit == nil else {
            return
        }

        Task {
            do {
                let rate = try await CurrencyService.fetchRate(from: sourceCurrency, to: targetCurrency)
                let billing = amountDouble * rate
                
                await MainActor.run {
                    self.billingAmountStr = String(format: "%.2f", billing)
                }
            } catch {
                print("汇率获取失败: \(error)")
            }
        }
    }
}
