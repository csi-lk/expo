// Copyright 2015-present 650 Industries. All rights reserved.

import ExpoModulesCore

private let queue = DispatchQueue(label: "expo.modules.networkfetch.RequestQueue")
internal var urlSessionConfigurationProvider: NSURLSessionConfigurationProvider?

public final class ExpoNetworkFetchModule: Module {
  private lazy var urlSession = createURLSession()
  private let urlSessionDelegate: URLSessionSessionDelegateProxy

  public required init(appContext: AppContext) {
    urlSessionDelegate = URLSessionSessionDelegateProxy(dispatchQueue: queue)
    super.init(appContext: appContext)
  }

  public func definition() -> ModuleDefinition {
    Name("ExpoNetworkFetchModule")

    OnDestroy {
      urlSession.invalidateAndCancel()
    }

    // swiftlint:disable:next closure_body_length
    Class(NativeResponse.self) {
      Constructor {
        return NativeResponse(dispatchQueue: queue)
      }

      AsyncFunction("startStreaming") { (response: NativeResponse) in
        response.startStreaming()
      }.runOnQueue(queue)

      AsyncFunction("cancelStreaming") { (response: NativeResponse, _ reason: String) in
        response.cancelStreaming()
      }.runOnQueue(queue)

      Property("bodyUsed", \.bodyUsed)

      Property("_rawHeaders") { (response: NativeResponse) in
        return response.responseInit?.headers ?? []
      }

      Property("status") { (response: NativeResponse) in
        return response.responseInit?.status ?? -1
      }

      Property("statusText") { (response: NativeResponse) in
        return response.responseInit?.statusText ?? ""
      }

      Property("url") { (response: NativeResponse) in
        return response.responseInit?.url ?? ""
      }

      Property("redirected", \.redirected)

      AsyncFunction("arrayBuffer") { (response: NativeResponse, promise: Promise) in
        response.waitFor(states: [.bodyCompleted]) { _ in
          let data = response.sink.finalize()
          promise.resolve(data)
        }
      }.runOnQueue(queue)

      AsyncFunction("text") { (response: NativeResponse, promise: Promise) in
        response.waitFor(states: [.bodyCompleted]) { _ in
          let data = response.sink.finalize()
          let text = String(decoding: data, as: UTF8.self)
          promise.resolve(text)
        }
      }.runOnQueue(queue)
    }

    Class(NativeRequest.self) {
      Constructor { (nativeResponse: NativeResponse) in
        return NativeRequest(response: nativeResponse)
      }

      AsyncFunction("start") { (request: NativeRequest, url: URL, requestInit: NativeRequestInit, requestBody: Data?, promise: Promise) in
        request.start(
          urlSession: urlSession,
          urlSessionDelegate: urlSessionDelegate,
          url: url,
          requestInit: requestInit,
          requestBody: requestBody
        )
        request.response.waitFor(states: [.responseReceived, .errorReceived]) { state in
          if state == .responseReceived {
            promise.resolve()
          } else if state == .errorReceived {
            promise.reject(request.response.error ?? NetworkFetchUnknownException())
          }
        }
      }.runOnQueue(queue)

      AsyncFunction("cancel") { (request: NativeRequest) in
        request.cancel(urlSessionDelegate: self.urlSessionDelegate)
      }.runOnQueue(queue)
    }
  }

  private func createURLSession() -> URLSession {
    let config: URLSessionConfiguration
    if let urlSessionConfigurationProvider, let concreteConfig = urlSessionConfigurationProvider() {
      config = concreteConfig
    } else {
      config = URLSessionConfiguration.default
      config.httpShouldSetCookies = true
      config.httpCookieAcceptPolicy = .always
      config.httpCookieStorage = HTTPCookieStorage.shared

      let useWifiOnly = Bundle.main.infoDictionary?["ReactNetworkForceWifiOnly"] as? Bool ?? false
      if useWifiOnly {
        config.allowsCellularAccess = !useWifiOnly
      }
    }
    return URLSession(configuration: config, delegate: urlSessionDelegate, delegateQueue: nil)
  }
}
