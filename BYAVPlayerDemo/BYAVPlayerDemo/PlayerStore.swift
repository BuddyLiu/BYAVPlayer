//
//  PlayerStore.swift
//  BYAVPlayerDemo
//
//  Created by bo.liu on 2026/10/19.
//

import BYAVPlayer
import Observation
import SwiftUI

/// 演示“由调用方持有 `PlayerState`，跨页面继续播放”的共享存储。
///
/// BYAVPlayer 的注入模式 `ConfigurableVideoPlayer(state:configuration:)` 不会在
/// 视图消失时暂停/释放播放器 —— 播放器的生命周期完全由这里（调用方）管理，
/// 结束时记得调用 `release()`（内部 `tearDown()` 清理观察者与资源）。
@MainActor
@Observable
final class PlayerStore {

    static let shared = PlayerStore()

    private(set) var state: PlayerState?

    private init() {}

    /// 确保指定 URL 的播放器已创建并返回同一个实例。
    func ensure(url: URL, configuration: PlayerConfiguration = .init()) -> PlayerState {
        if let state, state.url == url {
            return state
        }
        state?.tearDown()
        let newState = PlayerState(url: url, configuration: configuration)
        state = newState
        return newState
    }

    /// 停止播放并释放播放器（观察者、Now Playing 指令等一并清理）。
    func release() {
        state?.tearDown()
        state = nil
    }
}