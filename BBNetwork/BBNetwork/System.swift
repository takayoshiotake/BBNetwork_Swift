//
//  System.swift
//
//  Copyright © 2016 OTAKE Takayoshi. All rights reserved.
//

import Foundation

internal class System {
    #if os(OSX) || os(iOS)
    static let socket = Darwin.socket
    static let setsockopt = Darwin.setsockopt
    static let bind = Darwin.bind
    static let listen = Darwin.listen
    static let accept = Darwin.accept
    static let close = Darwin.close
    
    static let recv = Darwin.recv
    static let send = Darwin.send
    static let shutdown = Darwin.shutdown
    
    static let htons = {
        () -> ((UInt16) -> (UInt16)) in
        if OSHostByteOrder() == Int32(OSLittleEndian) {
            return _OSSwapInt16
        }
        else {
            return { $0 }
        }
    }()
    
    static let htonl = {
        () -> ((UInt32) -> (UInt32)) in
        if OSHostByteOrder() == Int32(OSLittleEndian) {
            return _OSSwapInt32
        }
        else {
            return { $0 }
        }
    }()
    
    static let ntohs = {
        () -> ((UInt16) -> (UInt16)) in
        if OSHostByteOrder() == Int32(OSLittleEndian) {
            return _OSSwapInt16
        }
        else {
            return { $0 }
        }
    }()
    #endif
}

internal let INADDR_ANY: UInt32 = 0
