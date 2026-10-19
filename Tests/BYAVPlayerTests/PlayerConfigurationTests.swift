import SwiftUI
import XCTest
@testable import BYAVPlayer

/// 锁定配置模型的默认值契约：主功能默认开启、可选功能默认关闭。
final class PlayerConfigurationTests: XCTestCase {

    private var config: PlayerConfiguration { PlayerConfiguration() }

    func testMainFeaturesDefaultEnabled() {
        let config = self.config
        XCTAssertTrue(config.showsPlaybackControls)
        XCTAssertTrue(config.showsTimeDisplay)
        XCTAssertTrue(config.showsProgressSlider)
        XCTAssertTrue(config.showsVolumeControl)
        XCTAssertTrue(config.allowsFullscreen)
    }

    func testOptionalFeaturesDefaultDisabled() {
        let config = self.config
        XCTAssertFalse(config.allowsPictureInPicture)
        XCTAssertFalse(config.showsAirPlayButton)
        XCTAssertFalse(config.allowsSubtitles)
        XCTAssertFalse(config.allowsPlaybackRate)
        XCTAssertFalse(config.updatesNowPlayingInfo)
        XCTAssertFalse(config.loopsPlayback)
    }

    func testRenderPathPreferenceDefaultsToNil() {
        XCTAssertNil(config.preferredRenderPath)
    }

    func testCustomUIPreferencesDefaultToNil() {
        XCTAssertNil(config.customOverlay)
        XCTAssertNil(config.customControls)
    }

    func testRequiresViewControllerCapabilitiesReflectsOptionalFlags() {
        var disabled = PlayerConfiguration()
        XCTAssertFalse(disabled.requiresViewControllerCapabilities)

        var enabled = PlayerConfiguration()
        enabled.allowsPictureInPicture = true
        XCTAssertTrue(enabled.requiresViewControllerCapabilities)
    }

    func testHasCustomUIReflectsClosures() {
        let empty = PlayerConfiguration()
        XCTAssertFalse(empty.hasCustomUI)

        var withOverlay = PlayerConfiguration()
        withOverlay.customOverlay = { _ in AnyView(EmptyView()) }
        XCTAssertTrue(withOverlay.hasCustomUI)

        var withControls = PlayerConfiguration()
        withControls.customControls = { _ in AnyView(EmptyView()) }
        XCTAssertTrue(withControls.hasCustomUI)
    }

    func testMainFeaturesCanBeDisabled() {
        var config = PlayerConfiguration()
        config.showsPlaybackControls = false
        config.showsTimeDisplay = false
        config.showsProgressSlider = false
        config.showsVolumeControl = false
        config.allowsFullscreen = false
        XCTAssertFalse(config.showsPlaybackControls)
        XCTAssertFalse(config.showsTimeDisplay)
        XCTAssertFalse(config.showsProgressSlider)
        XCTAssertFalse(config.showsVolumeControl)
        XCTAssertFalse(config.allowsFullscreen)
    }

    func testRequiresViewControllerCapabilitiesPerOptionalFlag() {
        var airplay = PlayerConfiguration(); airplay.showsAirPlayButton = true
        var subtitles = PlayerConfiguration(); subtitles.allowsSubtitles = true
        var rate = PlayerConfiguration(); rate.allowsPlaybackRate = true
        var loops = PlayerConfiguration(); loops.loopsPlayback = true

        XCTAssertTrue(airplay.requiresViewControllerCapabilities)
        XCTAssertTrue(subtitles.requiresViewControllerCapabilities)
        XCTAssertTrue(rate.requiresViewControllerCapabilities)
        // loopsPlayback 由 AVQueuePlayer 支持，不需要系统控制器。
        XCTAssertFalse(loops.requiresViewControllerCapabilities)
    }
}