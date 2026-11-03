//
//  main.swift
//  Swift port of "main.m" from Apple's EvenBetterAuthorizationSample.
//
//  XPC service main.
//

import Foundation

// We just create and start an instance of the main XPC service object and then
// have it resume the XPC service listener.
XPCService().run()          // This never comes back...
