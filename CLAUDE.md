# CLAUDE.md

Swift / SwiftUI port of Apple's EvenBetterAuthorizationSample: an app that does privileged work through a
launchd helper tool over `NSXPCConnection`, guarded by Authorization Services rights. The helper is a launch
daemon registered with `SMAppService` (not `SMJobBless`). See [README.md](README.md) for the user-facing guide;
`README-APPLE.md` is Apple's original and partly outdated.

## Layout

- `Common/` — `HelperToolProtocol.swift` (the XPC protocol and Mach service name) and `Common.swift`
  (authorization rights table and setup). Shared by the app, the XPC service and the helper.
- `HelperTool/` — the privileged helper (`HelperTool.swift`, `main.swift`), its `Info.plist`, launchd plist, and
  the daemon plist embedded in the app (`com.aldunelabs.samplecode.authorization.plist`).
- `App/`, `App-Sandboxed/` — the two SwiftUI apps. Each has only an `@main` entry point and a connector
  (`DirectHelperToolConnector` / `SandboxedHelperToolConnector`).
- `App-Sandboxed/XPCService/` — non-sandboxed XPC service the sandboxed app uses to reach the helper.
- `AppShared/` — code used by both apps: `ContentView`, `AuthorizationModel` (button actions, `ConsoleLog`,
  `HelperToolConnector`), `AppDelegate`, `AboutCommands`.
- `Tool/` — command-line client built with swift-argument-parser (`get-version`, `read-license`, `write-license [key]`).
  Shares `Common/HelperToolProtocol.swift` with the other targets.

## Targets

`App`, `App-Sandboxed`, `XPCService` (product `com.aldunelabs.caker.xpc.xpc`) and `Authorization` (the helper,
product `com.aldunelabs.caker.authorization`, bundle id `com.aldunelabs.samplecode.authorization`), and `Tool`.
The project file is edited by hand; new Swift files must be added to the right targets in
`EvenBetterAuthorizationSample.xcodeproj/project.pbxproj` (no `xcodeproj` gem is installed).

## Build

Signing is manual and tied to the author's team, so build unsigned to check that code compiles:

```bash
xcodebuild -project EvenBetterAuthorizationSample.xcodeproj -scheme App -configuration Debug \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

Schemes: `App`, `App-Sandboxed`, `XPCService`, `Authorization`, `Tool`. There are no tests. Running the helper for
real needs a signed build, and the user must approve the daemon in System Settings → Login Items.

## Things to keep in sync

- The `@objc(...)` selector names in `HelperToolProtocol` / `XPCServiceProtocol` are the XPC wire format. Changing
  them breaks the app, XPC service, helper and the Tool unless all are updated together.
- `Common.commandInfo` keys are selectors of `HelperToolProtocol`; adding a command means adding a right there and
  a `checkAuthorization(_:command:)` call in the helper.
- The Mach service name `com.aldunelabs.samplecode.authorization` appears in `HelperToolProtocol.swift`,
  `HelperTool-Launchd.plist` and the embedded daemon plist.
- `SMAuthorizedClients` in `HelperTool/HelperTool-Info.plist` must match the signing identity or the helper rejects
  the app.
- The converted targets use `SWIFT_VERSION = 5.0`; XPC reply blocks are marked `@Sendable`.
- UI work stays in `AppShared/` so both apps get it; model code that touches the UI is `@MainActor`, and XPC reply
  closures hop back with `ConsoleLog.post(...)`.
