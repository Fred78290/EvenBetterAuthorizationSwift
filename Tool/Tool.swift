//
//  Tool.swift
//  Tool
//
//  Command-line client for the privileged helper tool.  It sends the same requests as the app's
//  buttons: get the helper's version, read the license key and write a new one.
//

import ArgumentParser
import Foundation
import Security

@main
struct ToolCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sampletool",
        abstract: "Talks to the EvenBetterAuthorization privileged helper tool.",
        subcommands: [GetVersion.self, ReadLicense.self, WriteLicense.self]
    )
}

extension ToolCommand {

    /// Returns the version number of the helper tool.  This never requires authorization.
    struct GetVersion: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "get-version",
            abstract: "Print the helper tool's version."
        )

        func run() throws {
            let client = try HelperToolClient()
            let version: String? = try client.perform { helperTool, done in
                helperTool.getVersion { done(.success($0)) }
            }
            print("version = \(version ?? "(none)")")
        }
    }

    /// Reads the license key.  By default this can be done by anyone.
    struct ReadLicense: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "read-license",
            abstract: "Print the license key stored by the helper tool."
        )

        func run() throws {
            let client = try HelperToolClient()
            let licenseKey: String? = try client.perform { helperTool, done in
                helperTool.readLicenseKey(authorization: client.authorization) { error, licenseKey in
                    if let error {
                        done(.failure(HelperToolError.helper(error)))
                    } else {
                        done(.success(licenseKey))
                    }
                }
            }
            print("license = \(licenseKey ?? "(none)")")
        }
    }

    /// Writes a license key.  By default this requires administrator authentication.
    struct WriteLicense: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "write-license",
            abstract: "Store a license key in the helper tool.",
            discussion: "The key must be a UUID.  When it is omitted a new random UUID is generated."
        )

        @Argument(help: "The license key (a UUID) to store.")
        var licenseKey: String?

        func validate() throws {
            if let licenseKey, UUID(uuidString: licenseKey) == nil {
                throw ValidationError("'\(licenseKey)' is not a valid UUID.")
            }
        }

        func run() throws {
            let licenseKey = licenseKey ?? UUID().uuidString
            let client = try HelperToolClient()
            let _: Void = try client.perform { helperTool, done in
                helperTool.writeLicenseKey(licenseKey, authorization: client.authorization) { error in
                    if let error {
                        done(.failure(HelperToolError.helper(error)))
                    } else {
                        done(.success(()))
                    }
                }
            }
            print("license = \(licenseKey)")
        }
    }
}

enum HelperToolError: Error, CustomStringConvertible {
    case authorization(String, OSStatus)
    case noProxy
    case connection(Error)
    case helper(NSError)
    case timeout

    var description: String {
        switch self {
        case .authorization(let what, let status): "\(what) failed: \(status)"
        case .noProxy: "unable to get helper tool proxy"
        case .connection(let error): "connection error: \(error)"
        case .helper(let error): "error \(error.domain) / \(error.code)"
        case .timeout: "timeout waiting for helper tool"
        }
    }
}

/// Holds the first result delivered, whichever thread it arrives on.
private final class ResultBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<T, Error>?

    func set(_ newResult: Result<T, Error>) {
        lock.lock()
        defer { lock.unlock() }
        if result == nil { result = newResult }
    }

    var value: Result<T, Error>? {
        lock.lock()
        defer { lock.unlock() }
        return result
    }
}

/// A connection to the helper tool plus the authorization to send with its requests.
final class HelperToolClient {
    let authorization: Data
    private let authRef: AuthorizationRef
    private let connection: NSXPCConnection

    init() throws {
        // Create the authorization reference and pass it to the helper tool in its external form,
        // exactly like the app does.
        var authRef: AuthorizationRef?
        var err = AuthorizationCreate(nil, nil, [], &authRef)
        guard err == errAuthorizationSuccess, let authRef else {
            throw HelperToolError.authorization("AuthorizationCreate", err)
        }

        var extForm = AuthorizationExternalForm()
        err = AuthorizationMakeExternalForm(authRef, &extForm)
        guard err == errAuthorizationSuccess else {
            AuthorizationFree(authRef, [])
            throw HelperToolError.authorization("AuthorizationMakeExternalForm", err)
        }

        self.authRef = authRef
        self.authorization = withUnsafeBytes(of: &extForm) { Data($0) }

        connection = NSXPCConnection(machServiceName: kHelperToolMachServiceName, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: HelperToolProtocol.self)
        connection.resume()
    }

    deinit {
        connection.invalidate()
        AuthorizationFree(authRef, [])
    }

    /// Sends one request to the helper tool and waits for its reply.
    func perform<T>(
        timeout: TimeInterval = 30,
        _ request: (HelperToolProtocol, @escaping @Sendable (Result<T, Error>) -> Void) -> Void
    ) throws -> T {
        let semaphore = DispatchSemaphore(value: 0)
        let box = ResultBox<T>()

        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            box.set(.failure(HelperToolError.connection(error)))
            semaphore.signal()
        } as? HelperToolProtocol
        guard let proxy else {
            throw HelperToolError.noProxy
        }

        request(proxy) { result in
            box.set(result)
            semaphore.signal()
        }

        guard semaphore.wait(timeout: .now() + timeout) == .success, let result = box.value else {
            throw HelperToolError.timeout
        }
        return try result.get()
    }
}
