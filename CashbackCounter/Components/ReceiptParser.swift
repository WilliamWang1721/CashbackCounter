//
//  AppleIntelligenceService.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/24/25.
//
import FoundationModels
import Observation // 苹果的新状态管理框架
import Foundation


@MainActor
@Observable
final class ReceiptParser {
    
    // 1. 这里的 session 定义和苹果一模一样
    private let instructions = Instructions{
        "You are an expert receipt data extractor."
        
        "Your job is to analyze the OCR text and extract key details into a structure."
        "CRITICAL RULES FOR MERCHANT NAME extraction:"
        "- You can use Chinese, Japanese, English to get the MERCHANT NAME"
        "- The MERCHANT NAME is usually at the top left corner."
        
        "CRITICAL RULES FOR AMOUNT extraction:"
        // 1. 告诉它找“实付”
        "- You must extract the FINAL PAID amount (实付金额/合计/Total)."
        // 2. 明确告诉它不要自己做加法，也不要拿原价
        "- If there are discounts (立减/优惠/Discount), DO NOT use the subtotal (原价/小计). Use the final amount AFTER discount."
        "- DO NOT add the discount to the total. DO NOT sum up numbers yourself."
        "- Usually is the biggest one"
        // 3. 给出关键词提示
        "- Look for keywords like:"
        "  - English: 'Total', 'Grand Total', 'Amount Due'"
        "  - Chinese: '实付', '已支付', '合计'"
        "  - Japanese: '合計', '合　計', 'お支払い', '請求金額', '税込'"
                
        "CRITICAL RULES FOR CATEGORIZATION:"
        "- Analyze the merchant name and items purchased."
        "- 'dining': Restaurants, Cafes, Starbucks, Izakaya (居酒屋), Ramen (ラーメン)." // 👈 新增：居酒屋/拉面
        "- 'grocery': Supermarkets, 7-Eleven, Lawson, FamilyMart, Daily necessities." // 👈 新增：日本常见便利店
        "- 'travel': Uber, Taxi, Flights, Hotels, Suica, Pasmo, Shinkansen (新幹線)." // 👈 新增：西瓜卡/新干线
        "- 'digital': Electronics, Apple Store, Yodobashi, Bic Camera." // 👈 新增：友都八喜/Bic Camera
        "- 'other': Anything that doesn't fit above."
        
        "Rules:"
        "- Extract exact values for merchant, amount, card ending number, merchant category, and date."
        "- Infer currency from symbols (¥, $, JPY) or location (e.g. Tokyo -> JPY)." // 👈 提示它根据东京推断日元
        "- If a value is missing, leave it nil."
    }
    private let SMSinstructions = Instructions{
        "You are an expert receipt data extractor."
        
        "Your job is to analyze the OCR text and extract key details into a structure."
        "If you are not sure about the result, return nil for the missing field."
        
        "CRITICAL RULES FOR MERCHANT NAME extraction:"
        "- You can use Chinese, Japanese, English to get the MERCHANT NAME"
        
        "CRITICAL RULES FOR AMOUNT extraction:"
        // 1. 告诉它找“实付”
        "- You must extract the FINAL PAID amount (实付金额/合计/Total)."
        
        "CRITICAL RULES FOR CATEGORIZATION:"
        "- Analyze the merchant name and items purchased."
        "- 'dining': Restaurants, Cafes, Starbucks, Izakaya (居酒屋), Ramen (ラーメン)." // 👈 新增：居酒屋/拉面
        "- 'grocery': Supermarkets, 7-Eleven, Lawson, FamilyMart, Daily necessities." // 👈 新增：日本常见便利店
        "- 'travel': Uber, Taxi, Flights, Hotels, Suica, Pasmo, Shinkansen (新幹線)." // 👈 新增：西瓜卡/新干线
        "- 'digital': Electronics, Apple Store, Yodobashi, Bic Camera." // 👈 新增：友都八喜/Bic Camera
        "- 'other': Anything that doesn't fit above."
    }
    
    init() {}
    
    // 3. 解析方法
    func parse(text: String) async throws -> ReceiptMetadata {
            
            // 👇👇👇 核心修改：每次调用 parse 时，创建一个全新的 session！
            // 这样每次都是“第一次”，没有历史包袱
            let session = LanguageModelSession(instructions: instructions)
            
            let response = try await session.respond(
                generating: ReceiptMetadata.self
            ) {
                "Analyze this receipt text:"
                text
            }
            
        return response.content
        }
    func SMSparse(text: String) async throws -> ReceiptMetadata {
            
            // 👇👇👇 核心修改：每次调用 parse 时，创建一个全新的 session！
            // 这样每次都是“第一次”，没有历史包袱
            let session = LanguageModelSession(instructions: SMSinstructions)
            
            let response = try await session.respond(
                generating: ReceiptMetadata.self
            ) {
                "Analyze this receipt text:"
                text
            }
            
        return response.content
        }
    
}
