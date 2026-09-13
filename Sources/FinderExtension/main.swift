// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools contributors

import Foundation

// An app extension hands its process to Foundation's extension runtime, which
// loads the principal class named in Info.plist and serves Finder's requests.
// Xcode links extensions with this entry point; build.sh compiles with plain
// swiftc, so the call is spelled out here.
@_silgen_name("NSExtensionMain")
private func extensionMain(_ argc: Int32,
                           _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> Int32

exit(extensionMain(CommandLine.argc, CommandLine.unsafeArgv))
