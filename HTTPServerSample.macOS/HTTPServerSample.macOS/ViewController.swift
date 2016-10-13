//
//  ViewController.swift
//  HTTPServerSample.macOS
//
//  Copyright © 2016 OTAKE Takayoshi. All rights reserved.
//

import Cocoa
import BBNetwork

class ViewController: NSViewController, HTTPServerDelegate {
    
    var appears: Bool = false {
        didSet {
            didChangeViewControllerStatus()
        }
    }
    
    var httpServer: HTTPServer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        httpServer = HTTPServer(tcpServer: TCPServer(supportedProtocol: .iPv6, port: 8080))
        httpServer.delegate = self
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        appears = true
    }
    
    override func viewWillDisappear() {
        appears = false
        super.viewWillDisappear()
    }
    
    // MARK: -
    
    func didChangeViewControllerStatus() {
        if appears {
            do {
                try httpServer.start()
            }
            catch SocketServerErrorType.systemError(let rawErrno) {
                print("System error: \(errnoDescription(rawErrno))")
            }
            catch let error {
                print("\(error)")
            }
        }
        else {
            httpServer.stop()
        }
    }
    
    // MARK: -
    
    func handleWebsocket(_ request: HTTPRequest, socket: HTTPSocket) {
        guard let secWebSoketVersion = request.headers["Sec-WebSocket-Version"], let secWebSoketKey = request.headers["Sec-WebSocket-Key"] , secWebSoketVersion == "13" else {
            socket.close()
            return
        }
        
        let key = (secWebSoketKey + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").cString(using: .utf8)!
        let sha1Value = sha1(unsafePointerCast(key), len: key.count - 1)
        let secWebSocketAccept = Data(bytes: UnsafePointer(sha1Value), count: sha1Value.count).base64EncodedString(options: .lineLength64Characters)
        
        let httpResponse = HTTPResponse(httpVersion: request.httpVersion, statusCode: HTTPStatusCode.withRawValue(intValue: 101, reasonPhrase: "OK"), headers: [("Upgrade", "websocket"), ("Connection", "upgrade"), ("Sec-WebSocket-Accept", secWebSocketAccept)], body: nil)
        
        _ = try? socket.sendResponse(httpResponse)
        
        // DEBUG:
        while true {
            do {
                let head = try socket.rawSocket.recv(2)
                if head.count == 0 {
                    break
                }
                
                let isFinalFragment = head[0] >> 7 != 0
                let reserved = (head[0] >> 4) & 0x3
                if reserved != 0 {
                    break
                }
                let opcode = head[0] & 0xF
                print("WebSocket: opcode=\(opcode)")
                var payload: [UInt8] = []
                if head.count >= 2 {
                    let isMasked = head[1] >> 7 != 0
                    if !isMasked {
                        // All frames sent from client to server must be masked
                        break
                    }
                    var payloadLength = Int(head[1] & 0x7F)
                    switch payloadLength {
                    case 126:
                        // TODO:
                        break
                    case 127:
                        // TODO:
                        break
                    default:
                        // Nothing to do
                        break
                    }
                    
                    let maskingKey = try socket.rawSocket.recv(4)
                    if maskingKey.count != 4 {
                        break
                    }
                    
                    if payloadLength > 0 {
                        let maskedPayload = try socket.rawSocket.recv(payloadLength)
                        payload = [UInt8](repeating: 0, count: payloadLength)
                        for pi in 0..<payloadLength {
                            payload[pi] = maskedPayload[pi] ^ maskingKey[pi % 4]
                        }
                    }
                }
                
                if opcode == 1 {
                    // Data frame as UTF-8 text
                    if let text = String(bytes: payload, encoding: String.Encoding.utf8) {
                        print("text=\(text)")
                    }
                }
                else if opcode == 8 {
                    // Close frame
                    break
                }
            }
            catch let error {
                print("\(error)")
                break
            }
        }
        
        socket.close()
    }
    
    // MARK: -
    
    func httpServer(_ server: HTTPServer, didConnect socket: HTTPSocket) {
        do {
            if let request = try socket.readRequest() {
                if request.headers["Upgrade"] == "websocket" && request.headers["Connection"] == "Upgrade" {
                    handleWebsocket(request, socket: socket)
                    return
                }
                
                print("\(request)")
                
                let bodyText = "Hello, world!"
                let httpResponse = HTTPResponse(httpVersion: request.httpVersion, statusCode: .ok, headers: nil, body: [UInt8](bodyText.utf8))
                
                try socket.sendResponse(httpResponse)
            }
            socket.close()
        }
        catch let error {
            print("\(error)")
            socket.close()
        }
    }
    
}

private func unsafePointerCast<R>(_ value: UnsafeRawPointer) -> UnsafePointer<R> {
    return value.bindMemory(to: R.self, capacity: 1)
}

private func gaiErrnoDescription(_ gaiErrno: Int32) -> String {
    return String(cString: Darwin.gai_strerror(gaiErrno)) + " (\(gaiErrno))"
}

private func errnoDescription(_ rawErrno: Int32) -> String {
    return String(cString: Darwin.strerror(rawErrno)) + " (\(rawErrno))"
}

