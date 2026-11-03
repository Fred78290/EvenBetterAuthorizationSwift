//
//  EvenBetterAuthorizationSampleApp.swift
//
//  The sandboxed app's entry point, replacing "main.m", "AppDelegate" and "MainMenu.xib".
//

import SwiftUI

@main
struct EvenBetterAuthorizationSampleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AuthorizationModel { SandboxedHelperToolConnector(log: $0) }

    var body: some Scene {
        Window("EvenBetterAuthorizationSample", id: "main") {
            ContentView(model: model)
        }
        .defaultSize(width: 480, height: 315)
        .commands { AboutCommands() }
    }
}
