import AVKit
import SwiftUI

/// `.videoPlayer` 渲染路径：直接使用系统 SwiftUI `VideoPlayer`，最轻量。
///
/// 该路径复用系统控件，因此 `showsTimeDisplay` / `showsProgressSlider` /
/// `showsVolumeControl` 等细粒度开关不生效（由系统统一渲染）；关闭系统控件
/// 请改用 `.customLayer` 路径。
struct SystemVideoPlayer: View {
    let state: PlayerState

    var body: some View {
        VideoPlayer(player: state.player)
    }
}