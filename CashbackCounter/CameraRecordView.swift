//
//  CameraRecordView.swift
//  CashbackCounter
//
//  Created by Junhao Huang on 11/23/25.
//

import SwiftUI

struct CameraRecordView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea() // 模拟相机取景器背景
            
            VStack {
                Spacer()
                Image(systemName: "viewfinder")
                    .font(.system(size: 100, weight: .ultraLight))
                    .foregroundColor(.white.opacity(0.5))
                
                Text("扫描小票或手动记账")
                    .foregroundColor(.white)
                    .padding(.top)
                Spacer()
                
                // 模拟拍照按钮
                Circle()
                    .strokeBorder(Color.white, lineWidth: 5)
                    .background(Circle().fill(Color.white))
                    .frame(width: 80, height: 80)
                    .padding(.bottom, 50)
            }
        }
    }
}
