//
//  Socket.swift
//
//  Copyright © 2016 OTAKE Takayoshi. All rights reserved.
//

import Foundation

public enum SocketErrorType: ErrorType {
    case NotConnectedError
    case SystemError(rawErrno: Int32)
}

public class Socket: NSObject {
    private var socketfd: Int32?
    public let addr: String
    public let port: UInt16
    
    public init(socketfd: Int32, addr: String, port: UInt16) {
        self.socketfd = socketfd
        self.addr = addr
        self.port = port
    }
    
    public func recv(len: Int) throws -> ArraySlice<UInt8> {
        guard let socketfd = socketfd else {
            throw SocketErrorType.NotConnectedError
        }
        
        var buffer: [UInt8] = [UInt8](count: len, repeatedValue: 0)
        
        let recvlen = System.recv(socketfd, &buffer, len, 0)
        if recvlen == -1 {
            throw SocketErrorType.SystemError(rawErrno: errno)
        }
        
        return buffer[0..<recvlen]
    }
    
    public func peek(len: Int) throws -> ArraySlice<UInt8> {
        guard let socketfd = socketfd else {
            throw SocketErrorType.NotConnectedError
        }
        
        var buffer: [UInt8] = [UInt8](count: len, repeatedValue: 0)
        
        let recvlen = System.recv(socketfd, &buffer, len, MSG_PEEK)
        if recvlen == -1 {
            throw SocketErrorType.SystemError(rawErrno: errno)
        }
        
        return buffer[0..<recvlen]
    }
    
    public func send(data: [UInt8]) throws {
        guard let socketfd = socketfd else {
            throw SocketErrorType.NotConnectedError
        }
        
        if System.send(socketfd, data, data.count, 0) == -1 {
            throw SocketErrorType.SystemError(rawErrno: errno)
        }
    }
    
    public func close() {
        if let socketfd = socketfd {
            if System.shutdown(socketfd, SHUT_RDWR) == -1 {
                print("shutdown error: \(String.fromCString(strerror(errno))) (\(errno))")
            }
            if System.close(socketfd) == -1 {
                print("close error: \(String.fromCString(strerror(errno))) (\(errno))")
            }
            self.socketfd = nil
        }
    }
    
}
