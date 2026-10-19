import AVFoundation
import AVKit
import Foundation
import Observation
#if canImport(MediaPlayer)
import MediaPlayer
#endif

/// 一条可用的内嵌字幕（legible）轨道选项。
public struct SubtitleOption: Identifiable, Hashable, Sendable {
    /// “关闭字幕”这一特殊选项的固定 id。
    public static let offID = "byavplayer.subtitle.off"
    public static let off = SubtitleOption(id: offID, title: "关闭", isDefault: false)

    public let id: String
    public let title: String
    public let isDefault: Bool

    public init(id: String, title: String, isDefault: Bool) {
        self.id = id
        self.title = title
        self.isDefault = isDefault
    }

    /// 是否代表“关闭字幕”。
    public var isOffSelection: Bool { id == SubtitleOption.offID }
}

/// 播放器的公共可观察状态。
///
/// 该类型持有其生命周期内的 `AVPlayer` 与全部时间/状态观察者，
/// 并在主线程上更新。默认控件与自定义控件闭包共享同一份状态，
/// 保证播放、全屏、PiP 等操作不会出现状态分裂。
@MainActor
@Observable
public final class PlayerState {

    // MARK: - 公开状态

    /// 播放源。
    public let url: URL

    /// 播放器实例（循环播放时为内部 `AVQueuePlayer`）。
    public private(set) var player: AVPlayer

    /// 是否正在播放。
    public private(set) var isPlaying = false

    /// 是否处于缓冲（`waitingToPlayAtSpecifiedRate`）状态。
    public private(set) var isBuffering = false

    /// 当前播放时间（秒）。
    public private(set) var currentTime: TimeInterval = 0

    /// 总时长（秒）；直播流等未知时长时为 0。
    public private(set) var duration: TimeInterval = 0

    /// 当前播放速率。
    public private(set) var playbackRate: Float = 1

    /// 最后一次错误（如加载失败）。
    public private(set) var error: Error?

    /// 音量（0.0 – 1.0）。
    public var volume: Float = 1 {
        didSet { player.volume = volume }
    }

    /// 媒体内嵌字幕轨道列表（仅在 `allowsSubtitles` 开启时填充）。
    /// 列表首位恒为“关闭”选项。
    public private(set) var subtitles: [SubtitleOption] = []

    /// 当前选中的字幕选项 id。
    public private(set) var selectedSubtitleID: String?

    /// 画中画控制器（仅 `.customLayer` 路径且 `allowsPictureInPicture` 开启时创建）。
    /// `.systemViewController` 路径的 PiP 由系统控制器直接提供。
    public private(set) var pictureInPictureController: AVPictureInPictureController?

    // MARK: - 内部

    /// 自定义层渲染使用的 `AVPlayerLayer`（多次挂载时指向最后一次挂载的 layer）。
    @ObservationIgnored internal var playerLayer: AVPlayerLayer?

    /// 拖拽进度条期间置位，用于冻结 `currentTime` 的周期更新。
    @ObservationIgnored internal var isScrubbing = false

    @ObservationIgnored private let configuration: PlayerConfiguration
    @ObservationIgnored private var item: AVPlayerItem?
    @ObservationIgnored private var legibleGroup: AVMediaSelectionGroup?
    @ObservationIgnored private var looper: AVPlayerLooper?
    @ObservationIgnored private var periodicObserver: Any?
    @ObservationIgnored private var timeControlObservation: NSKeyValueObservation?
    @ObservationIgnored private var itemStatusObservation: NSKeyValueObservation?
    @ObservationIgnored private var durationObservation: NSKeyValueObservation?
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var didAttachLayerForPIP = false
    @ObservationIgnored private var isTornDown = false

    // MARK: - 初始化

    /// 创建一个播放状态模型并创建其内部的 `AVPlayer`。
    ///
    /// `ConfigurableVideoPlayer` 会在 `.task` 中延迟调用本方法，避免在视图
    /// `init` 或刷新时重复创建 `AVPlayer`。需要跨页面持有播放器的调用方可以
    /// 自行创建并持有本对象，再通过 `ConfigurableVideoPlayer.init(state:configuration:)`
    /// 注入。创建播放器前会先执行 `PlayerBootstrap.bootstrap()`。
    public convenience init(url: URL, configuration: PlayerConfiguration = .init()) {
        self.init(url: url,
                  configuration: configuration,
                  renderPath: RenderPathResolver.resolveWithValidation(configuration))
    }

