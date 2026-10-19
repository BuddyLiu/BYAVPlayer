import Foundation

/// 内部决策函数：根据配置推导最终渲染路径，并对显式偏好做兼容性校验。
///
/// 决策优先级（与文档约定一致）：
/// ```
/// 如果 preferredRenderPath != nil，使用指定路径
/// 否则如果 customControls != nil 或 customOverlay != nil → .customLayer
/// 否则如果 allowsPictureInPicture 或 showsAirPlayButton 或 allowsSubtitles
///      或 allowsPlaybackRate → .systemViewController
/// 否则 → .videoPlayer
/// ```
enum RenderPathResolver {

    /// 纯决策逻辑（不做校验），供决策与单测复用。
    static func resolve(_ config: PlayerConfiguration) -> PlayerConfiguration.RenderPath {
        if let preferred = config.preferredRenderPath {
            return preferred
        }
        if config.hasCustomUI {
            return .customLayer
        }
        if config.requiresViewControllerCapabilities {
            return .systemViewController
        }
        return .videoPlayer
    }

    /// 兼容性校验的**纯**逻辑：`.videoPlayer` 与部分可选能力不兼容时返回
    /// 需要回退到的路径；无需回退时返回 `nil`。
    static func compatibilityFallback(_ path: PlayerConfiguration.RenderPath,
                                      against config: PlayerConfiguration) -> PlayerConfiguration.RenderPath? {
        guard path == .videoPlayer, config.requiresViewControllerCapabilities else {
            return nil
        }
        return .systemViewController
    }

    /// 兼容性校验。Debug 下触发 `assertionFailure` 并打印明确说明；
    /// Release 下仅通过日志警告，并静默回退到 `.systemViewController`。
    static func validate(_ path: PlayerConfiguration.RenderPath,
                         against config: PlayerConfiguration) -> PlayerConfiguration.RenderPath? {
        let fallback = compatibilityFallback(path, against: config)
        guard fallback != nil else { return nil }
        let message = """
        BYAVPlayer: 指定的 `.videoPlayer` 渲染路径不支持配置中已开启的能力 \
        （allowsPictureInPicture / showsAirPlayButton / allowsSubtitles / allowsPlaybackRate）。\
         Debug 构建触发断言；Release 构建回退到 `.systemViewController`。
        """
        assertionFailure(message)
        #if DEBUG
        print("[BYAVPlayer] " + message)
        #endif
        return fallback
    }

    /// 决策 + 校验，返回最终生效的路径。
    static func resolveWithValidation(_ config: PlayerConfiguration) -> PlayerConfiguration.RenderPath {
        let path = resolve(config)
        return validate(path, against: config) ?? path
    }
}