import SwiftUI
import XCTest
@testable import BYAVPlayer

/// 渲染路径决策逻辑。覆盖默认配置、自定义 UI、可选功能组合与显式偏好。
final class RenderPathResolverTests: XCTestCase {

    private typealias RenderPath = PlayerConfiguration.RenderPath

    func testDefaultConfigResolvesToVideoPlayer() {
        XCTAssertEqual(RenderPathResolver.resolve(PlayerConfiguration()), .videoPlayer)
    }

    func testCustomControlsResolveToCustomLayer() {
        var config = PlayerConfiguration()
        config.customControls = { _ in AnyView(EmptyView()) }
        XCTAssertEqual(RenderPathResolver.resolve(config), .customLayer)
    }

    func testCustomOverlayResolveToCustomLayer() {
        var config = PlayerConfiguration()
        config.customOverlay = { _ in AnyView(EmptyView()) }
        XCTAssertEqual(RenderPathResolver.resolve(config), .customLayer)
    }

    func testEachOptionalFeatureResolvesToSystemViewController() {
        var pip = PlayerConfiguration(); pip.allowsPictureInPicture = true
        var airplay = PlayerConfiguration(); airplay.showsAirPlayButton = true
        var subtitles = PlayerConfiguration(); subtitles.allowsSubtitles = true
        var rate = PlayerConfiguration(); rate.allowsPlaybackRate = true

        XCTAssertEqual(RenderPathResolver.resolve(pip), .systemViewController)
        XCTAssertEqual(RenderPathResolver.resolve(airplay), .systemViewController)
        XCTAssertEqual(RenderPathResolver.resolve(subtitles), .systemViewController)
        XCTAssertEqual(RenderPathResolver.resolve(rate), .systemViewController)
    }

    func testCombinedOptionalFeaturesStillResolveToSystemViewController() {
        var config = PlayerConfiguration()
        config.allowsPictureInPicture = true
        config.showsAirPlayButton = true
        config.allowsSubtitles = true
        config.allowsPlaybackRate = true
        XCTAssertEqual(RenderPathResolver.resolve(config), .systemViewController)
    }

    func testPreferredRenderPathWinsOverAutoDecision() {
        var config = PlayerConfiguration()
        config.allowsPictureInPicture = true
        config.preferredRenderPath = .videoPlayer
        XCTAssertEqual(RenderPathResolver.resolve(config), .videoPlayer)
    }

    func testPreferredCustomLayerWithSystemCapabilitiesIsRespected() {
        var config = PlayerConfiguration()
        config.allowsPictureInPicture = true
        config.preferredRenderPath = .customLayer
        XCTAssertEqual(RenderPathResolver.resolve(config), .customLayer)
    }

    func testValidationFallsBackFromVideoPlayerToSystemViewController() {
        var config = PlayerConfiguration()
        config.allowsPictureInPicture = true
        let fallback = RenderPathResolver.compatibilityFallback(.videoPlayer, against: config)

        // 兼容性校验应当返回 systemViewController 作为软回退路径。
        XCTAssertEqual(fallback, .systemViewController)
    }

    func testValidationDoesNotFallbackWhenCapabilitiesNotEnabled() {
        let config = PlayerConfiguration()
        XCTAssertNil(RenderPathResolver.compatibilityFallback(.videoPlayer, against: config))
    }

    func testFallbackNilWhenPathIsNotVideoPlayer() {
        var config = PlayerConfiguration()
        config.allowsPictureInPicture = true
        XCTAssertNil(RenderPathResolver.compatibilityFallback(.systemViewController, against: config))
        XCTAssertNil(RenderPathResolver.compatibilityFallback(.customLayer, against: config))
    }

    func testFallbackNilForAnyPathWithoutCapabilities() {
        let config = PlayerConfiguration()
        XCTAssertNil(RenderPathResolver.compatibilityFallback(.videoPlayer, against: config))
        XCTAssertNil(RenderPathResolver.compatibilityFallback(.systemViewController, against: config))
        XCTAssertNil(RenderPathResolver.compatibilityFallback(.customLayer, against: config))
    }

    func testResolveWithValidationKeepsSafePreferredPath() {
        var config = PlayerConfiguration()
        config.preferredRenderPath = .videoPlayer
        XCTAssertEqual(RenderPathResolver.resolveWithValidation(config), .videoPlayer)
    }

    func testResolveWithValidationResolvesCapabilitiesToSystemViewController() {
        // 允许 PiP 时自动决策到 systemViewController，且校验不改变结果（不在断言下崩溃）。
        var config = PlayerConfiguration()
        config.allowsPictureInPicture = true
        XCTAssertEqual(RenderPathResolver.resolveWithValidation(config), .systemViewController)
    }

    func testResolveWithValidationResolvesCustomUI() {
        var config = PlayerConfiguration()
        config.customOverlay = { _ in AnyView(EmptyView()) }
        XCTAssertEqual(RenderPathResolver.resolveWithValidation(config), .customLayer)
    }
}