    internal init(url: URL, configuration: PlayerConfiguration, renderPath: PlayerConfiguration.RenderPath) {
        PlayerBootstrap.bootstrap()
        self.url = url
        self.configuration = configuration
        _ = renderPath

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: [
            "duration", "tracks", "availableMediaCharacteristicsWithMediaSelectionOptions"
        ])

        if configuration.loopsPlayback {
            // 循环播放：使用 AVPlayerLooper + AVQueuePlayer，避免反复 seek。
            let queuePlayer = AVQueuePlayer()
            self.player = queuePlayer
            self.looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        } else {
            self.player = AVPlayer()
            self.player.replaceCurrentItem(with: item)
        }
        self.item = item
        self.player.volume = volume
        self.player.rate = 1

        installObservers(on: item)

        if configuration.allowsSubtitles {
            loadSubtitles(for: item)
        }
        if configuration.updatesNowPlayingInfo {
            configureNowPlayingCommands()
        }
    }

    // MARK: - 观察者

    private func installObservers(on item: AVPlayerItem) {
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        periodicObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self, !self.isScrubbing, !self.isTornDown else { return }
                let seconds = time.seconds
                if seconds.isFinite, seconds >= 0 {
                    self.currentTime = seconds
                }
                self.updateNowPlayingInfoIfNeeded()
            }
        }

        timeControlObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            Task { @MainActor [weak self] in
                guard let self, self.player === player else { return }
                switch player.timeControlStatus {
                case .playing:
                    self.isPlaying = true
                    self.isBuffering = false
                case .paused:
                    self.isPlaying = false
                    self.isBuffering = false
                case .waitingToPlayAtSpecifiedRate:
                    self.isBuffering = true
                @unknown default:
                    self.isBuffering = false
                }
            }
        }

        itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self, self.item === item else { return }
                switch item.status {
                case .readyToPlay:
                    self.error = nil
                    self.refreshDuration()
                case .failed:
                    self.error = item.error
                    self.isPlaying = false
                default:
                    break
                }
            }
        }

        durationObservation = item.observe(\.duration, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.refreshDuration()
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self,
                          let current = self.player.currentItem,
                          current === self.item,
                          !self.configuration.loopsPlayback else { return }
                    self.isPlaying = false
                }
            }
    }

    private func refreshDuration() {
        guard let current = player.currentItem?.duration,
              current.isNumeric, current.seconds.isFinite, current.seconds > 0 else { return }
        duration = current.seconds
    }

    // MARK: - 播放控制

    /// 开始播放（首次播放时激活音频会话）。
    public func play() {
        guard !isTornDown, error == nil else { return }
        PlayerBootstrap.activateAudioSessionForPlaybackIfNeeded()
        player.play()
    }

    /// 暂停播放。
    public func pause() {
        player.pause()
        isPlaying = false
    }

    /// 播放 / 暂停切换。
    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    /// 跳转到指定时间（秒）。
    public func seek(to seconds: TimeInterval) {
        guard let item, item.status == .readyToPlay, seconds.isFinite else { return }
        let target = CMTime(seconds: min(max(seconds, 0), max(duration, 0)),
                            preferredTimescale: 600)
        isScrubbing = true
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isScrubbing = false
            }
        }
    }

    // MARK: - 速率

    /// 设置播放速率（仅影响播放中的速率；暂停后再播放会保持该速率）。
    public func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        if #available(iOS 16.0, macOS 13.0, *) {
            player.defaultRate = rate
        }
        if isPlaying {
            player.rate = rate
        }
    }

    // MARK: - 字幕

    private func loadSubtitles(for item: AVPlayerItem) {
        Task { @MainActor [weak self] in
            guard let self, self.item === item, !self.isTornDown else { return }
            let group = try? await item.asset.loadMediaSelectionGroup(for: .legible)
            guard let group else { return }
            self.legibleGroup = group
            var options: [SubtitleOption] = [.off]
            for option in group.options where !option.displayName.isEmpty {
                options.append(SubtitleOption(id: option.displayName,
                                              title: option.displayName,
                                              isDefault: option === group.defaultOption))
            }
            self.subtitles = options
            // 默认选中组内默认字幕轨道；无则视为“关闭”。
            if let defaultID = options.first(where: \.isDefault)?.id {
                self.selectedSubtitleID = defaultID == SubtitleOption.offID ? SubtitleOption.offID : defaultID
            } else {
                self.selectedSubtitleID = SubtitleOption.offID
            }
        }
    }

    /// 选择字幕轨道（传入 `SubtitleOption.off` 或 `isOffSelection == true` 表示关闭）。
    public func selectSubtitle(_ option: SubtitleOption) {
        guard let item, let group = legibleGroup else { return }
        selectedSubtitleID = option.id
        if option.isOffSelection {
            item.select(nil, in: group)
        } else if let matching = group.options.first(where: { $0.displayName == option.id }) {
            item.select(matching, in: group)
        }
    }

    // MARK: - 画中画（customLayer 路径）

    /// 由自定义层的 representable 在视图挂载时调用，绑定 `AVPlayerLayer`；
    /// 如配置允许 PiP 且系统支持，则创建一次 `AVPictureInPictureController`。
    internal func attach(playerLayer: AVPlayerLayer) {
        self.playerLayer = playerLayer
        playerLayer.player = player
        guard configuration.allowsPictureInPicture, !didAttachLayerForPIP else { return }
        didAttachLayerForPIP = true
        if AVPictureInPictureController.isPictureInPictureSupported() {
            pictureInPictureController = AVPictureInPictureController(playerLayer: playerLayer)
        }
    }

    /// 卸载自定义层（视图移除、全屏退出等场景）。
    internal func detach(playerLayer: AVPlayerLayer) {
        if self.playerLayer === playerLayer {
            self.playerLayer = nil
        }
        playerLayer.player = nil
    }

    /// 切换画中画（仅当控制器存在且系统支持时有效）。
    public func togglePictureInPicture() {
        guard let controller = pictureInPictureController else { return }
        if controller.isPictureInPictureActive {
            controller.stopPictureInPicture()
        } else {
            controller.startPictureInPicture()
        }
    }

    // MARK: - Now Playing（iOS）

    private func configureNowPlayingCommands() {
        #if canImport(MediaPlayer)
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.play() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.togglePlayPause() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let seconds = positionEvent.positionTime
            Task { @MainActor [weak self] in self?.seek(to: seconds) }
            return .success
        }
        #endif
    }

    private func updateNowPlayingInfoIfNeeded() {
        #if canImport(MediaPlayer)
        guard configuration.updatesNowPlayingInfo && isTornDown == false else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: url.lastPathComponent,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(playbackRate) : 0
        ]
        #endif
    }

    private func deconfigureNowPlayingCommands() {
        #if canImport(MediaPlayer)
        guard configuration.updatesNowPlayingInfo else { return }
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.togglePlayPauseCommand.removeTarget(nil)
        center.changePlaybackPositionCommand.removeTarget(nil)
        #endif
    }

    // MARK: - 生命周期

    /// 停止播放并清理所有观察者。
    ///
    /// 由持有方调用：`ConfigurableVideoPlayer` 在视图 `onDisappear`（自持模式下）
    /// 调用；外部持有的调用方应在不再需要播放器时手动调用。
    public func tearDown() {
        guard !isTornDown else { return }
        isTornDown = true
        pause()
        if let periodicObserver {
            player.removeTimeObserver(periodicObserver)
        }
        periodicObserver = nil
        timeControlObservation = nil
        itemStatusObservation = nil
        durationObservation = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
        deconfigureNowPlayingCommands()
        pictureInPictureController = nil
        looper = nil
        player.replaceCurrentItem(with: nil)
    }

    deinit {
        // 不在此处访问任何 MainActor 隔离的可变状态；观察者清理统一走 tearDown。
    }
}