//
//  HelperTool.swift
//  Swift port of "HelperTool.m" from Apple's EvenBetterAuthorizationSample.
//
//  The main object in the helper tool.  It's called by the helper tool's main.swift, but not by the
//  app directly.
//

import Foundation
import Security

private let licenseKeyDefaultsKey = "licenseKey"

final class HelperTool: NSObject, NSXPCListenerDelegate, HelperToolProtocol {

    private let listener: NSXPCListener

	/// The code signing requirement of a client: one of the app's executables, signed by the helper's own team.
	private static let clientRequirement: String? = {
		var code: SecCode?
		var staticCode: SecStaticCode?
		var information: CFDictionary?

		guard SecCodeCopySelf([], &code) == errSecSuccess, let code, SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
			SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
			let team = (information as? [String: Any])?[kSecCodeInfoTeamIdentifier as String] as? String
		else {
			return nil
		}

		let identifiers = ["com.aldunelabs.samplecode", "com.aldunelabs.samplecode.tool", "com.aldunelabs.samplecode.xpc"]
			.map { "identifier \"\($0)\"" }
			.joined(separator: " or ")

		return "(\(identifiers)) and anchor apple generic and certificate leaf[subject.OU] = \"\(team)\""
	}()

	override init() {
        // Set up our XPC listener to handle requests on our Mach service.
        listener = NSXPCListener(machServiceName: kHelperToolMachServiceName)
        super.init()
        listener.delegate = self
    }

    /// Starts processing requests and runs the run loop forever.
    func run() -> Never {
        listener.resume()
        RunLoop.current.run()
        fatalError("the run loop should never return")
    }

    // MARK: NSXPCListenerDelegate

    /// Called by our XPC listener when a new connection comes in.  We configure the connection with
    /// our protocol and ourselves as the main object.
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
		// Only the app's own executables, signed by the same team as the helper, may talk to it. An ad-hoc signed build
		// (development) has no team to compare with: it is accepted, as the authorization rights still apply.
		if let requirement = Self.clientRequirement {
			newConnection.setCodeSigningRequirement(requirement)
		} else {
			NSLog("Helper is not signed by a team: XPC clients are not verified")
		}

		newConnection.exportedInterface = NSXPCInterface(with: HelperToolProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }

    // MARK: Helpers

    /// Checks that the client denoted by `authData` is allowed to run the specified command.
    /// `authData` is expected to be a Data with an AuthorizationExternalForm embedded inside.
    private func checkAuthorization(_ authData: Data, command: Selector) -> NSError? {
        // First check that authData looks reasonable.
        guard authData.count == MemoryLayout<AuthorizationExternalForm>.size,
              let rightName = Common.authorizationRight(for: command) else {
            return NSError(domain: NSOSStatusErrorDomain, code: Int(paramErr))
        }

        // Create an authorization ref from the external form data contained within.
        var authRef: AuthorizationRef?
        var err = authData.withUnsafeBytes { buffer in
            AuthorizationCreateFromExternalForm(buffer.baseAddress!.assumingMemoryBound(to: AuthorizationExternalForm.self), &authRef)
        }
        defer {
            if let authRef {
                let junk = AuthorizationFree(authRef, [])
                assert(junk == errAuthorizationSuccess)
            }
        }

        // Authorize the right associated with the command.
        if err == errAuthorizationSuccess, let authRef {
            err = rightName.withCString { name in
                var oneRight = AuthorizationItem(name: name, valueLength: 0, value: nil, flags: 0)
                return withUnsafeMutablePointer(to: &oneRight) { items in
                    var rights = AuthorizationRights(count: 1, items: items)
                    return AuthorizationCopyRights(authRef, &rights, nil, [.extendRights, .interactionAllowed], nil)
                }
            }
        }

        return err == errAuthorizationSuccess ? nil : NSError(domain: NSOSStatusErrorDomain, code: Int(err))
    }

    /// Checks that the license key is valid.  There are two things to note here.  The first is that
    /// I could have just passed a UUID across the NSXPCConnection, because UUID supports the
    /// NSSecureCoding protocol.  I didn't do that, however, because I wanted to make an important
    /// point, and that brings us to our second thing.  When you're writing a privileged helper tool
    /// you have to make sure that all the data passed to you from the client is valid.
    /// NSXPCConnection does a lot of checking of this for you, but you still have to check your
    /// app-specific requirements.
    ///
    /// In this case the app-specific requirement is very simple--can it be parsed as a UUID
    /// string--but in a complex app they might be a lot more complex.  Regardless, it's vital that
    /// you do this checking for all data coming from untrusted sources.
    private func isValidLicenseKey(_ licenseKey: String) -> Bool {
        UUID(uuidString: licenseKey) != nil
    }

