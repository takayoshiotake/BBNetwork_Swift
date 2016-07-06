//
//  TCPServer.swift
//
//  Copyright © 2016 OTAKE Takayoshi. All rights reserved.
//

import Foundation

public enum SocketServerErrorType: ErrorType {
    case GetAddrInfoError(gaiErrno: Int32)
    case SystemError(rawErrno: Int32)
}

public enum ServerSupportedProtocolType {
    case IPv4
    /// Also supports IPv4-mapped IPv6 address
    case IPv6
    case IPv6Only
}

extension ServerSupportedProtocolType {
    private var family: Int32 {
        switch self {
        case .IPv4:
            return AF_INET
        case .IPv6:
            fallthrough
        case .IPv6Only:
            return AF_INET6
        }
    }
}

public protocol TCPServerDelegate: class {
    func tcpServer(server: TCPServer, didError error: SocketServerErrorType)
    func tcpServer(server: TCPServer, didAcceptSocket socket: Socket)
}

public class TCPServer {
    
    public let protocolType: ServerSupportedProtocolType
    public let port: UInt16
  
    public weak var delegate: TCPServerDelegate?
    
    private let queue: dispatch_queue_t = dispatch_queue_create("AcceptQueue", DISPATCH_QUEUE_SERIAL)
    private var serverfd: Int32?
    
    public init(supportedProtocol: ServerSupportedProtocolType, port: UInt16) {
        self.protocolType = supportedProtocol
        self.port = port
    }
    
    public func start() throws {
        guard self.serverfd == nil else {
            return
        }
        
        let serverfd: Int32
        serverfd = System.socket(protocolType.family, SOCK_STREAM, IPPROTO_TCP)
        if serverfd == -1 {
            throw SocketServerErrorType.SystemError(rawErrno: errno)
        }
        do {
            var on: Int32 = 1
            if System.setsockopt(serverfd, SOL_SOCKET, SO_REUSEADDR, &on, socklen_t(sizeof(on.dynamicType))) == -1 {
                throw SocketServerErrorType.SystemError(rawErrno: errno)
            }
        }
        if protocolType == .IPv6Only {
            // The socket supports IPv6 only
            var on: Int32 = 1
            if System.setsockopt(serverfd, IPPROTO_IPV6, IPV6_V6ONLY, &on, socklen_t(sizeof(on.dynamicType))) == -1 {
                throw SocketServerErrorType.SystemError(rawErrno: errno)
            }
        }
        switch protocolType {
        case .IPv4:
            var addr = sockaddr_in()
            addr.sin_len = UInt8(sizeof(addr.dynamicType))
            addr.sin_family = UInt8(AF_INET)
            addr.sin_port = System.htons(port)
            addr.sin_addr.s_addr = in_addr_t(System.htonl(INADDR_ANY))
            addr.sin_zero = (0, 0, 0, 0, 0, 0, 0, 0)
            if System.bind(serverfd, unsafeCast(&addr), socklen_t(sizeof(addr.dynamicType))) == -1 {
                close(serverfd)
                throw SocketServerErrorType.SystemError(rawErrno: errno)
            }
            break
        case .IPv6:
            fallthrough
        case .IPv6Only:
            var addr = sockaddr_in6()
            addr.sin6_len = UInt8(sizeof(addr.dynamicType))
            addr.sin6_family = UInt8(AF_INET6)
            addr.sin6_port = System.htons(port)
            addr.sin6_flowinfo = 0  // TODO
            addr.sin6_addr = in6_addr() // TODO
            addr.sin6_scope_id = 0  // TODO
            if System.bind(serverfd, unsafeCast(&addr), socklen_t(sizeof(addr.dynamicType))) == -1 {
                System.close(serverfd)
                throw SocketServerErrorType.SystemError(rawErrno: errno)
            }
            break
        }
        if System.listen(serverfd, 100) == -1 {
            System.close(serverfd)
            throw SocketServerErrorType.SystemError(rawErrno: errno)
        }
        self.serverfd = serverfd
        print("started")
        switch protocolType {
        case .IPv4:
            startAcceptForIPv4()
            break
        case .IPv6:
            fallthrough
        case .IPv6Only:
            startAcceptForIPv6()
            break
        }
    }

