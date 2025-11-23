//
//  CashbackCounterApp.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import SwiftUI

@main // 👈 1. 这里的 @main 就相当于 Java 的 public static void main()。
      // 它告诉系统：程序从这里开始跑！
struct CashbackCounterApp: App { // 2. 这个结构体必须遵守 App 协议
    // 1. 在这里创建仓库的唯一真身
    // @StateObject 保证了仓库即使 App 刷新也不会被销毁
    @StateObject var manager = DataManager()
    
    var body: some Scene {
        WindowGroup { // 3. 窗口组 (iOS 现在的 App 支持多窗口，比如 iPad 分屏)
            
            // 👇 4. 这里定义了 App 启动后显示的第一个画面！
            // 这就相当于 AndroidManifest 里配置了 <intent-filter> 的 Launcher Activity
            ContentView().environmentObject(manager)
        }
    }
}
