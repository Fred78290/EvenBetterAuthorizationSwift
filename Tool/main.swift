//
//  main.swift
//  Tool
//
//  Created by Frederic BOLTZ on 03/11/2026.
//

import Foundation
import Security

// Same Mach service name as kHelperToolMachServiceName in HelperTool.h.
let helperToolMachServiceName = "com.aldunelabs.samplecode.authorization"

// Subset of HelperToolProtocol (HelperTool.h) needed by this tool.  XPC only matches
// selectors and signatures, so declaring just the command we call is enough.
@objc(HelperToolProtocol)
protocol HelperToolProtocol {
    @objc(readLicenseKeyAuthorization:withReply:)
    func readLicenseKey(authorization authData: Data, withReply reply: @escaping (NSError?, String?) -> Void)
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

// Create the authorization reference and pass it to the helper tool in its external form,
// exactly like the app does.
var authRef: AuthorizationRef?
var err = AuthorizationCreate(nil, nil, [], &authRef)
guard err == errAuthorizationSuccess, let authRef else {
    fail("AuthorizationCreate failed: \(err)")
}

var extForm = AuthorizationExternalForm()
err = AuthorizationMakeExternalForm(authRef, &extForm)
guard err == errAuthorizationSuccess else {
    fail("AuthorizationMakeExternalForm failed: \(err)")
}
let authData = withUnsafeBytes(of: &extForm) { Data($0) }

// Connect to the helper tool.
let connection = NSXPCConnection(machServiceName: helperToolMachServiceName, options: .privileged)
connection.remoteObjectInterface = NSXPCInterface(with: HelperToolProtocol.self)
connection.resume()

let semaphore = DispatchSemaphore(value: 0)
var exitCode: Int32 = 0

let proxy = connection.remoteObjectProxyWithErrorHandler { error in
    FileHandle.standardError.write(Data("connection error: \(error)\n".utf8))
    exitCode = 1
    semaphore.signal()
} as? HelperToolProtocol

guard let proxy else {
    fail("unable to get helper tool proxy")
}

proxy.readLicenseKey(authorization: authData) { error, licenseKey in
    if let error {
        FileHandle.standardError.write(Data("error \(error.domain) / \(error.code)\n".utf8))
        exitCode = 1
    } else {
        print("license = \(licenseKey ?? "(none)")")
    }
    semaphore.signal()
}

if semaphore.wait(timeout: .now() + 30) == .timedOut {
    FileHandle.standardError.write(Data("timeout waiting for helper tool\n".utf8))
    exitCode = 1
}

connection.invalidate()
AuthorizationFree(authRef, [])
exit(exitCode)
