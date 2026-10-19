import AVKit
import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// 可选功能控件行：PiP / AirPlay / 字幕 / 速率。
///
/// 仅在 `.customLayer` 路径下渲染，且相应能力开关开启时显示对应按钮；
/// 未开启的能力不会出现在 UI 中。
struct OptionalControlsView: View {

    @Bindable var state: PlayerState
    let configuration: PlayerConfiguration

    var body: some View {
        HStack(spacing: 10) {
            if configuration.allowsPictureInPicture, state.pictureInPictureController != nil {
                PictureInPictureButton(state: state)
            }
            if configuration.showsAirPlayButton {
                AirPlayButton()
            }
            if configuration.allowsSubtitles, !state.subtitles.isEmpty {
                SubtitleMenu(state: state)
            }
            if configuration.allowsPlaybackRate {
                RateMenu(state: state)
            }
        }
        .foregroundStyle(.white)
    }
}

// MARK: - PiP

private struct PictureInPictureButton: View {
    @Bindable var state: PlayerState

    var body: some View {
        if let controller = state.pictureInPictureController {
            Button(action: state.togglePictureInPicture) {
                Image(systemName: controller.isPictureInPictureActive
                      ? "rectangle.inset.filled.and.person.filled"
                      : "rectangle.on.rectangle")
                    .font(.system(size: 18))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            // 可用性由 isPictureInPicturePossible 驱动，而不是始终 enabled。
            .disabled(controller.isPictureInPictureActive
                      ? !controller.isPictureInPictureActive
                      : !controller.isPictureInPicturePossible)
        }
    }
}

// MARK: - AirPlay

private struct AirPlayButton: View {
    var body: some View {
        RoutePickerView()
            .frame(width: 44, height: 44)
    }
}

#if os(iOS)
struct RoutePickerView: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.tintColor = .white
        view.activeTintColor = UIColor.systemBlue
        return view
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
#elseif os(macOS)
struct RoutePickerView: NSViewRepresentable {
    func makeNSView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.isRoutePickerButtonBordered = false
        view.setRoutePickerButtonColor(.white, for: .normal)
        return view
    }
    func updateNSView(_ nsView: AVRoutePickerView, context: Context) {}
}
#endif

// MARK: - 字幕

private struct SubtitleMenu: View {
    @Bindable var state: PlayerState

    var body: some View {
        Menu {
            ForEach(state.subtitles) { option in
                Button {
                    state.selectSubtitle(option)
                } label: {
                    if option.isOffSelection {
                        if state.selectedSubtitleID == SubtitleOption.offID {
                            Label(option.title, systemImage: "checkmark")
                        } else {
                            Text(option.title)
                        }
                    } else {
                        if state.selectedSubtitleID == option.id {
                            Label(option.title, systemImage: "checkmark")
                        } else {
                            Text(option.title)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "captions.bubble")
                .font(.system(size: 18))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 速率

private struct RateMenu: View {
    @Bindable var state: PlayerState

    private static let rates: [Float] = [0.25, 0.5, 1.0, 1.5, 2.0, 3.0]

    var body: some View {
        Menu {
            ForEach(Self.rates, id: \.self) { rate in
                Button {
                    state.setPlaybackRate(rate)
                } label: {
                    if abs(state.playbackRate - rate) < 0.01 {
                        Label(Self.label(for: rate), systemImage: "checkmark")
                    } else {
                        Text(Self.label(for: rate))
                    }
                }
            }
        } label: {
            Text(Self.label(for: state.playbackRate))
                .font(.caption.monospacedDigit())
                .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
    }

    private static func label(for rate: Float) -> String {
        rate == 1.0 ? "1x" : String(format: "%gx", rate)
    }
}