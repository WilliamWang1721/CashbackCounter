//
//  Transaction.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import SwiftUI
struct Transaction: Identifiable {
    let id = UUID()
    let merchant: String
    let category: String
    let amount: Double
    let cashbackRate: Double
    let date: String
    let color: Color
    
    var cashbackAmount: Double { amount * cashbackRate }
}
