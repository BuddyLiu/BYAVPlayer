Pod::Spec.new do |s|
  s.name             = 'BYAVPlayer'
  s.version          = '0.1.0'
  s.summary          = '零依赖、可配置的 SwiftUI 视频播放器封装（基于 AVFoundation 三条渲染路径）。'
  s.description      = <<-DESC
  BYAVPlayer 是一个零依赖、可配置、对调用方友好的 SwiftUI AVPlayer 封装包。
  对外只暴露一个主入口视图 `ConfigurableVideoPlayer` 和一个配置模型 `PlayerConfiguration`：
  调用方通过配置按需开启能力（PiP、AirPlay、字幕、播放速率、Now Playing、循环、自定义 UI 等），
  不开启的能力不产生运行时代价、也不出现在 UI 中。
  支持三条渲染路径：SwiftUI VideoPlayer / AVPlayerViewController（iOS）/ AVPlayerView（macOS）/ AVPlayerLayer。
  iOS 17+ / macOS 14+。
  DESC
  s.homepage         = 'https://github.com/BuddyLiu/BYAVPlayer'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'BuddyLiu' => '13621905107@163.com' }
  s.source           = { :git => 'https://github.com/BuddyLiu/BYAVPlayer.git', :tag => s.version.to_s }

  s.ios.deployment_target = '17.0'
  s.osx.deployment_target  = '14.0'

  # 与 Package.swift 的 Swift 5 语言模式对齐，避免 CocoaPods 以 Swift 6
  # 严格并发模式编译 AVFoundation 交互代码时出现误报级报错。
  s.swift_version   = '5.9'

  s.source_files     = 'Sources/BYAVPlayer/**/*.swift'
  # 注意：不要在此声明 'Observation' —— 该框架在 iOS/macOS SDK 中不存在
  # （仅有 toolchain 的预编译 Swift 模块），显式 `-framework Observation`
  # 会导致 `ld: framework 'Observation' not found`。SwiftUI 会自动链接它。
  s.frameworks       = 'AVFoundation', 'AVKit', 'SwiftUI'

  s.requires_arc     = true
end