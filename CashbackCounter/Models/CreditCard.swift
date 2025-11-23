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
}
