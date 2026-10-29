import CoreLocation
import Flutter
import UIKit

/// Streams raw CoreLocation heading data. Declination, smoothing and rate
/// limiting happen in Dart. Only the magnetic heading is used, so no location
/// permission is ever requested.
public class TrueCompassPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, CLLocationManagerDelegate {
  private var sink: FlutterEventSink?
  private var manager: CLLocationManager?
  private var compensate = true

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = TrueCompassPlugin()
    let methods = FlutterMethodChannel(name: "true_compass/methods", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: methods)
    let events = FlutterEventChannel(name: "true_compass/events", binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "checkAvailability", "requestPermission":
      result(CLLocationManager.headingAvailable() ? "available" : "noSensor")
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: FlutterStreamHandler

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    guard CLLocationManager.headingAvailable() else {
      return FlutterError(code: "no_sensor", message: "No compass sensor on this device", details: nil)
    }
    sink = events
    compensate = ((arguments as? [String: Any])?["compensateScreenOrientation"] as? Bool) ?? true
    let m = CLLocationManager()
    m.delegate = self
    m.headingFilter = kCLHeadingFilterNone
    applyOrientation(m)
    m.startUpdatingHeading()
    manager = m
    UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    NotificationCenter.default.addObserver(
      self, selector: #selector(orientationChanged),
      name: UIDevice.orientationDidChangeNotification, object: nil)
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
    UIDevice.current.endGeneratingDeviceOrientationNotifications()
    manager?.stopUpdatingHeading()
    manager?.delegate = nil
    manager = nil
    sink = nil
    return nil
  }

  @objc private func orientationChanged() {
    if let m = manager { applyOrientation(m) }
  }

  /// CoreLocation rotates the heading itself when `headingOrientation` matches
  /// the interface orientation, so Dart gets an already screen-relative value.
  private func applyOrientation(_ m: CLLocationManager) {
    guard compensate else {
      m.headingOrientation = .portrait
      return
    }
    let orientation = UIApplication.shared.connectedScenes
      .compactMap { ($0 as? UIWindowScene)?.interfaceOrientation }.first ?? .portrait
    switch orientation {
    case .portraitUpsideDown: m.headingOrientation = .portraitUpsideDown
    // Interface and device landscape are mirrored.
    case .landscapeLeft: m.headingOrientation = .landscapeRight
    case .landscapeRight: m.headingOrientation = .landscapeLeft
    default: m.headingOrientation = .portrait
    }
  }

  // MARK: CLLocationManagerDelegate

  public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
    guard newHeading.magneticHeading >= 0 else { return }
    sink?([
      "kind": "heading",
      "heading": newHeading.magneticHeading,
      "compensated": true,
      "screenRotation": 0,
      // Negative means "invalid" (needs calibration); Dart maps that to unreliable.
      "errorDegrees": newHeading.headingAccuracy,
    ])
  }

  public func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
    sink?(["kind": "calibration"])
    return true
  }
}
