# 角色

你是一名资深的 SwiftUI / AVFoundation 工程师，擅长构建可配置、可测试、对调用方友好的播放器封装组件。你熟悉 AVKit 的三种渲染路径（VideoPlayer、AVPlayerViewController、AVPlayerLayer）及其能力边界，也熟悉 Swift 6 并发和 SwiftUI 的 Observation 机制。

# 任务

在新建的 Swift Package 中，实现一个 SwiftUI AVPlayer 封装包，名称为 `ConfigurablePlayer`。对外只暴露一个主入口视图 `ConfigurableVideoPlayer` 和一个配置模型 `PlayerConfiguration`。调用方通过配置按需开启能力，不开启的能力不产生运行时代价，也不出现在 UI 中。

# 硬性要求

1. **主功能默认开启**：播放/暂停、时间显示、进度条、音量、全屏。
2. **其他功能默认关闭**：PiP、AirPlay 按钮、字幕选择、播放速率、Now Playing / 锁屏控制、循环播放、帧访问、自定义 UI 覆盖。
3. 所有可选功能必须通过 `PlayerConfiguration` 中的选项开启，不得依赖全局单例或隐式环境值。
4. 如果调用方不提供任何自定义 UI，播放器必须**立即可用**——即“零配置可用，全默认已开”。
5. 如果调用方提供了自定义 UI，默认控件必须可以被整体替换，而不是在默认控件上打补丁。
6. 不得使用第三方依赖。
7. 目标平台：iOS 17+ / macOS 14+（如某些 API 仅 iOS 可用，用 `#if os(iOS)` 条件编译，并在文档中注明）。

# 架构

## 1. 配置模型

定义 `PlayerConfiguration`，它是一个值类型 `struct`，所有能力以 `Bool` 或可选配置对象表达，**默认值必须严格符合“主功能开启、其他关闭”的约定**。

```swift
public struct PlayerConfiguration: Sendable {

    // 主功能：默认 true
    public var showsPlaybackControls: Bool = true
    public var showsTimeDisplay: Bool = true
    public var showsProgressSlider: Bool = true
    public var showsVolumeControl: Bool = true
    public var allowsFullscreen: Bool = true

    // 可选功能：默认 false
    public var allowsPictureInPicture: Bool = false
    public var showsAirPlayButton: Bool = false
    public var allowsSubtitles: Bool = false
    public var allowsPlaybackRate: Bool = false
    public var updatesNowPlayingInfo: Bool = false
    public var loopsPlayback: Bool = false

    // 渲染路径偏好：nil 表示由封装自动选择
    public var preferredRenderPath: RenderPath? = nil

    // 自定义 UI 入口
    public var customOverlay: (@MainActor @Sendable () -> AnyView)? = nil
    public var customControls: (@MainActor @Sendable () -> AnyView)? = nil

    public init() {}

    public enum RenderPath: Sendable {
        case videoPlayer        // 系统 SwiftUI VideoPlayer，最轻量
        case systemViewController // AVPlayerViewController 包装，保留系统控件 + PiP/AirPlay
        case customLayer        // AVPlayerLayer，完全自定义 UI
    }
}
```

如果 Swift 的 `Sendable` 与闭包类型冲突，将闭包属性标注为 `@MainActor` 并把整个配置改为 `@unchecked Sendable` 是可以接受的；但必须在注释中说明原因。

## 2. 渲染路径自动选择

实现一个内部决策函数，根据配置推导最终渲染路径，优先级如下：

```
如果 preferredRenderPath != nil，使用指定路径
否则如果 customControls != nil 或 customOverlay != nil → .customLayer
否则如果 allowsPictureInPicture 或 showsAirPlayButton 或 allowsSubtitles 或 allowsPlaybackRate → .systemViewController
否则 → .videoPlayer
```

如果调用方显式指定了 `preferredRenderPath`，但该路径与某些已开启能力不兼容（例如选择 `.videoPlayer` 但开启了 PiP），在初始化时触发 `assertionFailure` 并在 Debug 下打印明确说明；Release 下静默回退到兼容路径，但通过日志警告。

## 3. 视图层

`ConfigurableVideoPlayer` 是一个 `View`，签名大致如下：

```swift
public struct ConfigurableVideoPlayer: View {
    public init(
        url: URL,
        configuration: PlayerConfiguration = .init()
    )
}
```

内部行为：

