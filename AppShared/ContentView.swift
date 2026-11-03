//
//  ContentView.swift
//
//  The main window, replacing the window of "MainMenu.xib": a row of buttons and a log view.
//

import SwiftUI

struct ContentView: View {
    let model: AuthorizationModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button("Install") { model.install() }
                Button("Get Version") { model.getVersion() }
                Button("Read License") { model.readLicense() }
                Button("Write License") { model.writeLicense() }
                Button("Bind") { model.bind() }
            }

            LogView(log: model.log)
        }
        .padding()
        .frame(minWidth: 480, minHeight: 315)
    }
}

private struct LogView: View {
    let log: ConsoleLog

    var body: some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(log.text)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(6)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .border(Color(nsColor: .separatorColor))
            .onChange(of: log.text) {
                scroll.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
}
