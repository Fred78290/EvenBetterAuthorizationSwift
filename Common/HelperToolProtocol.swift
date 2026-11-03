//
//  HelperToolProtocol.swift
//  Swift port of "HelperTool.h" from Apple's EvenBetterAuthorizationSample.
//
//  The NSXPCConnection-based protocol implemented by the helper tool and called by the app.
//

import Foundation

/// The Mach service name of the helper tool.  Note that the value here has to match the value in
/// the MachServices dictionary in "HelperTool-Launchd.plist".
let kHelperToolMachServiceName = "com.aldunelabs.samplecode.authorization"

/// The `@objc(...)` names and selectors below are the wire format of the XPC connection; they must
/// match between the app, the XPC service and the helper tool (and the subset declared in "Tool").
@objc(HelperToolProtocol)
protocol HelperToolProtocol {

    /// Not used by the standard app (it's part of the sandboxed XPC service support).
    @objc(connectWithEndpointReply:)
    func connect(withEndpointReply reply: @escaping @Sendable (NSXPCListenerEndpoint) -> Void)

    /// Returns the version number of the tool.  It's a good idea to include a command like this so
    /// you can handle app upgrades cleanly.
    @objc(getVersionWithReply:)
    func getVersion(withReply reply: @escaping @Sendable (String?) -> Void)

    // The next two commands imagine an app that needs to store a license key in some global location
    // that's not writable by all users; thus, setting the license key requires elevated privileges.
    // To manage this there's a 'read' command--which by default can be used by everyone--to return
    // the key and a 'write' command--which requires admin authentication--to set the key.

    /// Reads the current license key.  `authData` must be an AuthorizationExternalForm embedded in a Data.
    @objc(readLicenseKeyAuthorization:withReply:)
    func readLicenseKey(authorization authData: Data, withReply reply: @escaping @Sendable (NSError?, String?) -> Void)

    /// Writes a new license key.  `authData` must be an AuthorizationExternalForm embedded in a Data.
    @objc(writeLicenseKey:authorization:withReply:)
    func writeLicenseKey(_ licenseKey: String, authorization authData: Data, withReply reply: @escaping @Sendable (NSError?) -> Void)

    /// Imagines an app that contains an embedded web server.  A web server has to bind to port 80,
    /// which is a privileged operation.  This command lets the app request that the privileged helper
    /// tool create sockets bound to port 80 and then pass them back to the app, thereby minimising the
    /// amount of code that has to run with elevated privileges.  `authData` must be an
    /// AuthorizationExternalForm embedded in a Data and the sockets are returned wrapped up in FileHandles.
    @objc(bindToLowNumberPortAuthorization:withReply:)
    func bindToLowNumberPort(authorization authData: Data, withReply reply: @escaping @Sendable (NSError?, FileHandle?, FileHandle?) -> Void)
}
