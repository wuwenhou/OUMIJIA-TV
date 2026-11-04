import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Cầu nối độ sáng màn hình trên iOS.
  ///
  /// iOS không có "độ sáng theo cửa sổ" như Android: `UIScreen.main.brightness`
  /// là độ sáng toàn hệ thống. Vì vậy app lưu mức sáng gốc, áp dụng mức người
  /// dùng chọn, rồi khôi phục ngay khi app rời foreground / kết thúc.
  private var brightnessChannel: FlutterMethodChannel?
  private var savedBrightness: CGFloat?
  private var appliedBrightness: CGFloat?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let center = NotificationCenter.default
    center.addObserver(
      self,
      selector: #selector(restoreSystemBrightness),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    center.addObserver(
      self,
      selector: #selector(reapplyCustomBrightness),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
    center.addObserver(
      self,
      selector: #selector(restoreSystemBrightness),
      name: UIApplication.willTerminateNotification,
      object: nil
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "oumijia_tv/brightness",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }
      switch call.method {
      case "setBrightness":
        guard let number = call.arguments as? NSNumber else {
          result(FlutterError(
            code: "bad_args",
            message: "Thiếu giá trị độ sáng",
            details: nil
          ))
          return
        }
        self.applyBrightness(CGFloat(truncating: number))
        result(true)
      case "getBrightness":
        result(Double(UIScreen.main.brightness))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    brightnessChannel = channel
  }

  /// value < 0 → trả về độ sáng hệ thống; 0...1 → áp dụng mức tuỳ chỉnh.
  private func applyBrightness(_ value: CGFloat) {
    if value < 0 {
      restoreSystemBrightness()
      appliedBrightness = nil
      return
    }
    if savedBrightness == nil {
      savedBrightness = UIScreen.main.brightness
    }
    let clamped = min(max(value, 0), 1)
    appliedBrightness = clamped
    UIScreen.main.brightness = clamped
  }

  @objc private func restoreSystemBrightness() {
    guard let saved = savedBrightness else { return }
    UIScreen.main.brightness = saved
    savedBrightness = nil
  }

  @objc private func reapplyCustomBrightness() {
    guard let value = appliedBrightness else { return }
    if savedBrightness == nil {
      savedBrightness = UIScreen.main.brightness
    }
    UIScreen.main.brightness = value
  }
}
