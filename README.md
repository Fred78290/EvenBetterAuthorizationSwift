# EvenBetterAuthorizationSwift

A Swift / SwiftUI port of Apple's **EvenBetterAuthorizationSample**. It shows how to move privileged
operations out of an app and into a launchd-managed privileged helper tool, reached over
`NSXPCConnection` and guarded by Authorization Services rights.

Compared with Apple's original:

* All Objective-C is now Swift.
* The `.xib` windows are replaced by a SwiftUI `Window` scene.
* `SMJobBless` is replaced by `SMAppService`: the helper is a launch daemon whose plist is embedded
  in the app bundle, not copied into `/Library/PrivilegedHelperTools`.

Apple's original read-me is kept in [README-APPLE.md](README-APPLE.md) for background on the design.
Parts of it (SMJobBless, the removed `SMJobBlessUtil.py` script, OS X 10.8) no longer apply.

## Targets

| Target | Product | Bundle identifier | Purpose |
| --- | --- | --- | --- |
| `App` | `EvenBetterAuthorizationSample.app` | `com.aldunelabs.samplecode` | Standard app; talks to the helper directly. |
| `App-Sandboxed` | `EvenBetterAuthorizationSample-Sandboxed.app` | `com.aldunelabs.samplecode` | Sandboxed app; goes through the XPC service. |
| `XPCService` | `com.aldunelabs.caker.xpc.xpc` | `com.aldunelabs.samplecode.xpc` | Non-sandboxed service that connects to the helper and holds the authorization for the sandboxed app. |
| `Authorization` | `com.aldunelabs.caker.authorization` | `com.aldunelabs.samplecode.authorization` | The privileged helper tool (Mach service `com.aldunelabs.samplecode.authorization`). |
| `Tool` | `Tool` | `com.aldunelabs.samplecode.tool` | Command-line client (swift-argument-parser) for get-version, read-license and write-license. |

## Layout

```
App/                 standard app entry point + DirectHelperToolConnector
App-Sandboxed/       sandboxed app entry point + SandboxedHelperToolConnector
  XPCService/        XPC service and its protocol
AppShared/           SwiftUI ContentView, AuthorizationModel, AppDelegate (used by both apps)
Common/              HelperToolProtocol and authorization rights (shared with the helper)
HelperTool/          helper tool, its Info.plist, launchd plist and the daemon plist embedded in the app
Tool/                command-line client
```

The window has five buttons and a log:

| Button | What it does | Authorization right |
| --- | --- | --- |
| Install | Registers the daemon with `SMAppService`. | none |
| Get Version | Asks the helper for its version. | none |
| Read License | Reads the license key. | `readLicenseKey` (allowed for everyone) |
| Write License | Writes a new random license key. | `writeLicenseKey` (admin authentication) |
| Bind | Has the helper bind sockets to port 80 and pass them back. | `startWebService` (allowed for everyone) |

## Building

1. Open `EvenBetterAuthorizationSample.xcodeproj` in Xcode.
2. Select your own team and signing identity for each target. The project is currently set to the
   author's team (`LE7988HTRN`).
3. Update the `SMAuthorizedClients` requirements in `HelperTool/HelperTool-Info.plist` so they match
   your team and certificate. The helper only accepts clients that satisfy one of them.
4. Build and run the `App` scheme (or `App-Sandboxed`).

The helper is embedded in the app at `Contents/MacOS`, and the daemon plist at
`Contents/Library/LaunchDaemons`. The `App-Sandboxed` app also embeds the XPC service in
`Contents/XPCServices`.

## Running

1. Click **Install**. If the log shows an error and System Settings opens, enable the daemon under
   *General → Login Items & Extensions*, then click **Install** again.
2. Use **Get Version**, **Read License**, **Write License** and **Bind**. Results appear in the log.
3. Optionally use the `Tool` command-line client (built with swift-argument-parser) for the same requests:

   ```shell
   Tool get-version
   Tool read-license
   Tool write-license            # stores a new random UUID
   Tool write-license <uuid>     # stores the given UUID
   ```

   `write-license` needs administrator authentication, which may not be possible from a headless session.

The helper logs to `/var/log/ebas-helper.log`.

## Uninstalling

Run `./Uninstall.sh`. It stops the daemon (`launchctl bootout`), removes the three authorization
rights from the authorization database and deletes the stored license key. Then remove the app's
entry under *System Settings → General → Login Items & Extensions*, or run `sudo sfltool resetbtm`
to reset the whole background-items database.

## Credit

Based on Apple's EvenBetterAuthorizationSample (© 2013 Apple Inc.); see the license text at the top of
the files derived from it.
