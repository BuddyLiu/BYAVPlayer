import SwiftUI

struct ConfigurableVideoPlayer_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 24) {
            // 零配置可用：只传 URL，主功能控件全部默认开启。
            ConfigurableVideoPlayer(
                url: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")!
            )
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // 全功能开启：PiP + AirPlay + 字幕 + 速率 + 循环。
            ConfigurableVideoPlayer(
                url: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")!,
                configuration: {
                    var config = PlayerConfiguration()
                    config.allowsPictureInPicture = true
                    config.showsAirPlayButton = true
                    config.allowsSubtitles = true
                    config.allowsPlaybackRate = true
                    config.loopsPlayback = true
                    config.updatesNowPlayingInfo = true
                    return config
                }()
            )
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding()
    }
}