//
//  HTTPServer.swift
//
//  Copyright © 2016 OTAKE Takayoshi. All rights reserved.
//

import Foundation

public protocol HTTPServerDelegate: class {
    func httpServer(_ server: HTTPServer, didConnect socket: HTTPSocket)
}

open class HTTPServer: TCPServerDelegate {
    fileprivate var tcpServer: TCPServer
    
    open var delegate: HTTPServerDelegate?
    
    public init(tcpServer: TCPServer) {
        self.tcpServer = tcpServer
        self.tcpServer.delegate = self
    }
    
    open func start() throws {
        try tcpServer.start()
    }
    
    open func stop() {
        tcpServer.stop()
    }
    
    fileprivate func communicate(_ socket: Socket) {
        if let delegate = delegate {
            delegate.httpServer(self, didConnect: HTTPSocket(socket: socket))
        }
        else {
            socket.close()
        }
    }
    
    // MARK: - TCPServerDelegate
    
    open func tcpServer(_ server: TCPServer, didAcceptSocket socket: Socket) {
        communicate(socket)
    }
    
    open func tcpServer(_ server: TCPServer, didError error: SocketServerErrorType) {
    }

}