- 用 `.task` 延迟创建 `AVPlayer`，避免在 `init` 中创建，也避免在视图刷新时重复创建。
- 根据决策出的渲染路径，切换到 `SystemVideoPlayer` / `SystemViewControllerPlayer` / `CustomLayerPlayer` 三个内部视图之一。
- 如果 `customControls` 有值，用 `ZStack` 把自定义控件叠在视频层之上；默认控件不渲染。如果 `customOverlay` 有值，叠在视频层与控件层之间。
- 公共状态（`isPlaying`、`currentTime`、`duration`、`isBuffering`、`error`）由内部 `@Observable` 模型持有，并通过环境或初始化参数传给自定义控件闭包。自定义控件闭包的签名建议为 `(PlayerState) -> AnyView`，而不是无参闭包。

## 4. 能力实现要点

### 播放控制与状态

- `AVPlayer.isObservationEnabled = true` 必须在**创建任何 AVPlayer 之前**设置，建议放在包内一个 `PlayerBootstrap` 的 `static let` 或 `App` 初始化中，并提供 `public static func bootstrap()` 供调用方在 `@main` 中调用。
- 用 `player.timeControlStatus` 驱动缓冲指示器，`.waitingToPlayAtSpecifiedRate` 时显示 spinner。
- 用 `addPeriodicTimeObserver` 驱动进度条和时间标签，间隔 0.1–0.5 秒，回调队列使用 `.main`；在视图 `onDisappear` 或模型销毁时移除观察者。
- 播放结束监听 `.AVPlayerItemDidPlayToEndTime`；如果 `loopsPlayback == true`，使用 `AVPlayerLooper`（配合 `AVQueuePlayer`），而不是反复 seek。

### 全屏

- 全屏使用 `.fullScreenCover` 呈现同一个播放器实例的另一个视图，**不要**创建第二个 `AVPlayer`，否则会出现音频中断和状态分裂。
- 全屏入口按钮仅在 `allowsFullscreen == true` 时出现。

### PiP（可选，默认关闭）

- `.systemViewController` 路径：设置 `allowsPictureInPicturePlayback = true`、`canStartPictureInPictureAutomaticallyFromInline = true`，并实现 `AVPlayerViewControllerDelegate` 的 `restoreUserInterfaceForPictureInPictureStopWithCompletionHandler`，调用 `completionHandler(true)`。
- `.customLayer` 路径：使用 `AVPictureInPictureController(playerLayer:)`，仅在 `isPictureInPictureSupported()` 为真时创建；PiP 按钮的可用性由 `isPictureInPicturePossible` 驱动，而不是始终 enabled。
- `.videoPlayer` 路径不支持 PiP；如果调用方在 `.videoPlayer` 下开启 PiP，按上文回退策略处理。

### AirPlay（可选，默认关闭）

- `.systemViewController` 路径：系统控件会自动出现 AirPlay 按钮；`showsAirPlayButton` 为 `false` 时不额外添加。
- `.customLayer` 路径：用 `AVRoutePickerView` 包装一个 SwiftUI 按钮，仅在 `showsAirPlayButton == true` 时出现在自定义控件中。
- `player.allowsExternalPlayback` 保持默认 `true`。

### 字幕（可选，默认关闭）

- `allowsSubtitles == true` 时，从 `player.currentItem?.asset` 读取 `AVMediaCharacteristic.legible` 的媒体选择组，暴露一个 `subtitles: [SubtitleOption]` 和 `selectSubtitle(_:)` 方法。
- `.systemViewController` 路径下，系统控件本身提供字幕切换入口；封装层只需确保媒体选择没有被禁用。
- `.customLayer` 路径下，需要在自定义控件中渲染一个字幕选择菜单。不要自行解析 SRT/WebVTT；只处理媒体内嵌的 legible 轨道。如果调用方需要外挂字幕，在文档中明确说明当前版本不支持，并给出扩展点。

### 播放速率（可选，默认关闭）

- `.systemViewController` 路径：设置 `playerVC.speeds` 为常用速率数组（0.5、1.0、1.5、2.0），系统控件会出现速率菜单。
- `.customLayer` 路径：通过 `player.rate` 控制，自定义控件中提供一个 `Menu` 或 `Picker`。
- 速率变更时更新 `PlayerState.playbackRate`，并通过 `effectivePlaybackSpeed` 或 KVO 同步。

### Now Playing / 锁屏控制（可选，默认关闭）

- `updatesNowPlayingInfo == true` 时：
  - `.systemViewController` 路径保持 `updatesNowPlayingInfoCenter = true`。
  - `.customLayer` 路径手动配置 `MPNowPlayingInfoCenter` 和 `MPRemoteCommandCenter`，至少处理 play、pause、toggle、changePlaybackPosition 四个命令。
