//
//  Socket.swift
//
//  Copyright © 2016 OTAKE Takayoshi. All rights reserved.
//

import Foundation

public enum SocketErrorType: Error {
    case notConnectedError
    case systemError(rawErrno: Int32)
}

open class Socket: NSObject {
    fileprivate var socketfd: Int32?
    open let addr: String
    open let port: UInt16
    
    public init(socketfd: Int32, addr: String, port: UInt16) {
        self.socketfd = socketfd
        self.addr = addr
        self.port = port
    }
    
    open func recv(_ len: Int) throws -> ArraySlice<UInt8> {
        guard let socketfd = socketfd else {
            throw SocketErrorType.notConnectedError
        }
        
        var buffer: [UInt8] = [UInt8](repeating: 0, count: len)
        
        let recvlen = System.recv(socketfd, &buffer, len, 0)
        if recvlen == -1 {
            throw SocketErrorType.systemError(rawErrno: errno)
        }
        
        return buffer[0..<recvlen]
    }
    
    open func peek(_ len: Int) throws -> ArraySlice<UInt8> {
        guard let socketfd = socketfd else {
            throw SocketErrorType.notConnectedError
        }
        
        var buffer: [UInt8] = [UInt8](repeating: 0, count: len)
        
        let recvlen = System.recv(socketfd, &buffer, len, MSG_PEEK)
        if recvlen == -1 {
            throw SocketErrorType.systemError(rawErrno: errno)
        }
        
        return buffer[0..<recvlen]
    }
    
    open func send(_ data: [UInt8]) throws {
        guard let socketfd = socketfd else {
            throw SocketErrorType.notConnectedError
        }
        
        if System.send(socketfd, data, data.count, 0) == -1 {
            throw SocketErrorType.systemError(rawErrno: errno)
        }
    }
    
    open func close() {
        if let socketfd = socketfd {
            if System.shutdown(socketfd, SHUT_RDWR) == -1 {
                print("shutdown error: \(String(cString: strerror(errno))) (\(errno))")
            }
            if System.close(socketfd) == -1 {
                print("close error: \(String(cString: strerror(errno))) (\(errno))")
            }
            self.socketfd = nil
        }
    }
    
}
