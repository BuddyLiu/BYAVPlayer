import AVFoundation
import XCTest
@testable import BYAVPlayer

/// PlayerState 创建期状态契约：不依赖网络 / 耗时媒体加载，只锁定初始化后
/// 的确定性状态与简单方法行为（@MainActor 对象按约定在主线程创建）。
@MainActor
final class PlayerStateTests: XCTestCase {

    private let sample = URL(string: "https://example.invalid/media.m3u8")!

    private func makeState(config: PlayerConfiguration = PlayerConfiguration()) -> PlayerState {
        PlayerState(url: sample, configuration: config)
    }

    func testInitDefaults() {
        let state = makeState()
        XCTAssertEqual(state.url, sample)
        XCTAssertFalse(state.isPlaying)
        XCTAssertFalse(state.isBuffering)
        XCTAssertEqual(state.currentTime, 0)
        XCTAssertEqual(state.duration, 0)
        XCTAssertEqual(state.playbackRate, 1)
        XCTAssertNil(state.error)
        XCTAssertEqual(state.volume, 1)
        XCTAssertTrue(state.subtitles.isEmpty)
        XCTAssertNil(state.selectedSubtitleID)
        XCTAssertNil(state.pictureInPictureController)
    }

    func testPlayerIsCreated() {
        let state = makeState()
        XCTAssertNotNil(state.player)
    }

    func testVolumeSetterSyncedToPlayer() {
        let state = makeState()
        state.volume = 0.3
        XCTAssertEqual(state.player.volume, 0.3, accuracy: 0.0001)
    }

    func testSetPlaybackRateUpdatesState() {
        let state = makeState()
        state.setPlaybackRate(1.5)
        XCTAssertEqual(state.playbackRate, 1.5, accuracy: 0.0001)
    }

    func testLoopsPlaybackUsesQueuePlayer() {
        var config = PlayerConfiguration()
        config.loopsPlayback = true
        let state = makeState(config: config)
        XCTAssertTrue(state.player is AVQueuePlayer, "loopsPlayback 应使用 AVQueuePlayer + AVPlayerLooper")
    }

    func testSubtitlesDisabledLeavesListEmpty() {
        // allowsSubtitles 未开启时不应填充轨道列表。
        let state = makeState()
        XCTAssertTrue(state.subtitles.isEmpty)
        XCTAssertNil(state.selectedSubtitleID)
    }

    func testSelectSubtitleIsSafeWithoutTracks() {
        let state = makeState()
        state.selectSubtitle(.off) // 无 legible 轨道时静默无副作用、不崩溃
        XCTAssertTrue(state.subtitles.isEmpty)
        XCTAssertNil(state.selectedSubtitleID)
    }

    func testTearDownIsIdempotent() {
        let state = makeState()
        state.tearDown()
        state.tearDown() // 重复释放不崩溃
    }

    func testOffIDConstant() {
        XCTAssertEqual(SubtitleOption.offID, "byavplayer.subtitle.off")
        XCTAssertTrue(SubtitleOption.off.isOffSelection)
    }
}