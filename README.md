# BYAVPlayer

一个零依赖、可配置、对调用方友好的 **SwiftUI 视频播放器封装**：基于 AVFoundation 的三条渲染路径（SwiftUI `VideoPlayer` / `AVPlayerViewController`（macOS 为 `AVPlayerView`）/ `AVPlayerLayer`），通过一份 `PlayerConfiguration` 按需开启能力。不开启的能力不产生运行时代价，也不出现在 UI 中。

- 面向：iOS 17+ / macOS 14+
- 依赖：无（仅系统框架 AVFoundation / AVKit / SwiftUI / Observation / MediaPlayer(iOS)）
- 定位：**零配置可用，全默认已开**——`ConfigurableVideoPlayer(url:)` 即可播放。

---

## 接入

### Swift Package Manager

```
https://github.com/BuddyLiu/BYAVPlayer
```

```swift
dependencies: [
    .package(url: "https://github.com/BuddyLiu/BYAVPlayer", from: "0.1.0")
]
```

### CocoaPods

```ruby
pod 'BYAVPlayer', '~> 0.1.0'
# 本地/私有源调试：
# pod 'BYAVPlayer', :path => '../BYAVPlayer'
```

---

## 零配置示例

只传 `url`，主功能控件（播放/暂停、时间显示、进度条、音量、全屏）全部默认开启：

```swift
import BYAVPlayer

ConfigurableVideoPlayer(
    url: URL(string: "https://cdn.example.com/videos/trailer.mp4")!
)
.frame(height: 260)
```

自动选择渲染路径：无自定义 UI、无高级能力时使用最轻量的 SwiftUI `VideoPlayer`。

---

## 开启 PiP + AirPlay

```swift
var config = PlayerConfiguration()
config.allowsPictureInPicture = true
config.showsAirPlayButton  = true

ConfigurableVideoPlayer(url: url, configuration: config)
```

任意高级能力（PiP / AirPlay / 字幕 / 速率）开启后，渲染路径自动切到
`AVPlayerViewController`（macOS 为 `AVPlayerView`），由系统控件提供对应入口。

---

## 自定义控件（整体替换默认控件）

提供 `customControls` 后默认控件**完全消失**，闭包收到完整的 `PlayerState`
（`isPlaying`、`currentTime`、`duration`、`isBuffering`、`error`、`subtitles`、
`playbackRate` 等），用于构建绑定状态的自定义 UI：

```swift
var config = PlayerConfiguration()
config.customControls = { state in
    VStack {
        Spacer()
        HStack {
            Button(state.isPlaying ? "暂停" : "播放") { state.togglePlayPause() }
            Text("\(Int(state.currentTime)) / \(Int(state.duration))s")
        }
        .padding()
        .background(.black.opacity(0.5))
    }
}

ConfigurableVideoPlayer(url: url, configuration: config)
```

- `customOverlay` 会叠在视频层与控件层之间；
- 自定义控件闭包签名：`(@MainActor (PlayerState) -> AnyView)?`，在设置值前
  用 `AnyView { ... }` 包裹。

---

## 默认值表

| 能力 | 配置项 | 默认值 | 说明 |
| --- | --- | --- | --- |
| 主功能 | `showsPlaybackControls` | ✅ 开 | 播放/暂停等核心控制 |
| 主功能 | `showsTimeDisplay` | ✅ 开 | 当前时间 / 总时长 |
| 主功能 | `showsProgressSlider` | ✅ 开 | 可拖拽进度条 |
| 主功能 | `showsVolumeControl` | ✅ 开 | 音量控制（iOS 系统音量 / macOS 滑块） |
| 主功能 | `allowsFullscreen` | ✅ 开 | 全屏按钮（`.customLayer` 路径生效） |
| 可选 | `allowsPictureInPicture` | ❌ 关 | PiP（当前不支持的路径会回退，见已知限制） |
| 可选 | `showsAirPlayButton` | ❌ 关 | AirPlay 投屏按钮 |
| 可选 | `allowsSubtitles` | ❌ 关 | 媒体内嵌字幕（legible）轨道 |
| 可选 | `allowsPlaybackRate` | ❌ 关 | 播放速率切换（0.25x–3x） |
| 可选 | `updatesNowPlayingInfo` | ❌ 关 | Now Playing / 锁屏控制（仅 iOS） |
| 可选 | `loopsPlayback` | ❌ 关 | 循环播放（`AVPlayerLooper` + `AVQueuePlayer`） |
| 渲染路径 | `preferredRenderPath` | `nil`（自动） | `.videoPlayer` / `.systemViewController` / `.customLayer` |
| 自定义 UI | `customOverlay` | `nil` | 覆盖层 |
| 自定义 UI | `customControls` | `nil` | 整体替换默认控件 |

> 默认 `nil` 表示自动决策，决策规则见下方。

### 渲染路径自动选择

```
preferredRenderPath != nil                              → 使用指定路径
否则 customControls != nil 或 customOverlay != nil      → .customLayer
否则 allowsPictureInPicture / AirPlay / 字幕 / 速率任一  → .systemViewController
否则                                                    → .videoPlayer
```

若显式指定 `.videoPlayer` 但又开启了 PiP 等能力：Debug 下会触发
`assertionFailure` 并打印明确说明；Release 下日志警告后软回退到
`.systemViewController`，不会静默失效。

