import SwiftUI

/// 播放器配置模型。
///
/// 所有能力开关的默认值严格符合“主功能开启、其他关闭”的约定：
/// `shows*` / `allows*` 一类主功能默认 `true`，可选功能默认 `false`；
/// 不开启的能力不产生运行时代价，也不会出现在 UI 中。
///
/// - Note: 该类型被标记为 `@unchecked Sendable`。原因是 `customControls` /
///   `customOverlay` 是 `@MainActor` 隔离的视图构造闭包（`(PlayerState) -> AnyView`），
///   而 `PlayerState` 是 `@Observable` 对象、并非 `Sendable`。
///   `@MainActor` 隔离的函数类型本身隐式满足 `Sendable`，因此该结构体可以被安全地
///   跨隔离域传递——只要保证闭包只会在主线程被调用。包内所有读取配置的代码路径
///   都在主线程（视图与播放器均运行在 `@MainActor`）上，故此处采用 `@unchecked`
///   而非常规 `Sendable` 约束。
public struct PlayerConfiguration: @unchecked Sendable {

    // MARK: - 主功能（默认开启）

    /// 是否显示播放/暂停等核心控制。
    public var showsPlaybackControls: Bool = true

    /// 是否显示当前时间 / 总时长标签。
    public var showsTimeDisplay: Bool = true

    /// 是否显示可拖拽的进度条。
    public var showsProgressSlider: Bool = true

    /// 是否显示音量控制。
    public var showsVolumeControl: Bool = true

    /// 是否允许进入全屏（显示全屏按钮）。
    public var allowsFullscreen: Bool = true

    // MARK: - 可选功能（默认关闭）

    /// 是否允许画中画（PiP）。
    public var allowsPictureInPicture: Bool = false

    /// 是否显示 AirPlay 投屏按钮。
    public var showsAirPlayButton: Bool = false

    /// 是否启用在媒体内加载并选择字幕（legible）轨道。
    public var allowsSubtitles: Bool = false

    /// 是否允许切换播放速率。
    public var allowsPlaybackRate: Bool = false

    /// 是否上报 Now Playing / 锁屏控制信息（仅 iOS 生效）。
    public var updatesNowPlayingInfo: Bool = false

    /// 是否循环播放（使用 `AVPlayerLooper` + `AVQueuePlayer`）。
    public var loopsPlayback: Bool = false

    // MARK: - 渲染路径偏好

    /// 期望的渲染路径。`nil` 表示由封装自动选择；
    /// 提供时会作为最终路径（除非与已开启能力不兼容，见 `RenderPathResolver`）。
    public var preferredRenderPath: RenderPath? = nil

    // MARK: - 自定义 UI

    /// 自定义覆盖层：叠加在视频层之上、默认控件之下。
    /// 一旦提供，会在覆盖层上方继续渲染默认控件（除非同时提供了 `customControls`）。
    public var customOverlay: (@MainActor (PlayerState) -> AnyView)? = nil

    /// 自定义控件：提供后**整体替换**默认控件。
    /// 闭包接收完整的 `PlayerState`，用于构建与控制状态绑定的 UI。
    public var customControls: (@MainActor (PlayerState) -> AnyView)? = nil

    public init() {}

    /// 可用的渲染路径。
    public enum RenderPath: Sendable, Hashable {
        /// 系统 SwiftUI `VideoPlayer`，最轻量。
        case videoPlayer
        /// `AVPlayerViewController` 包装，保留系统控件与 PiP / AirPlay 能力。
        case systemViewController
        /// `AVPlayerLayer`，完全自定义 UI。
        case customLayer
    }

    /// 是否启用了任何需要系统级（`AVPlayerViewController`）能力的可选功能。
    @inlinable internal var requiresViewControllerCapabilities: Bool {
        allowsPictureInPicture || showsAirPlayButton || allowsSubtitles || allowsPlaybackRate
    }

    /// 是否提供了任何自定义 UI（覆盖层或控件）。
    @inlinable internal var hasCustomUI: Bool {
        customControls != nil || customOverlay != nil
    }
}