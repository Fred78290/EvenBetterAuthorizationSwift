//
//  Common.swift
//  Swift port of "Common.h" / "Common.m" from Apple's EvenBetterAuthorizationSample.
//
//  Code shared between app and helper tool.
//

import Foundation
import Security

enum Common {

    // commandInfo represents everything we need to know about the authorized commands supported by
    // the app.  Each key is the selector of the command.  The corresponding value contains three items:
    //
    // o authRightName is the name of the authorization right itself.  This is used by both the app
    //   (when creating rights and when pre-authorizing rights) and by the tool (when doing the final
    //   authorization check).
    //
    // o authRightDefault is the default right specification, used by the app when it needs to create
    //   the default right specification.  This is commonly a string containing a rule name, but it can
    //   potentially be more complex.  See the discussion of the rightDefinition parameter of
    //   AuthorizationRightSet.
    //
    // o authRightDescription is a user-visible description of the right.  This is used by the app when
    //   it needs to create the default right specification.  Actually, the string is used to look up
    //   a localized version of the string in "Common.strings".
    //
    //   The strings here contain EBAS as a shortcut for EvenBetterAuthorizationSample.  However, the
    //   values in "Common.strings" contain the fully expanded name, which allows you to see whether
    //   localization is working properly.
    //
    //   These strings are also surrounded by NSLocalizedString, which makes it easy to use
    //   genstrings to create an initial "Common.strings".

    private struct CommandInfo {
        let authRightName: String
        let authRightDefault: String
        let authRightDescription: String
    }

    private static let commandInfo: [Selector: CommandInfo] = [
        #selector(HelperToolProtocol.readLicenseKey(authorization:withReply:)): CommandInfo(
            authRightName: "com.aldunelabs.samplecode.authorization.readLicenseKey",
            authRightDefault: kAuthorizationRuleClassAllow,
            authRightDescription: NSLocalizedString(
                "EBAS is trying to read its license key.",
                comment: "prompt shown when user is required to authorize to read the license key"
            )
        ),
        #selector(HelperToolProtocol.writeLicenseKey(_:authorization:withReply:)): CommandInfo(
            authRightName: "com.aldunelabs.samplecode.authorization.writeLicenseKey",
            authRightDefault: kAuthorizationRuleAuthenticateAsAdmin,
            authRightDescription: NSLocalizedString(
                "EBAS is trying to write its license key.",
                comment: "prompt shown when user is required to authorize to write the license key"
            )
        ),
        #selector(HelperToolProtocol.bindToLowNumberPort(authorization:withReply:)): CommandInfo(
            authRightName: "com.aldunelabs.samplecode.authorization.startWebService",
            authRightDefault: kAuthorizationRuleClassAllow,
            authRightDescription: NSLocalizedString(
                "EBAS is trying to start its web service.",
                comment: "prompt shown when user is required to authorize to start the web service"
            )
        ),
    ]

    /// For a given command selector, returns the associated authorization right name.
    static func authorizationRight(for command: Selector) -> String? {
        commandInfo[command]?.authRightName
    }

    /// Sets up the default authorization rights in the authorization database.
    static func setupAuthorizationRights(_ authRef: AuthorizationRef) {
        for info in commandInfo.values {
            // First get the right.  If we get back errAuthorizationDenied that means there's
            // no current definition, so we add our default one.
            guard AuthorizationRightGet(info.authRightName, nil) == errAuthorizationDenied else {
                // A right already exists (err == noErr) or any other error occurs, we assume that it
                // has been set up in advance by the system administrator or this is the second time
                // we've run.  Either way, there's nothing more for us to do.
                continue
            }

            let err = AuthorizationRightSet(
                authRef,                            // authRef
                info.authRightName,                 // rightName
                info.authRightDefault as CFString,  // rightDefinition
                info.authRightDescription as CFString, // descriptionKey
                nil,                                // bundle (nil implies main bundle)
                "Common" as CFString                // localeTableName
            )
            assert(err == errAuthorizationSuccess)
        }
    }
}
