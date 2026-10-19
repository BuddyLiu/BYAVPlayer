//
//  BYAVPlayerDemoUITests.swift
//  BYAVPlayerDemoUITests
//
//  Created by bo.liu on 2026/10/19.
//

import XCTest

/// 主列表导航 + 示例页面标题 + 自定义控件交互的端到端验证。
/// 播放本身依赖网络，这里只断言 UI 结构与控件交互，不依赖真实播放。
final class BYAVPlayerDemoUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsAllFourExampleScreens() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["BYAVPlayerDemo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["零配置播放"].exists)
        XCTAssertTrue(app.staticTexts["全功能（PiP / AirPlay / 字幕 / 速率 / Now Playing / 循环）"].exists)
        XCTAssertTrue(app.staticTexts["自定义控件（customLayer 渲染）"].exists)
        XCTAssertTrue(app.staticTexts["跨页面继续播放（注入 PlayerState）"].exists)
    }

    @MainActor
    func testNavigationToEachExampleScreen() throws {
        let app = XCUIApplication()
        app.launch()

        // 零配置
        app.staticTexts["零配置播放"].tap()
        XCTAssertTrue(app.navigationBars["零配置播放"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()

        // 全功能（HLS，自动切换到系统控制器路径）
        app.staticTexts["全功能（PiP / AirPlay / 字幕 / 速率 / Now Playing / 循环）"].tap()
        XCTAssertTrue(app.navigationBars["全功能（HLS）"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()

        // 自定义控件（customLayer 渲染）
        app.staticTexts["自定义控件（customLayer 渲染）"].tap()
        XCTAssertTrue(app.navigationBars["自定义控件"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()

        // 跨页面继续播放
        app.staticTexts["跨页面继续播放（注入 PlayerState）"].tap()
        XCTAssertTrue(app.navigationBars["跨页面播放"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCustomControlsToggleVisibility() throws {
        let app = XCUIApplication()
        app.launch()
        app.staticTexts["自定义控件（customLayer 渲染）"].tap()

        let toggle = app.buttons["custom-toggle"]
        let playPause = app.buttons["custom-play-pause"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertTrue(playPause.exists)
        XCTAssertTrue(app.buttons["custom-back10"].exists)
        XCTAssertTrue(app.buttons["custom-forward10"].exists)

        // 在空白角落点击透明层 → 控件隐藏
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.06)).tap()
        let gone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: playPause
        )
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 3), .completed)

        // 再次点击 → 控件恢复
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.06)).tap()
        XCTAssertTrue(playPause.waitForExistence(timeout: 3))
    }

    @MainActor
    func testCrossPageNavigationToSecondPage() throws {
        let app = XCUIApplication()
        app.launch()
        app.staticTexts["跨页面继续播放（注入 PlayerState）"].tap()
        XCTAssertTrue(app.navigationBars["跨页面播放"].waitForExistence(timeout: 5))

        let next = app.buttons["前往第二页"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        next.tap()

        XCTAssertTrue(app.staticTexts["页面 2：两页注入同一份 PlayerState，切换页面不中断播放"]
            .waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["返回第一页"].exists)
    }
}