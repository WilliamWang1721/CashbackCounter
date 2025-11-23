//
//  CashbackCounterApp.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import SwiftUI
import SwiftData

@main // 👈 1. 这里的 @main 就相当于 Java 的 public static void main()。
      // 它告诉系统：程序从这里开始跑！
struct CashbackCounterApp: App { // 2. 这个结构体必须遵守 App 协议
    // 1. 在这里创建仓库的唯一真身
    // @StateObject 保证了仓库即使 App 刷新也不会被销毁
    @StateObject var manager = DataManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(manager)
        }
        .modelContainer(for: Transaction.self)
    }
}
