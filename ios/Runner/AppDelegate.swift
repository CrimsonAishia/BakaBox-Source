import Flutter
import UIKit
import WebKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // 设置 Cookie Channel
    let controller = window?.rootViewController as! FlutterViewController
    let cookieChannel = FlutterMethodChannel(name: "cc.aishia.bakabox/cookie",
                                              binaryMessenger: controller.binaryMessenger)
    
    cookieChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "getCookies" {
        guard let args = call.arguments as? [String: Any],
              let url = args["url"] as? String else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "URL is required", details: nil))
          return
        }
        self?.getCookies(url: url, result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func getCookies(url: String, result: @escaping FlutterResult) {
    guard let urlObj = URL(string: url) else {
      result(FlutterError(code: "INVALID_URL", message: "Invalid URL", details: nil))
      return
    }
    
    let dataStore = WKWebsiteDataStore.default()
    dataStore.httpCookieStore.getAllCookies { cookies in
      // 过滤出匹配域名的 cookies
      let domain = urlObj.host ?? ""
      let matchingCookies = cookies.filter { cookie in
        return domain.hasSuffix(cookie.domain) || cookie.domain.hasSuffix(domain) || cookie.domain == domain
      }
      
      let cookieList = matchingCookies.map { cookie -> [String: String] in
        return ["name": cookie.name, "value": cookie.value]
      }
      
      result(cookieList)
    }
  }
}
