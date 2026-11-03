//
//  XPCServiceProtocol.swift
//  Swift port of "XPCService.h" from Apple's EvenBetterAuthorizationSample.
//
//  When the app is sandboxed it can't install the helper tool or even talk to it directly.
//  In that case it uses a non-sandboxed XPC service to do that work.
//

import Foundation

let kXPCServiceName = "com.aldunelabs.samplecode.xpc"

@objc(XPCServiceProtocol)
protocol XPCServiceProtocol {

    /// Called by the app at startup time to set up our authorization rights in the authorization database.
    func setupAuthorizationRights()

    /// Called by the app to get an endpoint that's connected to the helper tool.  This also returns
    /// the XPC service's authorization reference so that the app can pass that to the requests it
    /// sends to the helper tool.  Without this authorization will fail because the app is sandboxed.
    func connectWithEndpointAndAuthorizationReply(_ reply: @escaping @Sendable (NSXPCListenerEndpoint?, Data?) -> Void)
}
