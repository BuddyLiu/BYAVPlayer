//
//  BYAVPlayerDemoTests.swift
//  BYAVPlayerDemoTests
//
//  Created by bo.liu on 2026/10/19.
//

import BYAVPlayer
import XCTest
@testable import BYAVPlayerDemo

/// Demo 工程的单元测试：示例媒体源、`formatTime`、`PlayerStore` 生命周期。
/// 不依赖网络播放，只锁定纯逻辑与状态契约。
final class BYAVPlayerDemoTests: XCTestCase {

    // MARK: - SampleMedia

    func testSampleMediaURLsAreValidHTTPS() {
        let samples = [SampleMedia.hlsTearsOfSteel, SampleMedia.mp4Oceans, SampleMedia.mp4DomesticShort]
        for url in samples {
            XCTAssertEqual(url.scheme, "https", "\(url) 应为 HTTPS")
            XCTAssertNotNil(url.host)
            XCTAssertFalse(url.host!.isEmpty)
        }
    }

    func testSampleMediaExtensions() {
        XCTAssertTrue(SampleMedia.hlsTearsOfSteel.path.hasSuffix(".m3u8"))
        XCTAssertTrue(SampleMedia.mp4Oceans.path.hasSuffix(".mp4"))
        XCTAssertTrue(SampleMedia.mp4DomesticShort.path.hasSuffix(".mp4"))
    }

    // MARK: - formatTime

    func testFormatTimeUnits() {
        XCTAssertEqual(formatTime(0), "0:00")
        XCTAssertEqual(formatTime(59), "0:59")
        XCTAssertEqual(formatTime(60), "1:00")
        XCTAssertEqual(formatTime(61.4), "1:01")
        XCTAssertEqual(formatTime(3599), "59:59")
        XCTAssertEqual(formatTime(3600), "1:00:00")
        XCTAssertEqual(formatTime(3661), "1:01:01")
    }

    func testFormatTimeEdgeCases() {
        XCTAssertEqual(formatTime(-5), "0:00")
        XCTAssertEqual(formatTime(.infinity), "0:00")
        XCTAssertEqual(formatTime(.nan), "0:00")
    }

    // MARK: - PlayerStore

    @MainActor
    func testEnsureReturnsSameInstanceForSameURL() {
        let store = PlayerStore.shared
        defer { store.release() }
        let first = store.ensure(url: SampleMedia.mp4DomesticShort)
        let second = store.ensure(url: SampleMedia.mp4DomesticShort)
        XCTAssertTrue(first === second, "同一 URL 应复用同一 PlayerState 实例")
    }

    @MainActor
    func testEnsureReplacesInstanceForDifferentURL() {
        let store = PlayerStore.shared
        defer { store.release() }
        let a = store.ensure(url: SampleMedia.mp4DomesticShort)
        let b = store.ensure(url: SampleMedia.mp4Oceans)
        XCTAssertFalse(a === b, "不同 URL 应创建新 PlayerState 并释放旧的")
    }

    @MainActor
    func testReleaseDropsHeldState() {
        let store = PlayerStore.shared
        let first = store.ensure(url: SampleMedia.mp4DomesticShort)
        store.release()
        let second = store.ensure(url: SampleMedia.mp4DomesticShort)
        XCTAssertFalse(first === second, "release() 后再次 ensure 应产生新实例")
        store.release()
    }
}