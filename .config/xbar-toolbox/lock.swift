import Foundation

// Private login.framework call; the same one used by the lock screen menu item.
guard let handle = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_NOW),
      let symbol = dlsym(handle, "SACLockScreenImmediate") else { exit(1) }

if CommandLine.arguments.contains("--check") { print("available"); exit(0) }

typealias LockScreen = @convention(c) () -> Void
unsafeBitCast(symbol, to: LockScreen.self)()
