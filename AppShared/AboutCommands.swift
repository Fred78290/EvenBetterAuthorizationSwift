//
//  AboutCommands.swift
//
//  Replaces the standard "About" menu item so the About panel can credit the Swift/SwiftUI rewrite.
//

import SwiftUI

struct AboutCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About EvenBetterAuthorizationSample") {
                NSApplication.shared.orderFrontStandardAboutPanel(options: [
                    .credits: NSAttributedString(
                        string: "Rewritten in Swift and SwiftUI by Fred78290.\nCode converted from Objective-C to Swift by Claude.\nBased on Apple's EvenBetterAuthorizationSample.",
                        attributes: [
                            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                            .foregroundColor: NSColor.labelColor,
                        ]
                    ),
                ])
            }
        }
    }
}
