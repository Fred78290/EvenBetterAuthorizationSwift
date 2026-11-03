//
//  DirectHelperToolConnector.swift
//  Swift port of the connection logic of "AppDelegate.m" from Apple's EvenBetterAuthorizationSample.
//
//  Used by the standard (non-sandboxed) app, which talks to the helper tool directly.
//

import Foundation
import Security

@MainActor
final class DirectHelperToolConnector: HelperToolConnector {
    private let log: ConsoleLog
    private var authorization = Data()
    private var connection: NSXPCConnection?

    init(log: ConsoleLog) {
        self.log = log

        // Create our connection to the authorization system.
        //
        // If we can't create an authorization reference then the app is not going to be able to do
        // anything requiring authorization.  Generally this only happens when you launch the app in
        // some wacky, and typically unsupported, way.  In the debug build we flag that with an assert.
        // In the release build we continue with an empty authorization, which will cause all
        // authorized operations to fail.
        var authRef: AuthorizationRef?
        var extForm = AuthorizationExternalForm()
        var err = AuthorizationCreate(nil, nil, [], &authRef)
        if err == errAuthorizationSuccess, let authRef {
            err = AuthorizationMakeExternalForm(authRef, &extForm)
        }
        if err == errAuthorizationSuccess {
            authorization = withUnsafeBytes(of: &extForm) { Data($0) }
        }
        assert(err == errAuthorizationSuccess)

        // If we successfully connected to Authorization Services, add definitions for our default
        // rights (unless they're already in the database).
        if let authRef {
            Common.setupAuthorizationRights(authRef)
        }
    }

    func connect(completion: @escaping @MainActor (Result<HelperToolSession, Error>) -> Void) {
        // Ensure that there's a helper tool connection in place.  Note that we never error in this case
        // because, if there is an error connecting to the helper tool, it will be delivered to the error
        // handler passed to remoteObjectProxyWithErrorHandler.
        let connection = self.connection ?? makeConnection()
        completion(.success(HelperToolSession(connection: connection, authorization: authorization)))
    }

    private func makeConnection() -> NSXPCConnection {
        let connection = NSXPCConnection(machServiceName: kHelperToolMachServiceName, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: HelperToolProtocol.self)
        connection.invalidationHandler = { [weak self, weak connection] in
            // If the connection gets invalidated then, on the main actor, nil out our reference to it.
            // This ensures that we attempt to rebuild it the next time around.
            Task { @MainActor in
                guard let self, self.connection === connection else { return }
                self.connection = nil
                self.log.append("connection invalidated\n")
            }
        }
        connection.resume()
        self.connection = connection
        return connection
    }
}
