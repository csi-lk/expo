// Copyright 2015-present 650 Industries. All rights reserved.

import ExpoModulesCore

internal class NetworkFetchUnknownException: Exception {
  override var reason: String {
    "Unknown error"
  }
}

internal class NetworkFetchRequestCanceledException: Exception {
  override var reason: String {
    "Fetch request has been canceled"
  }
}
