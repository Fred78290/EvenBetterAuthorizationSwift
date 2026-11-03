//
//  AuthorizationModel.swift
//  Swift port of the action methods of "AppDelegate.m" from Apple's EvenBetterAuthorizationSample.
//
//  Shared by the standard app and the sandboxed app; they only differ in how they reach the helper
//  tool, which is abstracted by `HelperToolConnector`.
//

import Foundation
import Observation
import ServiceManagement

/// The text shown in the window.
@MainActor
@Observable
final class ConsoleLog {
    private(set) var text = ""

    func append(_ string: String) {
        text += string
    }

    func append(error: Error) {
        let nsError = error as NSError
        append("error \(nsError.domain) / \(nsError.code)\n")
    }

    /// Logs from any thread.
    nonisolated func post(_ string: String) {
        Task { @MainActor in append(string) }
    }

    /// Logs an error from any thread.
    nonisolated func post(error: Error) {
        Task { @MainActor in append(error: error) }
    }
}

/// An established connection to the helper tool and the authorization to send with its requests.
struct HelperToolSession {
    let connection: NSXPCConnection
    let authorization: Data
}

/// Knows how to reach the helper tool.
@MainActor
protocol HelperToolConnector: AnyObject {
    /// Ensures that we're connected to our helper tool and then calls `completion` on the main actor
    /// with the session, or with an error if the connection could not be established.
    func connect(completion: @escaping @MainActor (Result<HelperToolSession, Error>) -> Void)
}

@MainActor
final class AuthorizationModel {
    let log: ConsoleLog
    private let connector: HelperToolConnector

    init(makeConnector: (ConsoleLog) -> HelperToolConnector) {
        let log = ConsoleLog()
        self.log = log
        self.connector = makeConnector(log)
    }

    /// Connects to the helper tool and then runs `command` on the main actor with a proxy for it.
    /// Note that if there is an error talking to the helper tool, it will be logged by the proxy's
    /// error handler.
    private func perform(_ command: @escaping @MainActor (HelperToolProtocol, Data) -> Void) {
        let log = log
        connector.connect { result in
            switch result {
            case .failure(let error):
                log.append(error: error)
            case .success(let session):
                let proxy = session.connection.remoteObjectProxyWithErrorHandler { error in
                    log.post(error: error)
                }
                if let helperTool = proxy as? HelperToolProtocol {
                    command(helperTool, session.authorization)
                }
            }
        }
    }

    /// Called when the user clicks the Install button.  This uses SMAppService (which replaces the
    /// deprecated SMJobBless) to register the launch daemon whose plist is embedded in the app's
    /// Contents/Library/LaunchDaemons directory.  It must run in the app itself (not the XPC service)
    /// because SMAppService looks in the main bundle.
    func install() {
        let service = SMAppService.daemon(plistName: "com.aldunelabs.samplecode.authorization.plist")
        do {
            try service.register()
            log.append("success\n")
        } catch {
            log.append(error: error)
            if service.status == .requiresApproval {
                // The user must approve the daemon in System Settings > General > Login Items.
                SMAppService.openSystemSettingsLoginItems()
            }
        }
    }

    /// Called when the user clicks the Get Version button.  This is the simplest form of
    /// NSXPCConnection request because it doesn't require any authorization.
    func getVersion() {
        let log = log
        perform { helperTool, _ in
            helperTool.getVersion { version in
                log.post("version = \(version ?? "(null)")\n")
            }
        }
    }

    /// Called when the user clicks the Read License button.  This is an example of an authorized
    /// command that, by default, can be done by anyone.
    func readLicense() {
        let log = log
        perform { helperTool, authorization in
            helperTool.readLicenseKey(authorization: authorization) { error, licenseKey in
                if let error {
                    log.post(error: error)
                } else {
                    log.post("license = \(licenseKey ?? "(null)")\n")
                }
            }
        }
    }

    /// Called when the user clicks the Write License button.  This is an example of an authorized
    /// command that, by default, can only be done by administrators.
    func writeLicense() {
        // Generate a new random license key so that we can see things change.
        let licenseKey = UUID().uuidString
        let log = log
        perform { helperTool, authorization in
            helperTool.writeLicenseKey(licenseKey, authorization: authorization) { error in
                if let error {
                    log.post(error: error)
                } else {
                    log.post("success\n")
                }
            }
        }
    }

    /// Called when the user clicks the Bind button.  This is an example of an authorized command
    /// that returns file descriptors.
    func bind() {
        let log = log
        perform { helperTool, authorization in
            helperTool.bindToLowNumberPort(authorization: authorization) { error, ipv4Handle, ipv6Handle in
                if let error {
                    log.post(error: error)
                } else if let ipv4Handle, let ipv6Handle {
                    // Each of these FileHandles has the close-on-dealloc flag set.  If we wanted to hold
                    // on to the underlying descriptor for a long time, we need to call dup2 on that
                    // descriptor to get our own descriptor that persists beyond the lifetime of the
                    // FileHandle.  In this example app, however, we just print the descriptors, which
                    // we can do without any complications.
                    log.post("IPv4 = \(ipv4Handle.fileDescriptor), IPv6 = \(ipv6Handle.fileDescriptor)\n")
                }
            }
        }
    }
}
