//
//  ContentView.swift
//  BYAVPlayerDemo
//
//  Created by bo.liu on 2026/10/19.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("BYAVPlayer 示例") {
                    NavigationLink("零配置播放") { ZeroConfigScreen() }
                    NavigationLink("全功能（PiP / AirPlay / 字幕 / 速率 / Now Playing / 循环）") { FullFeatureScreen() }
                    NavigationLink("自定义控件（customLayer 渲染）") { CustomControlsScreen() }
                    NavigationLink("跨页面继续播放（注入 PlayerState）") { CrossPageScreen() }
                }

                Section("说明") {
                    Text("所有 demos 均为 HTTPS 公开流，已在国内网络环境实测可达。")
                        .font(.footnote)
                    Text("零配置走 SwiftUI VideoPlayer；开启任何可选能力后自动切换到系统控制器路径；提供自定义控件后切换到 AVPlayerLayer 自定义路径。")
                        .font(.footnote)
                }
            }
            .navigationTitle("BYAVPlayerDemo")
        }
    }
}

#Preview {
    ContentView()
}