import SwiftUI

/// 播放器场景：给定同一个 `PlayerState` 与渲染路径，决定当前舞台由哪套视图构成。
///
/// 内联与全屏共用同一份 `state` / `player`，全屏只是在 `fullScreenCover`
/// 中再次实例化 `PlayerScene`——不会创建第二个 `AVPlayer`，也就不会出现
/// 音频中断或状态分裂。
struct PlayerScene: View {

    @Bindable var state: PlayerState
    let configuration: PlayerConfiguration
    let renderPath: PlayerConfiguration.RenderPath
    var isFullscreenPresentation: Bool
    var onRequestFullscreen: () -> Void
    var onExitFullscreen: () -> Void

    var body: some View {
        ZStack {
            videoContent

            // 自定义覆盖层：叠在视频层之上、默认控件之下。
            if let overlay = configuration.customOverlay {
                overlay(state)
            }

            // 自定义控件整体替换默认控件。
            if let customControls = configuration.customControls {
                customControls(state)
            } else if configuration.showsPlaybackControls, renderPath == .customLayer {
                DefaultControlsView(
                    state: state,
                    configuration: configuration,
                    isFullscreenPresentation: isFullscreenPresentation,
                    onRequestFullscreen: onRequestFullscreen,
                    onExitFullscreen: onExitFullscreen
                )
            }
        }
        .clipped()
    }

    @ViewBuilder
    private var videoContent: some View {
        switch renderPath {
        case .videoPlayer:
            SystemVideoPlayer(state: state)
        case .systemViewController:
            SystemViewControllerPlayer(state: state, configuration: configuration)
        case .customLayer:
            CustomLayerPlayer(state: state)
        }
    }
}