- `updatesNowPlayingInfo == false` 时，`.systemViewController` 路径必须显式设置 `updatesNowPlayingInfoCenter = false`，避免隐式副作用。

### 帧访问（可选，默认关闭，不暴露在默认 UI 中）

- 提供 `playerItemVideoOutput` 的可选挂载点，但不在默认控件中出现任何入口。如果 `configuration` 中没有对应开关，不创建 `AVPlayerItemVideoOutput`。
- 如果调用方需要帧访问，通过一个单独的 `FrameAccessProviding` 协议或回调暴露，而不是塞进主视图。

## 5. 音频会话与生命周期

- 提供一个 `public static func configureAudioSessionForPlayback()`，设置 `.playback` / `.moviePlayback`，但**不要**在 `setCategory` 后立刻 `setActive(true)`；推迟到真正开始播放时激活。
- 在 `ConfigurableVideoPlayer` 的 `onDisappear` 中调用 `pause()`；如果调用方希望跨页面继续播放，应在文档中说明需要将 `AVPlayer` 提升到视图外部持有，并提供 `PlayerStore` 或类似的外部持有示例。
- 包内不得在 `deinit` 中执行需要主线程的 UI 操作。

## 6. 文件结构

```
Sources/ConfigurablePlayer/
├── ConfigurablePlayer.swift          // 主视图
├── PlayerConfiguration.swift         // 配置模型
├── PlayerState.swift                 // @Observable 状态模型
├── RenderPathResolver.swift          // 路径决策
├── Internal/
│   ├── SystemVideoPlayer.swift       // VideoPlayer 路径
│   ├── SystemViewControllerPlayer.swift // AVPlayerViewController 包装
│   ├── CustomLayerPlayer.swift       // AVPlayerLayer 包装
│   ├── DefaultControlsView.swift     // 默认控件（主功能）
│   ├── OptionalControlsView.swift    // PiP/AirPlay/字幕/速率控件（条件渲染）
│   └── PlayerBootstrap.swift         // isObservationEnabled 等全局设置
└── Documentation.docc/               // 至少包含 README 和默认值表
```

## 7. 测试要求

- 为 `RenderPathResolver` 写单元测试，覆盖“主功能默认开启”和“可选功能默认关闭”的默认配置，以及各种开关组合下的路径选择。
- 为 `PlayerConfiguration` 写测试，断言默认值严格匹配约定。
- 至少提供一个 SwiftUI Preview，展示零配置可用状态，和一个“全功能开启”状态。

## 8. 文档要求

在 `README.md` 中包含：

- 一句话定位。
- 零配置示例（只有 `url`）。
- 开启 PiP + AirPlay 的示例。
- 自定义控件的示例（闭包签名和状态获取方式）。
- 一张**默认值表**，逐项列出主功能和可选功能及其默认状态。
- 已知限制（例如 `.videoPlayer` 路径不支持 PiP、外挂字幕不支持、macOS 上 PiP 的可用性差异等）。

# 执行步骤

1. 先用 `swift package init --type library` 创建包骨架。
2. 先实现 `PlayerConfiguration` 和 `RenderPathResolver` 及其测试，确保默认值契约在最早阶段被锁定。
3. 实现 `PlayerState` 和 `PlayerBootstrap`。
4. 按路径分别实现三个内部视图，优先完成 `.systemViewController` 路径（主功能 + PiP/AirPlay/字幕/速率的系统能力最容易验证），再完成 `.customLayer` 路径，最后完成 `.videoPlayer` 轻量路径。
5. 实现默认控件和可选控件的条件渲染。
6. 编写 Preview 和 README。
7. 运行 `swift test`，确保默认值测试全部通过；在 Xcode 中确认零配置 Preview 可播放，并逐项手动验证每个可选功能在开启和关闭两种状态下的行为差异。

# 验收标准

- [ ] `ConfigurableVideoPlayer(url:)` 零配置即可播放，主功能控件可见可用。
- [ ] PiP、AirPlay、字幕、速率、Now Playing、循环在零配置下均不出现、不产生额外对象。
- [ ] 每个可选功能开启后，在不支持的路径上会明确回退或报错，而不是静默失效。
- [ ] `customControls` 一旦提供，默认控件完全消失，自定义控件能拿到完整的 `PlayerState`。
- [ ] 全屏不会创建第二个 `AVPlayer`。
- [ ] 周期时间观察者在视图消失时被移除。
- [ ] `AVPlayer.isObservationEnabled` 在创建播放器之前设置，且不依赖调用方记得设置。