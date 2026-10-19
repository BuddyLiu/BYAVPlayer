# BYAVPlayer

零依赖、可配置的 SwiftUI 视频播放器封装。

调用方通过一份 `PlayerConfiguration` 按需开启能力；不开启的能力不产生运行时代价，也不出现在 UI 中。

主入口：

- ``ConfigurableVideoPlayer`` —— 播放器视图
- ``PlayerConfiguration`` —— 能力配置模型
- ``PlayerState`` —— 公共可观察状态（自定义控件闭包接收此对象）

<doc:DefaultValues>

- 术语：``PlayerConfiguration/RenderPath``