# 默认值约定

BYAVPlayer 的配置默认值严格遵循 **“主功能开启、其他关闭”**：

| 能力 | 配置项 | 默认值 |
| --- | --- | --- |
| 主功能 | ``PlayerConfiguration/showsPlaybackControls`` | ✅ 开 |
| 主功能 | ``PlayerConfiguration/showsTimeDisplay`` | ✅ 开 |
| 主功能 | ``PlayerConfiguration/showsProgressSlider`` | ✅ 开 |
| 主功能 | ``PlayerConfiguration/showsVolumeControl`` | ✅ 开 |
| 主功能 | ``PlayerConfiguration/allowsFullscreen`` | ✅ 开 |
| 可选 | ``PlayerConfiguration/allowsPictureInPicture`` | ❌ 关 |
| 可选 | ``PlayerConfiguration/showsAirPlayButton`` | ❌ 关 |
| 可选 | ``PlayerConfiguration/allowsSubtitles`` | ❌ 关 |
| 可选 | ``PlayerConfiguration/allowsPlaybackRate`` | ❌ 关 |
| 可选 | ``PlayerConfiguration/updatesNowPlayingInfo`` | ❌ 关 |
| 可选 | ``PlayerConfiguration/loopsPlayback`` | ❌ 关 |
| 渲染 | ``PlayerConfiguration/preferredRenderPath`` | `nil`（自动） |
| UI | ``PlayerConfiguration/customOverlay`` | `nil` |
| UI | ``PlayerConfiguration/customControls`` | `nil` |

渲染路径自动决策优先级：

```
preferredRenderPath != nil                              → 使用指定路径
否则 customControls != nil 或 customOverlay != nil      → .customLayer
否则 任一高级能力开启                                    → .systemViewController
否则                                                    → .videoPlayer
```