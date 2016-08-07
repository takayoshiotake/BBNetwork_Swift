//
//  HTTPServer.swift
//
//  Copyright © 2016 OTAKE Takayoshi. All rights reserved.
//

import Foundation

public protocol HTTPServerDelegate: class {
    func httpServer(server: HTTPServer, didConnect socket: HTTPSocket)
}

public class HTTPServer: TCPServerDelegate {
    private var tcpServer: TCPServer
    
    public var delegate: HTTPServerDelegate?
    
    public init(tcpServer: TCPServer) {
        self.tcpServer = tcpServer
        self.tcpServer.delegate = self
    }
    
    public func start() throws {
        try tcpServer.start()
    }
    
    public func stop() {
        tcpServer.stop()
    }
    
    private func communicate(socket: Socket) {
        if let delegate = delegate {
            delegate.httpServer(self, didConnect: HTTPSocket(socket: socket))
        }
        else {
            socket.close()
        }
    }
    
    // MARK: - TCPServerDelegate
    
    public func tcpServer(server: TCPServer, didAcceptSocket socket: Socket) {
        communicate(socket)
    }
    
    public func tcpServer(server: TCPServer, didError error: SocketServerErrorType) {
    }

}