    /// Creates a TCP socket of the given family bound to port 80.  The caller owns the descriptor.
    private func makeSocketBoundToPort80(family: Int32) throws -> Int32 {
        let fd = socket(family, SOCK_STREAM, 0)
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }

        var one: Int32 = 1
        var bound = setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, socklen_t(MemoryLayout<Int32>.size)) == 0
        if bound {
            if family == AF_INET {
                var addr = sockaddr_in()
                addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
                addr.sin_family = sa_family_t(AF_INET)
                addr.sin_port = UInt16(80).bigEndian
                bound = withUnsafePointer(to: &addr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
                } == 0
            } else {
                var addr = sockaddr_in6()
                addr.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
                addr.sin6_family = sa_family_t(AF_INET6)
                addr.sin6_port = UInt16(80).bigEndian
                bound = withUnsafePointer(to: &addr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in6>.size)) }
                } == 0
            }
        }
        guard bound else {
            let code = errno
            close(fd)
            throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
        }
        return fd
    }

    // MARK: HelperToolProtocol implementation

    // IMPORTANT: NSXPCConnection can call these methods on any thread.  It turns out that our
    // implementation of these methods is thread safe but if that's not the case for your code
    // you have to implement your own protection (for example, having your own serial queue and
    // dispatching over to it).

    /// Called by the XPC service to get an endpoint for our listener.  It then passes this endpoint
    /// to the app so that the sandboxed app can talk to us directly.
    func connect(withEndpointReply reply: @escaping @Sendable (NSXPCListenerEndpoint) -> Void) {
        reply(listener.endpoint)
    }

    /// Returns the version number of the tool.  Note that this never requires authorization.
    func getVersion(withReply reply: @escaping @Sendable (String?) -> Void) {
        // We specifically don't check for authorization here.  Everyone is always allowed to get
        // the version of the helper tool.
        reply(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
    }

    /// Gets the current license key from the defaults database.
    func readLicenseKey(authorization authData: Data, withReply reply: @escaping @Sendable (NSError?, String?) -> Void) {
        let error = checkAuthorization(authData, command: #selector(HelperToolProtocol.readLicenseKey(authorization:withReply:)))
        let licenseKey = error == nil ? UserDefaults.standard.string(forKey: licenseKeyDefaultsKey) : nil
        reply(error, licenseKey)
    }

    /// Saves the license key to the defaults database.
    func writeLicenseKey(_ licenseKey: String, authorization authData: Data, withReply reply: @escaping @Sendable (NSError?) -> Void) {
        var error: NSError?
        if !isValidLicenseKey(licenseKey) {
            error = NSError(domain: NSOSStatusErrorDomain, code: Int(paramErr))
        }
        if error == nil {
            error = checkAuthorization(authData, command: #selector(HelperToolProtocol.writeLicenseKey(_:authorization:withReply:)))
        }
        if error == nil {
            UserDefaults.standard.set(licenseKey, forKey: licenseKeyDefaultsKey)
        }
        reply(error)
    }

    /// Binds two sockets (TCPv4 and TCPv6) to port 80 and returns a reference to them to the client.
    /// Note that we just create and bind the sockets and nothing else.  This minimizes the amount of
    /// code that we have to run with elevated privileges.  We return these sockets to the app, which
    /// then listens for, accepts, and manages incoming connections.
    func bindToLowNumberPort(authorization authData: Data, withReply reply: @escaping @Sendable (NSError?, FileHandle?, FileHandle?) -> Void) {
        var fd4: Int32 = -1
        var fd6: Int32 = -1
        var failure = checkAuthorization(authData, command: #selector(HelperToolProtocol.bindToLowNumberPort(authorization:withReply:)))
        var ipv4Handle: FileHandle?
        var ipv6Handle: FileHandle?

        if failure == nil {
            do {
                fd4 = try makeSocketBoundToPort80(family: AF_INET)
                fd6 = try makeSocketBoundToPort80(family: AF_INET6)
                ipv4Handle = FileHandle(fileDescriptor: fd4, closeOnDealloc: false)
                ipv6Handle = FileHandle(fileDescriptor: fd6, closeOnDealloc: false)
            } catch let posixError as POSIXError {
                failure = NSError(domain: NSPOSIXErrorDomain, code: Int(posixError.code.rawValue))
            } catch {
                failure = NSError(domain: NSPOSIXErrorDomain, code: Int(EIO))
            }
        }

        assert((failure == nil) == (ipv4Handle != nil))
        assert((failure == nil) == (ipv6Handle != nil))
        reply(failure, ipv4Handle, ipv6Handle)

        // The descriptors have been sent to the client (or we failed part way through); either way
        // we don't need ours any more.
        if fd4 != -1 { close(fd4) }
        if fd6 != -1 { close(fd6) }
    }
}
