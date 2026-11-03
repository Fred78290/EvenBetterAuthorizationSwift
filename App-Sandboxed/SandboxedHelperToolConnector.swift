//
//  SandboxedHelperToolConnector.swift
//  Swift port of the connection logic of "AppDelegate.m" from Apple's EvenBetterAuthorizationSample.
//
//  Used by the sandboxed app, which can't talk to the helper tool (or use Authorization Services)
//  directly.  Instead it asks a non-sandboxed XPC service for an endpoint connected to the helper tool,
//  plus the XPC service's authorization to send with its requests.
//

import Foundation

@MainActor
final class SandboxedHelperToolConnector: HelperToolConnector {
    private let log: ConsoleLog
    private var xpcServiceConnection: NSXPCConnection?
    private var helperToolConnection: NSXPCConnection?
    private var authorization = Data()

    init(log: ConsoleLog) {
        self.log = log

        // Get our XPC service to add definitions for our default rights (unless they're already in
        // the database).
        (connectToXPCService().remoteObjectProxy as? XPCServiceProtocol)?.setupAuthorizationRights()
    }

    func connect(completion: @escaping @MainActor (Result<HelperToolSession, Error>) -> Void) {
        if let helperToolConnection {
            // The helper tool connection is already in place, so we can just complete directly.
            completion(.success(HelperToolSession(connection: helperToolConnection, authorization: authorization)))
            return
        }

        // There's no helper tool connection in place.  Create an XPC service connection and ask it to
        // give us an endpoint for the helper tool.
        let proxy = connectToXPCService().remoteObjectProxyWithErrorHandler { error in
            Task { @MainActor in completion(.failure(error)) }
        } as? XPCServiceProtocol

        proxy?.connectWithEndpointAndAuthorizationReply { endpoint, authorization in
            Task { @MainActor in
                guard let endpoint else {
                    completion(.failure(NSError(domain: NSPOSIXErrorDomain, code: Int(ENOTTY))))
                    return
                }

                // The XPC service gave us an endpoint for the helper tool.  Create a connection from that.
                // Also, save the authorization information returned by the XPC service so that the command
                // can send requests that act like they're coming from the XPC service (which is allowed to
                // use authorization services) and not the app (which isn't, 'cause it's sandboxed).
                //
                // It's important to realize that helperToolConnection could be non-nil here because some
                // other command has connected ahead of us.  That's OK though, we just ignore the new
                // endpoint and keep using the helper tool connection that's in place.
                let connection = self.helperToolConnection ?? self.makeHelperToolConnection(endpoint: endpoint)
                self.authorization = authorization ?? Data()
                completion(.success(HelperToolSession(connection: connection, authorization: self.authorization)))
            }
        }
    }

    /// Ensures that we're connected to our XPC service.
    private func connectToXPCService() -> NSXPCConnection {
        if let xpcServiceConnection {
            return xpcServiceConnection
        }
        let connection = NSXPCConnection(serviceName: kXPCServiceName)
        connection.remoteObjectInterface = NSXPCInterface(with: XPCServiceProtocol.self)
        connection.invalidationHandler = { [weak self, weak connection] in
            // If the connection gets invalidated then, on the main actor, nil out our reference to it.
            // This ensures that we attempt to rebuild it the next time around.
            Task { @MainActor in
                guard let self, self.xpcServiceConnection === connection else { return }
                self.xpcServiceConnection = nil
                self.log.append("connection invalidated\n")
            }
        }
        connection.resume()
        xpcServiceConnection = connection
        return connection
    }

    private func makeHelperToolConnection(endpoint: NSXPCListenerEndpoint) -> NSXPCConnection {
        let connection = NSXPCConnection(listenerEndpoint: endpoint)
        connection.remoteObjectInterface = NSXPCInterface(with: HelperToolProtocol.self)
        connection.invalidationHandler = { [weak self, weak connection] in
            Task { @MainActor in
                guard let self, self.helperToolConnection === connection else { return }
                self.helperToolConnection = nil
                self.log.append("connection invalidated\n")
            }
        }
        connection.resume()
        helperToolConnection = connection
        return connection
    }
}
