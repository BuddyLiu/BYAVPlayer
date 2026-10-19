import AVFoundation
import SwiftUI

/// 主入口视图。
///
/// 零配置可用：`ConfigurableVideoPlayer(url: someURL)` 即可播放，主功能控件
/// （播放/暂停、时间显示、进度条、音量、全屏）默认开启；PiP、AirPlay、字幕、
/// 速率、Now Playing、循环、自定义 UI 默认关闭。
///
/// 生命周期说明：
/// - `AVPlayer` 在 `.task` 中延迟创建（自持模式），避免在 `init` 或视图刷新时
///   重复创建播放器。
/// - 视图消失时默认 `pause()` 并释放当前播放器（自持模式）。若希望跨页面继续
///   播放，请在外部持有 `PlayerState` 并通过 `init(state:configuration:)` 注入。
public struct ConfigurableVideoPlayer: View {

    /// 媒体 URL。
    public let url: URL
    /// 能力配置。
    public let configuration: PlayerConfiguration

    /// 外部注入的播放器状态；为 `nil` 时由视图自行创建。
    private let providedState: PlayerState?
    /// 本视图是否拥有该状态的生命周期（自持则负责暂停/释放）。
    private let ownsState: Bool

    @State private var state: PlayerState?
    @State private var isPresentingFullscreen = false

    private let renderPath: PlayerConfiguration.RenderPath

    // MARK: - 便捷初始化（自持模式）

    /// 创建一个播放器视图，内部延迟创建并持有 `AVPlayer`。
    public init(url: URL, configuration: PlayerConfiguration = .init()) {
        self.url = url
        self.configuration = configuration
        self.providedState = nil
        self.ownsState = true
        self.renderPath = RenderPathResolver.resolveWithValidation(configuration)
        PlayerBootstrap.bootstrap()
    }

    // MARK: - 注入模式（外部持有状态）

    /// 使用外部持有的 `PlayerState` 渲染播放器，适用于跨页面继续播放的场景。
    ///
    /// 外部持有模式下本视图不会在 `onDisappear` 时暂停或释放播放器，
    /// 生命周期由调用方负责（结束时调用 `state.tearDown()`）。
    public init(state: PlayerState, configuration: PlayerConfiguration = .init()) {
        self.url = state.url
        self.configuration = configuration
        self.providedState = state
        self.ownsState = false
        self.renderPath = RenderPathResolver.resolveWithValidation(configuration)
        _state = State(initialValue: state)
        PlayerBootstrap.bootstrap()
    }

    // MARK: - Body

    public var body: some View {
        Group {
            if let state {
                PlayerScene(
                    state: state,
                    configuration: configuration,
                    renderPath: renderPath,
                    isFullscreenPresentation: false,
                    onRequestFullscreen: { isPresentingFullscreen = true },
                    onExitFullscreen: {}
                )
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .task {
            guard state == nil, ownsState else { return }
            let newState = PlayerState(url: url, configuration: configuration, renderPath: renderPath)
            state = newState
        }
        .onDisappear {
            // 全屏弹层盖住当前视图时也会触发 onDisappear，此时不要暂停/释放。
            guard !isPresentingFullscreen else { return }
            if ownsState {
                state?.pause()
                state?.tearDown()
                state = nil
            }
        }
        .fullscreenPresentation(isPresented: $isPresentingFullscreen) {
            if let state {
                PlayerScene(
                    state: state,
                    configuration: configuration,
                    renderPath: renderPath,
                    isFullscreenPresentation: true,
                    onRequestFullscreen: {},
                    onExitFullscreen: { isPresentingFullscreen = false }
                )
                .ignoresSafeArea()
                #if os(iOS)
                .statusBarHidden(true)
                #endif
            }
        }
    }
}

// MARK: - 全屏呈现适配

@MainActor
extension View {

    /// 跨平台全屏呈现：
    /// - iOS / tvOS：`fullScreenCover`（真正的沉浸式全屏）。
    /// - macOS：`AVPlayerView` / `VideoPlayer` 等系统控件自带全屏入口，
    ///   这里用 `.sheet` 呈现“伪全屏”舞台，并依赖其中的退出按钮关闭。
    @ViewBuilder
    func fullscreenPresentation<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View where Content: View {
        #if os(iOS) || os(tvOS)
        fullScreenCover(isPresented: isPresented, content: content)
        #else
        sheet(isPresented: isPresented, content: content)
        #endif
    }
}