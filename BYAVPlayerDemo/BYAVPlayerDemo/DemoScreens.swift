//
//  DemoScreens.swift
//  BYAVPlayerDemo
//
//  Created by bo.liu on 2026/10/19.
//

import BYAVPlayer
import SwiftUI

// MARK: - 示例 1：零配置

/// 一行代码即可播放：主功能（播放/暂停、时间、进度条、音量、全屏）默认开启，
/// 渲染路径由封装自动选择（此处为最轻量的 SwiftUI VideoPlayer）。
struct ZeroConfigScreen: View {
    var body: some View {
        ConfigurableVideoPlayer(url: SampleMedia.mp4DomesticShort)
            .aspectRatio(16 / 9, contentMode: .fit)
            .navigationTitle("零配置播放")
    }
}

// MARK: - 示例 2：全功能

/// 开启全部可选能力：PiP、AirPlay、字幕、速率、Now Playing、循环。
/// 因为这些能力需要系统级控制器，即使不指定 `preferredRenderPath`，
/// 封装也会自动选择 `.systemViewController`（iOS：AVPlayerViewController；
/// macOS：AVPlayerView）。
struct FullFeatureScreen: View {

    private var configuration: PlayerConfiguration {
        var config = PlayerConfiguration()
        config.allowsPictureInPicture = true
        config.showsAirPlayButton = true
        config.allowsSubtitles = true
        config.allowsPlaybackRate = true
        config.updatesNowPlayingInfo = true
        config.loopsPlayback = true
        return config
    }

    var body: some View {
        ConfigurableVideoPlayer(url: SampleMedia.mp4DomesticShort, configuration: configuration)
            .aspectRatio(16 / 9, contentMode: .fit)
            .navigationTitle("全功能（HLS）")
    }
}

// MARK: - 示例 3：自定义渲染层 + 完全自定义控件

struct CustomControlsScreen: View {

    private var configuration: PlayerConfiguration {
        var config = PlayerConfiguration()
        // 提供后整体替换默认控件；渲染路径随之自动选择 `.customLayer`。
        config.customControls = { state in
            AnyView(CustomControls(state: state))
        }
        return config
    }

    var body: some View {
        ConfigurableVideoPlayer(url: SampleMedia.mp4DomesticShort, configuration: configuration)
            .aspectRatio(16 / 9, contentMode: .fit)
            .navigationTitle("自定义控件")
    }
}

/// 一份极简的自定义控件：点击画面显示/隐藏，倒带 + 播放暂停 + 快进 + 进度。
struct CustomControls: View {
    let state: PlayerState

    @State private var visible = true

    var body: some View {
        ZStack {
            // 透明点击层：切换控件显隐。用全尺寸 button 便于 UI 测试定位。
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { visible.toggle() }
            } label: {
                Color.clear
                    .contentShape(Rectangle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("custom-toggle")

            if visible {
                VStack {
                    Spacer()
                    HStack(spacing: 32) {
                        Button { state.seek(to: state.currentTime - 10) } label: {
                            Image(systemName: "gobackward.10")
                                .font(.title)
                        }
                        .accessibilityIdentifier("custom-back10")
                        Button { state.togglePlayPause() } label: {
                            Image(systemName: state.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 56))
                        }
                        .accessibilityIdentifier("custom-play-pause")
                        Button { state.seek(to: state.currentTime + 10) } label: {
                            Image(systemName: "goforward.10")
                                .font(.title)
                        }
                        .accessibilityIdentifier("custom-forward10")
                    }
                    .foregroundStyle(.white)

                    ProgressView(value: state.currentTime, total: max(state.duration, 0.001))
                        .tint(.white)
                        .padding(.horizontal, 16)

                    HStack {
                        Text(formatTime(state.currentTime))
                        Spacer()
                        Text(formatTime(state.duration))
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
            }
        }
    }
}

// MARK: - 示例 4：跨页面继续播放（注入 PlayerState）

/// 通过 `PlayerStore` 在外部持有 `PlayerState`，两个页面注入同一实例，
/// 页面切换不会暂停，播放进度无缝衔接。
struct CrossPageScreen: View {
    var body: some View {
        NavigationStack {
            PlayerPage(number: 1)
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Button("停止并释放") { PlayerStore.shared.release() }
                    }
                }
        }
    }
}

struct PlayerPage: View {
    let number: Int

    /// 每次 body 求值都返回同一个实例（幂等）。
    private var state: PlayerState {
        PlayerStore.shared.ensure(url: SampleMedia.mp4DomesticShort)
    }

    var body: some View {
        VStack(spacing: 12) {
            ConfigurableVideoPlayer(state: state)
                .aspectRatio(16 / 9, contentMode: .fit)

            Text("页面 \(number)：两页注入同一份 PlayerState，切换页面不中断播放")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if number == 1 {
                NavigationLink("前往第二页") { PlayerPage(number: 2) }
                    .buttonStyle(.borderedProminent)
            } else {
                Button("返回第一页") { dismiss() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal)
        .navigationTitle("跨页面播放")
    }

    @Environment(\.dismiss) private var dismiss
}

// MARK: - 工具

/// 毫米级格式化时长，与包内默认控件保持一致。
func formatTime(_ seconds: TimeInterval) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let total = Int(seconds.rounded())
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let secs = total % 60
    return hours > 0
        ? String(format: "%d:%02d:%02d", hours, minutes, secs)
        : String(format: "%d:%02d", minutes, secs)
}

#Preview("自定义控件") {
    CustomControlsScreen()
}
