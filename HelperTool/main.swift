//
//  main.swift
//  Swift port of "main.m" from Apple's EvenBetterAuthorizationSample.
//
//  Privileged helper tool main.
//

import Foundation

// We just create and start an instance of the main helper tool object and then
// have it run the run loop forever.
NSLog("Starting EBAS helper tool...")
HelperTool().run()      // This never comes back...
