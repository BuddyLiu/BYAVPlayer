import SwiftUI
#if canImport(MediaPlayer)
import MediaPlayer
#endif
#if os(iOS)
import UIKit
#endif

/// 默认控件：主功能（播放/暂停、时间显示、进度条、音量、全屏）+ 可选功能条件渲染。
///
/// 仅在 `.customLayer` 路径、且配置未提供 `customControls` 时渲染。
/// 点击视频区可切换播放/暂停；缓冲时显示 spinner。
struct DefaultControlsView: View {

    @Bindable var state: PlayerState
    let configuration: PlayerConfiguration
    let isFullscreenPresentation: Bool
    let onRequestFullscreen: () -> Void
    let onExitFullscreen: () -> Void

    /// 拖拽进度条期间的用户输入值。
    @State private var scrubValue: Double?

    var body: some View {
        ZStack {
            // 视频区点击切换播放/暂停
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { state.togglePlayPause() }

            // 缓冲指示
            if state.isBuffering && !state.isPlaying {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            }

            // 暂停时的大播放按钮
            if !state.isPlaying {
                Button {
                    state.play()
                } label: {
                    Image(systemName: "play.circle.fill")
                        .resizable()
                        .frame(width: 64, height: 64)
                }
                .buttonStyle(.plain)
                .shadow(radius: 4)
            }

            bottomBar
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
        .foregroundStyle(.white)
    }

    // MARK: - 顶层控件行

    private var bottomBar: some View {
        VStack(spacing: 0) {
            // 可选功能行（PiP / AirPlay / 字幕 / 速率）
            if hasOptionalControls {
                HStack {
                    Spacer()
                    OptionalControlsView(state: state, configuration: configuration)
                }
                .padding(.bottom, 4)
            }

            HStack(spacing: 12) {
                // 播放/暂停
                Button {
                    state.togglePlayPause()
                } label: {
                    Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)

                // 时间显示
                if configuration.showsTimeDisplay {
                    Text("\(format(time: state.currentTime)) / \(format(time: state.duration))")
                        .font(.caption.monospacedDigit())
                        .lineLimit(1)
                }

                // 进度条
                if configuration.showsProgressSlider, state.duration > 0 {
                    slider
                }

                // 音量（iOS 用系统 MPVolumeView，macOS 用滑块）
                if configuration.showsVolumeControl {
                    volumeControl
                }

                Spacer(minLength: 0)

                // 全屏入口/退出
                if isFullscreenPresentation {
                    Button {
                        onExitFullscreen()
                    } label: {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 20))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                } else if configuration.allowsFullscreen {
                    Button {
                        onRequestFullscreen()
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 20))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var hasOptionalControls: Bool {
        (configuration.allowsPictureInPicture && state.pictureInPictureController != nil)
            || configuration.showsAirPlayButton
            || (configuration.allowsSubtitles && !state.subtitles.isEmpty)
            || configuration.allowsPlaybackRate
    }

    // MARK: - 进度条

    private var slider: some View {
        let bounds = 0.0...max(state.duration, 0.01)
        return Slider(
            value: Binding(
                get: { scrubValue ?? min(state.currentTime, state.duration) },
                set: { newValue in
                    scrubValue = newValue
                    state.isScrubbing = true
                }
            ),
            in: bounds,
            onEditingChanged: { editing in
                if !editing {
                    if let value = scrubValue {
                        state.seek(to: value)
                    }
                    scrubValue = nil
                    state.isScrubbing = false
                }
            }
        )
        .tint(.white)
        .frame(minWidth: 120, maxWidth: 480)
    }

    // MARK: - 音量

    @ViewBuilder
    private var volumeControl: some View {
        #if os(iOS)
        SystemVolumeView()
            .frame(width: 110, height: 26)
        #else
        HStack(spacing: 4) {
            Image(systemName: "speaker.fill")
                .font(.caption)
            Slider(value: $state.volume, in: 0...1)
                .tint(.white)
                .frame(width: 90)
        }
        #endif
    }

    // MARK: - 工具

    private func format(time: TimeInterval) -> String {
        guard time.isFinite, time >= 0 else { return "0:00" }
        let total = Int(time.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }
}

#if os(iOS)
/// iOS 系统音量滑块（MPVolumeView）。
struct SystemVolumeView: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView()
        // showsRouteButton 自 iOS 13 起弃用且为 no-op；路由按钮由
        // OptionalControlsView 中的 AVRoutePickerView 另行提供。
        view.showsVolumeSlider = true
        view.tintColor = .white
        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {
        uiView.tintColor = .white
    }
}
#endif