import AVFoundation
import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// `.customLayer` 渲染路径：把 `AVPlayerLayer` 嵌入 SwiftUI，配合默认/自定义控件使用。
///
/// 自定义层完全由封装控制：默认控件、PiP 按钮、AirPlay 按钮、字幕/速率菜单、
/// 全屏都由本包渲染（见 `DefaultControlsView` / `OptionalControlsView`）。
struct CustomLayerPlayer: View {
    let state: PlayerState

    var body: some View {
        PlayerLayerView(state: state)
            .background(Color.black)
    }
}

#if os(iOS)

/// 承载 `AVPlayerLayer` 的容器视图。
final class PlayerLayerUIView: UIView {
    private let playerLayer = AVPlayerLayer()
    private weak var attachedState: PlayerState?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        playerLayer.videoGravity = .resizeAspect
        layer.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        CATransaction.commit()
    }

    func attach(_ state: PlayerState) {
        attachedState = state
        state.attach(playerLayer: playerLayer)
    }

    func detach() {
        attachedState?.detach(playerLayer: playerLayer)
        attachedState = nil
    }
}

struct PlayerLayerView: UIViewRepresentable {
    let state: PlayerState

    func makeUIView(context: Context) -> PlayerLayerUIView {
        let view = PlayerLayerUIView()
        view.attach(state)
        return view
    }

    func updateUIView(_ uiView: PlayerLayerUIView, context: Context) {
        uiView.attach(state)
    }

    static func dismantleUIView(_ uiView: PlayerLayerUIView, coordinator: ()) {
        uiView.detach()
    }
}

#elseif os(macOS)

/// 承载 `AVPlayerLayer` 的容器视图。
final class PlayerLayerNSView: NSView {
    private let playerLayer = AVPlayerLayer()
    private weak var attachedState: PlayerState?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        playerLayer.videoGravity = .resizeAspect
        layer?.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        CATransaction.commit()
    }

    func attach(_ state: PlayerState) {
        attachedState = state
        state.attach(playerLayer: playerLayer)
    }

    func detach() {
        attachedState?.detach(playerLayer: playerLayer)
        attachedState = nil
    }
}

struct PlayerLayerView: NSViewRepresentable {
    let state: PlayerState

    func makeNSView(context: Context) -> PlayerLayerNSView {
        let view = PlayerLayerNSView()
        view.attach(state)
        return view
    }

    func updateNSView(_ nsView: PlayerLayerNSView, context: Context) {
        nsView.attach(state)
    }

    static func dismantleNSView(_ nsView: PlayerLayerNSView, coordinator: ()) {
        nsView.detach()
    }
}

#endif