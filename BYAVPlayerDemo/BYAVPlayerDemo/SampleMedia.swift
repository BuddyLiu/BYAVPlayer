//
//  SampleMedia.swift
//  BYAVPlayerDemo
//
//  Created by bo.liu on 2026/10/19.
//

import Foundation

/// 演示用的免费公开媒体资源（均为 HTTPS，无需额外配置 ATS）。
///
/// !!! 说明：以下每条链接都已在「国内网络环境」逐个 curl 实测可达（HTTP 200/206）。
/// 传统教程里流传的"国内免费测试流"绝大多数已失效——北邮直播间
/// （ivi.bupt.edu.cn/hls）、香港卫视（live.hkstv.hk.lxdns.com）、央视 CDN
/// （hls.cntv.myhwcdn.cn）、百度 CDN（vd*.bdstatic.com）、时光网
/// （vfx.mtime.cn），以及 Apple/Google 官方样例（devstreaming-cdn.apple.com、
/// commondatastorage.googleapis.com，含本工程早期版本用的两个地址），
/// 2026-10 实测均不可达。
enum SampleMedia {
    /// HLS 多码率点播（Tears of Steel，Unified Streaming 官方测试流，国内外都稳定）。
    /// 多档清晰度 + 多音频轨，适合演示系统控制器 / PiP / Now Playing 等能力。
    static let hlsTearsOfSteel = URL(string: "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8")!

    /// 点播 MP4（Video.js 官方 CDN，国内可达）：56 秒、约 23 MB，适合零配置 / 自定义控件。
    static let mp4Oceans = URL(string: "https://vjs.zencdn.net/v/oceans.mp4")!

    /// 国内教程站 w3school.com.cn 的 HTML5 示例短片：体积最小、秒开。
    static let mp4DomesticShort = URL(string: "https://www.w3school.com.cn/i/movie.mp4")!
}