// Copyright 2015-present 650 Industries. All rights reserved.

/**
 A SharedRef for response.
 */
internal final class NativeResponse: SharedRef<ResponseSink>, ExpoURLSessionTaskDelegate {
  private let dispatchQueue: DispatchQueue

  private(set) var state: ResponseState = .intialized {
    didSet {
      dispatchQueue.async { [weak self] in
        guard let self else {
          return
        }
        self.stateChangeOnceListeners.removeAll { $0(self.state) == true }
      }
    }
  }
  private typealias StateChangeListener = (ResponseState) -> Bool
  private var stateChangeOnceListeners: [StateChangeListener] = []

  private(set) var responseInit: NativeResponseInit?
  private(set) var redirected = false
  private(set) var error: Error?

  var bodyUsed: Bool {
    return self.ref.bodyUsed
  }

  init(dispatchQueue: DispatchQueue) {
    self.dispatchQueue = dispatchQueue
    super.init(ResponseSink())
  }

  func startStreaming() {
    if isInvalidState([.responseReceived]) {
      return
    }
    state = .bodyStreamingStarted
    let queuedData = self.ref.finalize()
    emit(event: "didReceiveResponseData", arguments: queuedData)
  }

  func cancelStreaming() {
    if isInvalidState([.bodyStreamingStarted]) {
      return
    }
    state = .bodyStreamingCancelled
  }

  func emitRequestCancelled() {
    error = NetworkFetchRequestCancelledException()
    state = .errorReceived
  }

  /**
   Waits for given states and when it meets the requirement, executes the callback.
   */
  func waitFor(states: [ResponseState], callback: @escaping (ResponseState) -> Void) {
    if states.contains(state) {
      callback(state)
      return
    }
    dispatchQueue.async { [weak self] () in
      guard let self else {
        return
      }
      self.stateChangeOnceListeners.append { newState in
        if states.contains(newState) {
          callback(newState)
          return true
        }
        return false
      }
    }
  }

  /**
   Check valid state machine
   */
  private func isInvalidState(_ validStates: [ResponseState]) -> Bool {
    if validStates.contains(state) {
      return false
    }

    let validStatesString = validStates.map { "\($0.rawValue)" }.joined(separator: ",")
    NSLog("Invalid state - currentState[\(state.rawValue)] validStates[\(validStatesString)]")
    return true
  }

  /**
   Factory of NativeResponseInit
   */
  private static func createResponseInit(response: URLResponse) -> NativeResponseInit? {
    guard let httpResponse = response as? HTTPURLResponse else {
      NSLog("Invalid response type")
      return nil
    }

    let status = httpResponse.statusCode
    let statusText = HTTPURLResponse.localizedString(forStatusCode: status)
    let headers = httpResponse.allHeaderFields.reduce(into: [[String]]()) { result, header in
      if let key = header.key as? String, let value = header.value as? String {
        result.append([key, value])
      }
    }
    let url = httpResponse.url?.absoluteString ?? ""
    return NativeResponseInit(
      headers: headers, status: status, statusText: statusText, url: url
    )
  }

  // MARK: - ExpoURLSessionTaskDelegate implementations

  func urlSessionDidStart(_ session: ExpoURLSessionTask) {
    if isInvalidState([.intialized]) {
      return
    }
    state = .started
  }

  func urlSession(_ session: ExpoURLSessionTask, didReceive response: URLResponse) {
    if isInvalidState([.started]) {
      return
    }
    responseInit = Self.createResponseInit(response: response)
    state = .responseReceived
  }

  func urlSession(_ session: ExpoURLSessionTask, didReceive data: Data) {
    if isInvalidState([.responseReceived, .bodyStreamingStarted, .bodyStreamingCancelled]) {
      return
    }

    if state == .responseReceived {
      self.ref.appendBufferBody(data: data)
    } else if state == .bodyStreamingStarted {
      emit(event: "didReceiveResponseData", arguments: data)
    }
    // no-op in .bodyStreamingCancelled state
  }

  func urlSession(_ session: ExpoURLSessionTask, didRedirect response: URLResponse) {
    redirected = true
  }

  func urlSession(_ session: ExpoURLSessionTask, didCompleteWithError error: (any Error)?) {
    if isInvalidState([.started, .responseReceived, .bodyStreamingStarted, .bodyStreamingCancelled]) {
      return
    }

    if state == .bodyStreamingStarted {
      if let error {
        emit(event: "didFailWithError", arguments: error.localizedDescription)
      } else {
        emit(event: "didComplete")
      }
    }

    if let error {
      self.error = error
      state = .errorReceived
    } else {
      state = .bodyCompleted
    }
  }
}

/**
 A data structure to store response body chunks
 */
internal final class ResponseSink {
  private var bodyQueue: [Data] = []
  private var isFinalized = false
  private(set) var bodyUsed = false

  fileprivate func appendBufferBody(data: Data) {
    bodyUsed = true
    bodyQueue.append(data)
  }

  func finalize() -> Data {
    let size = bodyQueue.reduce(0) { $0 + $1.count }
    var result = Data(capacity: size)
    while !bodyQueue.isEmpty {
      let data = bodyQueue.removeFirst()
      result.append(data)
    }
    bodyUsed = true
    isFinalized = true
    return result
  }
}

/**
 States represent for native response.
 */
internal enum ResponseState: Int {
  case intialized = 0
  case started
  case responseReceived
  case bodyCompleted
  case bodyStreamingStarted
  case bodyStreamingCancelled
  case errorReceived
}

/**
 Native data for ResponseInit.
 */
internal struct NativeResponseInit {
  let headers: [[String]]
  let status: Int
  let statusText: String
  let url: String
}
