import AVKit
import SwiftUI

/// `.systemViewController` 渲染路径：包装系统播放器控制器，
/// 保留系统控件，并让 PiP / AirPlay / 字幕 / 速率菜单由系统能力直接提供。
///
/// - iOS：包装 `AVPlayerViewController`。
/// - macOS：该平台没有 `AVPlayerViewController`，包装 `AVPlayerView`
///   （控件由 `controlsStyle` 决定）。
struct SystemViewControllerPlayer: View {
    let state: PlayerState
    let configuration: PlayerConfiguration

    var body: some View {
        SystemPlayerControllerRepresentable(state: state, configuration: configuration)
            .background(Color.black)
    }
}

#if os(iOS)

/// iOS 侧包装：`AVPlayerViewController`。
struct SystemPlayerControllerRepresentable: UIViewControllerRepresentable {

    let state: PlayerState
    let configuration: PlayerConfiguration

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = state.player
        apply(configuration, to: controller)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.player = state.player
        apply(configuration, to: controller)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    private func apply(_ configuration: PlayerConfiguration, to controller: AVPlayerViewController) {
        controller.videoGravity = .resizeAspect
        controller.showsPlaybackControls = configuration.showsPlaybackControls
        controller.allowsPictureInPicturePlayback = configuration.allowsPictureInPicture
        if #available(iOS 15.0, *) {
            controller.canStartPictureInPictureAutomaticallyFromInline = configuration.allowsPictureInPicture
        }
        // 明确设置 Now Playing 上报开关，避免隐式副作用。
        controller.updatesNowPlayingInfoCenter = configuration.updatesNowPlayingInfo
        if configuration.allowsPlaybackRate {
            controller.speeds = [0.5, 1.0, 1.5, 2.0, 3.0].map {
                AVPlaybackSpeed(rate: $0, localizedName: "\($0)x")
            }
        }
    }

    final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        func playerViewController(
            _ playerViewController: AVPlayerViewController,
            restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
        ) {
            // PiP 关闭后恢复内嵌 UI：封装层视图始终存在，直接确认即可。
            completionHandler(true)
        }
    }
}

#elseif os(macOS)

/// macOS 侧包装：`AVPlayerView`（该平台没有 `AVPlayerViewController`）。
struct SystemPlayerControllerRepresentable: NSViewRepresentable {

    let state: PlayerState
    let configuration: PlayerConfiguration

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = state.player
        apply(configuration, to: view)
        // 注意：PiP 恢复回调属于独立的 AVPlayerViewPictureInPictureDelegate 协议。
        view.pictureInPictureDelegate = context.coordinator
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        view.player = state.player
        apply(configuration, to: view)
        view.pictureInPictureDelegate = context.coordinator
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    private func apply(_ configuration: PlayerConfiguration, to view: AVPlayerView) {
        view.controlsStyle = configuration.showsPlaybackControls ? .floating : .none
        view.allowsPictureInPicturePlayback = configuration.allowsPictureInPicture
        if configuration.allowsPlaybackRate {
            if #available(macOS 13.0, *) {
                view.speeds = [0.5, 1.0, 1.5, 2.0, 3.0].map {
                    AVPlaybackSpeed(rate: $0, localizedName: "\($0)x")
                }
            }
        }
    }

    final class Coordinator: NSObject, AVPlayerViewPictureInPictureDelegate {
        func playerView(
            _ playerView: AVPlayerView,
            restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
        ) {
            // PiP 关闭后恢复内嵌 UI：封装层视图始终存在，直接确认即可。
            completionHandler(true)
        }
    }
}

#endif