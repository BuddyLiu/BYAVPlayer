import AVFoundation
#if os(iOS) || os(tvOS)
import AVFAudio
#endif

/// 包级全局配置与音频会话管理。
///
/// 包内所有会产生 `AVPlayer` 的生命周期入口（`PlayerState` 初始化）都会先调用
/// `bootstrap()`，因此调用方无需记得设置 `AVPlayer.isObservationEnabled`。
public enum PlayerBootstrap {

    /// 幂等的全局初始化标记：模块首次访问 `bootstrap()` 时执行一次。
    private static let initialized: Void = {
        // 必须在任何 AVPlayer 创建之前开启，SwiftUI / 新式观察依赖该开关。
        // 注意：当前 SDK 将该属性标注为 iOS 26.0 / macOS 26.0 起可用，
        // 因此需要可用性守卫；更早的系统上 KVO 观察仍然可用，
        // 只是缺少增强观察能力（观察代码本身不受影响）。
        if #available(iOS 26.0, macOS 26.0, *) {
            AVPlayer.isObservationEnabled = true
        }
    }()

    /// 确保全局设置已应用。重复调用无副作用。
    public static func bootstrap() {
        _ = initialized
    }

    // MARK: - 音频会话

    /// 是否已完成音频会话类别配置。
    /// 标记为 `@MainActor`：Swift 6 严格并发下该可变全局状态必须限定隔离域，
    /// 且音频会话本就在主线程配置/访问。
    @MainActor private static var isAudioSessionConfigured = false

    /// 配置音频会话为 `.playback` / `.moviePlayback`（仅 iOS 有效，macOS 无此概念）。
    ///
    /// 注意：这里只设置类别，不调用 `setActive(true)`——激活推迟到真正开始播放时，
    /// 由 `activateAudioSessionForPlaybackIfNeeded()` 完成。
    @MainActor
    public static func configureAudioSessionForPlayback() {
        #if os(iOS) || os(tvOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback)
        isAudioSessionConfigured = true
        #endif
    }

    /// 在开始播放前激活音频会话。首次调用前若尚未配置类别则先配置。
    @MainActor
    static func activateAudioSessionForPlaybackIfNeeded() {
        #if os(iOS) || os(tvOS)
        if !isAudioSessionConfigured {
            configureAudioSessionForPlayback()
        }
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }
}