    public func stop() {
        if let serverfd = serverfd {
            if System.close(serverfd) == -1 {
                print("close error: \(String.fromCString(strerror(errno))) (\(errno))")
            }
            self.serverfd = nil
            print("stopped")
        }
    }
    
    private func startAcceptForIPv4() {
        dispatch_async(queue) {
            [weak self] in
            if let weakSelf = self, serverfd = weakSelf.serverfd {
                var addr = sockaddr_in()
                var addrlen = socklen_t(sizeof(addr.dynamicType))
                let socketfd = System.accept(serverfd, unsafeCast(&addr), &addrlen)
                if socketfd == -1 {
                    let rawErrno = errno
                    guard rawErrno != ECONNABORTED else {
                        return
                    }
                    
                    if let delegate = weakSelf.delegate {
                        delegate.tcpServer(weakSelf, didError: SocketServerErrorType.SystemError(rawErrno: rawErrno))
                    }
                    weakSelf.startAcceptForIPv4()
                    return
                }
                
                let socket = Socket(socketfd: socketfd, addr: addr.addrDescription(), port: addr.port)
                if let delegate = weakSelf.delegate {
                    delegate.tcpServer(weakSelf, didAcceptSocket: socket)
                }
                else {
                    socket.close()
                }
                
                weakSelf.startAcceptForIPv4()
            }
        }
    }
    
    private func startAcceptForIPv6() {
        dispatch_async(queue) {
            [weak self] in
            if let weakSelf = self, serverfd = weakSelf.serverfd {
                var addr = sockaddr_in6()
                var addrlen = socklen_t(sizeof(addr.dynamicType))
                let socketfd = System.accept(serverfd, unsafeCast(&addr), &addrlen)
                if socketfd == -1 {
                    let rawErrno = errno
                    guard rawErrno != ECONNABORTED else {
                        return
                    }
                    
                    if let delegate = weakSelf.delegate {
                        delegate.tcpServer(weakSelf, didError: SocketServerErrorType.SystemError(rawErrno: rawErrno))
                    }
                    weakSelf.startAcceptForIPv6()
                    return
                }
                
                let socket = Socket(socketfd: socketfd, addr: addr.addrDescription(), port: addr.port)
                if let delegate = weakSelf.delegate {
                    delegate.tcpServer(weakSelf, didAcceptSocket: socket)
                }
                else {
                    socket.close()
                }
                socket.close()
                
                weakSelf.startAcceptForIPv6()
            }
        }
    }

}

private func unsafeCast<T, R>(value: UnsafePointer<T>) -> UnsafePointer<R> {
    return UnsafePointer<R>(value)
}

private func unsafeCast<T, R>(value: UnsafeMutablePointer<T>) -> UnsafeMutablePointer<R> {
    return UnsafeMutablePointer<R>(value)
}

extension sockaddr_in {
    private func addrDescription() -> String {
        var addrDescription = [CChar](count: Int(INET_ADDRSTRLEN), repeatedValue: 0)
        var sin_addr = self.sin_addr
        inet_ntop(AF_INET, &sin_addr, &addrDescription, socklen_t(INET_ADDRSTRLEN))
        return String.fromCString(addrDescription)!
    }
    
    private var port: UInt16 {
        return System.ntohs(sin_port)
    }
}

extension sockaddr_in6 {
    private func addrDescription() -> String {
        var addrDescription = [CChar](count: Int(INET6_ADDRSTRLEN), repeatedValue: 0)
        var sin6_addr = self.sin6_addr
        inet_ntop(AF_INET6, &sin6_addr, &addrDescription, socklen_t(INET6_ADDRSTRLEN))
        return String.fromCString(addrDescription)!
    }
    
    private var port: UInt16 {
        return System.ntohs(sin6_port)
    }
}

