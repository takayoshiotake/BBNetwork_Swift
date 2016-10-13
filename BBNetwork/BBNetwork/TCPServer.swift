//
//  TCPServer.swift
//
//  Copyright © 2016 OTAKE Takayoshi. All rights reserved.
//

import Foundation

public enum SocketServerErrorType: Error {
    case getAddrInfoError(gaiErrno: Int32)
    case systemError(rawErrno: Int32)
}

public enum ServerSupportedProtocolType {
    case iPv4
    /// Also supports IPv4-mapped IPv6 address
    case iPv6
    case iPv6Only
}

extension ServerSupportedProtocolType {
    fileprivate var family: Int32 {
        switch self {
        case .iPv4:
            return AF_INET
        case .iPv6:
            fallthrough
        case .iPv6Only:
            return AF_INET6
        }
    }
}

public protocol TCPServerDelegate: class {
    func tcpServer(_ server: TCPServer, didError error: SocketServerErrorType)
    func tcpServer(_ server: TCPServer, didAcceptSocket socket: Socket)
}

open class TCPServer {
    
    open let protocolType: ServerSupportedProtocolType
    open let port: UInt16
  
    open weak var delegate: TCPServerDelegate?
    
    fileprivate let queue: DispatchQueue = DispatchQueue(label: "AcceptQueue", attributes: [])
    fileprivate var serverfd: Int32?
    
    public init(supportedProtocol: ServerSupportedProtocolType, port: UInt16) {
        self.protocolType = supportedProtocol
        self.port = port
    }
    
    open func start() throws {
        guard self.serverfd == nil else {
            return
        }
        
        let serverfd: Int32
        serverfd = System.socket(protocolType.family, SOCK_STREAM, IPPROTO_TCP)
        if serverfd == -1 {
            throw SocketServerErrorType.systemError(rawErrno: errno)
        }
        do {
            var on: Int32 = 1
            if System.setsockopt(serverfd, SOL_SOCKET, SO_REUSEADDR, &on, socklen_t(MemoryLayout<Int32>.size)) == -1 {
                throw SocketServerErrorType.systemError(rawErrno: errno)
            }
        }
        if protocolType == .iPv6Only {
            // The socket supports IPv6 only
            var on: Int32 = 1
            if System.setsockopt(serverfd, IPPROTO_IPV6, IPV6_V6ONLY, &on, socklen_t(MemoryLayout<Int32>.size)) == -1 {
                throw SocketServerErrorType.systemError(rawErrno: errno)
            }
        }
        switch protocolType {
        case .iPv4:
            var addr = sockaddr_in()
            addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            addr.sin_family = UInt8(AF_INET)
            addr.sin_port = System.htons(port)
            addr.sin_addr.s_addr = in_addr_t(System.htonl(INADDR_ANY))
            addr.sin_zero = (0, 0, 0, 0, 0, 0, 0, 0)
            if System.bind(serverfd, unsafePointerCast(&addr), socklen_t(MemoryLayout<sockaddr_in>.size)) == -1 {
                close(serverfd)
                throw SocketServerErrorType.systemError(rawErrno: errno)
            }
            break
        case .iPv6:
            fallthrough
        case .iPv6Only:
            var addr = sockaddr_in6()
            addr.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
            addr.sin6_family = UInt8(AF_INET6)
            addr.sin6_port = System.htons(port)
            addr.sin6_flowinfo = 0  // TODO
            addr.sin6_addr = in6_addr() // TODO
            addr.sin6_scope_id = 0  // TODO
            if System.bind(serverfd, unsafePointerCast(&addr), socklen_t(MemoryLayout<sockaddr_in6>.size)) == -1 {
                _ = System.close(serverfd)
                throw SocketServerErrorType.systemError(rawErrno: errno)
            }
            break
        }
        if System.listen(serverfd, 100) == -1 {
            _ = System.close(serverfd)
            throw SocketServerErrorType.systemError(rawErrno: errno)
        }
        self.serverfd = serverfd
        print("started")
        switch protocolType {
        case .iPv4:
            startAcceptForIPv4()
            break
        case .iPv6:
            fallthrough
        case .iPv6Only:
            startAcceptForIPv6()
            break
        }
    }

    open func stop() {
        if let serverfd = serverfd {
            if System.close(serverfd) == -1 {
                print("close error: \(String(cString: strerror(errno))) (\(errno))")
            }
            self.serverfd = nil
            print("stopped")
        }
    }
    
    fileprivate func startAcceptForIPv4() {
        queue.async {
            [weak self] in
            if let weakSelf = self, let serverfd = weakSelf.serverfd {
                var addr = sockaddr_in()
                var addrlen = socklen_t(MemoryLayout<sockaddr_in>.size)
                let socketfd = System.accept(serverfd, unsafePointerCast(&addr), &addrlen)
                if socketfd == -1 {
                    let rawErrno = errno
                    guard rawErrno != ECONNABORTED else {
                        return
                    }
                    
                    if let delegate = weakSelf.delegate {
                        delegate.tcpServer(weakSelf, didError: SocketServerErrorType.systemError(rawErrno: rawErrno))
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
    
    fileprivate func startAcceptForIPv6() {
        queue.async {
            [weak self] in
            if let weakSelf = self, let serverfd = weakSelf.serverfd {
                var addr = sockaddr_in6()
                var addrlen = socklen_t(MemoryLayout<sockaddr_in6>.size)
                let socketfd = System.accept(serverfd, unsafePointerCast(&addr), &addrlen)
                if socketfd == -1 {
                    let rawErrno = errno
                    guard rawErrno != ECONNABORTED else {
                        return
                    }
                    
                    if let delegate = weakSelf.delegate {
                        delegate.tcpServer(weakSelf, didError: SocketServerErrorType.systemError(rawErrno: rawErrno))
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

private func unsafePointerCast<R>(_ value: UnsafeRawPointer) -> UnsafePointer<R> {
    return value.bindMemory(to: R.self, capacity: 1)
}

private func unsafePointerCast<R>(_ value: UnsafeRawPointer) -> UnsafeMutablePointer<R> {
    return UnsafeMutablePointer(mutating: value.bindMemory(to: R.self, capacity: 1))
}

extension sockaddr_in {
    fileprivate func addrDescription() -> String {
        var addrDescription = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        var sin_addr = self.sin_addr
        inet_ntop(AF_INET, &sin_addr, &addrDescription, socklen_t(INET_ADDRSTRLEN))
        return String(cString: addrDescription)
    }
    
    fileprivate var port: UInt16 {
        return System.ntohs(sin_port)
    }
}

extension sockaddr_in6 {
    fileprivate func addrDescription() -> String {
        var addrDescription = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        var sin6_addr = self.sin6_addr
        inet_ntop(AF_INET6, &sin6_addr, &addrDescription, socklen_t(INET6_ADDRSTRLEN))
        return String(cString: addrDescription)
    }
    
    fileprivate var port: UInt16 {
        return System.ntohs(sin6_port)
    }
}