---

## 跨页面持续播放

默认情况下视图消失（自持模式）会自动 `pause()` 并释放当前 `AVPlayer`。若需
跨页面继续播放，在外部持有 `PlayerState` 并注入：

```swift
@MainActor
final class PlayerStore {
    var state: PlayerState?

    func play(_ url: URL) {
        state?.tearDown()
        state = PlayerState(url: url)          // 创建即完成 AVPlayer 初始化
    }

    func stop() {
        state?.tearDown()
        state = nil
    }
}

// Scene
ConfigurableVideoPlayer(
    state: store.state!,
    configuration: config
)
```

> 注入模式下本视图**不会**自动暂停/释放播放器，生命周期由调用方负责。

---

## 音频会话

iOS 上播放前会自动将音频会话设为 `.playback` / `.moviePlayback` 并延迟激活
（真正开始播放时才 `setActive(true)`）。也可在 `@main` 中提前调用：

```swift
PlayerBootstrap.configureAudioSessionForPlayback()
```

包内会在创建任何 `AVPlayer` 前自动执行 `PlayerBootstrap.bootstrap()`
（设置 `AVPlayer.isObservationEnabled`），调用方无需手动处理。

---

## 已知限制

- **`.videoPlayer` 路径不支持 PiP / AirPlay / 字幕 / 速率**：显式指定该路径并
  开启这些能力时走回退策略（见上文）；系统 `VideoPlayer` 的控件是整体的，
  `showsTimeDisplay` / `showsProgressSlider` / `showsVolumeControl` 等细粒度开关
  在该路径下不生效。
- **`.systemViewController` 路径的控件是系统整体的**：细粒度开关
  （时间显示、进度条、音量等）在该路径不生效；`allowsFullscreen` 在该路径
  依赖系统全屏能力。
- **macOS 无 `AVPlayerViewController`**：该路径使用 `AVPlayerView`，
  `updatesNowPlayingInfoCenter` / `canStartPictureInPictureAutomaticallyFromInline`
  等 iOS 专属 API 不适用（已用条件编译隔离）。
- **外挂字幕不支持**：只处理媒体内嵌的 legible 轨道。需要外挂字幕时可通过
  `PlayerConfiguration.customControls` 自行实现，或在
  `PlayerState` 的 `selectSubtitle(_:)` 之上扩展自定义轨道源。
- **帧访问（frame-accurate 读取）默认关闭且不暴露**：包内默认不创建
  `AVPlayerItemVideoOutput`，也不在默认控件中提供任何帧访问入口。需要帧访问
  的调用方可自行解析 `player.currentItem?.asset` 挂载
  `AVPlayerItemVideoOutput`，或在此基础上扩展一个 `FrameAccessProviding` 协议。
- **PiP**：`.videoPlayer` 路径不支持；macOS 上 PiP 的可用性由系统
  `isPictureInPictureSupported()` 决定，按钮可用性由 `isPictureInPicturePossible`
  驱动。
- **全屏**：`.customLayer` 路径使用 `fullScreenCover` 呈现**同一个**
  `AVPlayer` 的另一舞台（不创建第二个播放器）；macOS 上以 `.sheet` 呈现
  "伪全屏"。
- **Now Playing / 锁屏控制仅 iOS 生效**（`MPNowPlayingInfoCenter` 为 iOS 专属）。
- `AVPlayer.isObservationEnabled` 在当前 SDK 中被标注为 iOS/macOS 26 起可用，
  更早系统上该开关不会设置，但 KVO 观察不受影响。

---

## 渲染路径与能力矩阵

| 能力 | `.videoPlayer` | `.systemViewController` | `.customLayer`（默认/可选控件） |
| --- | :-: | :-: | :-: |
| 播放/暂停、时间、进度 | 系统控件 | 系统控件 | 包内默认控件 |
| 音量 | 系统（部分） | 系统 | 系统音量(iOS) / 滑块(macOS) |
| 全屏 | 系统 | 系统 | 包内 `fullScreenCover` |
| PiP | ❌（回退） | ✅ | ✅ `AVPictureInPictureController` |
| AirPlay | ❌（回退） | ✅（系统按钮） | ✅ `AVRoutePickerView` |
| 字幕 | ❌（回退） | ✅（系统） | ✅ 包内菜单 |
| 速率 | ❌（回退） | ✅（系统） | ✅ 包内菜单 |
| Now Playing | ❌ | ✅（系统 VC） | ✅ `MPNowPlayingInfoCenter`（iOS） |
| 循环 | ✅ | ✅ | ✅ |

---

## 测试

```bash
swift test
```

覆盖内容：`PlayerConfiguration` 默认值契约（主功能全开、可选功能全关）、
`RenderPathResolver` 全部决策分支（默认配置 / 自定义 UI / 各可选能力 /
显式偏好 / 不兼容回退）。

编译验证（需 Xcode）：

```bash
xcodebuild -scheme BYAVPlayer -destination 'generic/platform=iOS Simulator' build
```

## 预览

[Sources/BYAVPlayer/Previews.swift](Sources/BYAVPlayer/Previews.swift) 提供两个
`PreviewProvider`：零配置可用状态、以及全功能开启状态。

## License

MIT