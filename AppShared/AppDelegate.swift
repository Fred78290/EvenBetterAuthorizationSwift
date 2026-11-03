//
//  AppDelegate.swift
//
//  SwiftUI has no equivalent of -applicationShouldTerminateAfterLastWindowClosed:, so the apps keep a
//  tiny delegate around for that.
//

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
