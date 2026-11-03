//
//  XPCService.swift
//  Swift port of "XPCService.m" from Apple's EvenBetterAuthorizationSample.
//
//  The main object in the XPC service.  It's called by the XPC service's main.swift, but not by the
//  app directly.
//

import Foundation
import Security

final class XPCService: NSObject, NSXPCListenerDelegate, XPCServiceProtocol {

    private let listener: NSXPCListener
    private let authorization: Data?
    private var authRef: AuthorizationRef?
    private let queue: OperationQueue

    /// Only accessed or modified by operations on `queue`.
    private var helperToolConnection: NSXPCConnection?

    override init() {
        listener = NSXPCListener.service()      // this code must be run from an XPC service

        var ref: AuthorizationRef?
        var extForm = AuthorizationExternalForm()
        var err = AuthorizationCreate(nil, nil, [], &ref)
        if err == errAuthorizationSuccess, let ref {
            err = AuthorizationMakeExternalForm(ref, &extForm)
        }
        assert(err == errAuthorizationSuccess)
        authRef = ref
        authorization = err == errAuthorizationSuccess ? withUnsafeBytes(of: &extForm) { Data($0) } : nil

        queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1

        super.init()
        listener.delegate = self
    }

    deinit {
        if let authRef {
            _ = AuthorizationFree(authRef, [])
        }
    }

    func run() {
        listener.resume()       // never comes back
    }

    // MARK: NSXPCListenerDelegate

    /// Called by our XPC listener when a new connection comes in.  We configure the connection with
    /// our protocol and ourselves as the main object.
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: XPCServiceProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }

    // MARK: XPCServiceProtocol implementation

    func setupAuthorizationRights() {
        if let authRef {
            Common.setupAuthorizationRights(authRef)
        }
    }

    func connectWithEndpointAndAuthorizationReply(_ reply: @escaping @Sendable (NSXPCListenerEndpoint?, Data?) -> Void) {
        // Because we access helperToolConnection, we have to run on the operation queue.
        queue.addOperation { [self] in

            // Create our connection to the helper tool if it's not already in place.
            let connection: NSXPCConnection
            if let existing = helperToolConnection {
                connection = existing
            } else {
                connection = NSXPCConnection(machServiceName: kHelperToolMachServiceName, options: .privileged)
                connection.remoteObjectInterface = NSXPCInterface(with: HelperToolProtocol.self)
                connection.invalidationHandler = { [weak self, weak connection] in
                    // If the connection gets invalidated then, on our operation queue thread, nil out
                    // our reference to it.  This ensures that we attempt to rebuild it the next time around.
                    self?.queue.addOperation {
                        guard let self, self.helperToolConnection === connection else { return }
                        self.helperToolConnection = nil
                        NSLog("connection invalidated")
                    }
                }
                connection.resume()
                helperToolConnection = connection
            }

            // Call the helper tool to get the endpoint we need.
            let proxy = connection.remoteObjectProxyWithErrorHandler { proxyError in
                let error = proxyError as NSError
                NSLog("connect failed: %@ / %d", error.domain, Int32(error.code))
                reply(nil, nil)
            } as? HelperToolProtocol

            proxy?.connect(withEndpointReply: { [authorization] endpoint in
                reply(endpoint, authorization)
            })
        }
    }
}
