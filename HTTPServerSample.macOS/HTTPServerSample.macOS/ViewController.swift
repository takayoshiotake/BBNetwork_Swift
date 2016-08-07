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
        httpServer = HTTPServer(tcpServer: TCPServer(supportedProtocol: .IPv6, port: 8080))
        httpServer.delegate = self
    }
    
    override var representedObject: AnyObject? {
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
            catch SocketServerErrorType.SystemError(let rawErrno) {
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
    
    func handleWebsocket(request: HTTPRequest, socket: HTTPSocket) {
        guard let secWebSoketVersion = request.headers["Sec-WebSocket-Version"], secWebSoketKey = request.headers["Sec-WebSocket-Key"] where secWebSoketVersion == "13" else {
            socket.close()
            return
        }
        
        let key = (secWebSoketKey + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").cStringUsingEncoding(NSUTF8StringEncoding)!
        let sha1Value = sha1(UnsafePointer(key), len: key.count - 1)
        let secWebSocketAccept = NSData(bytes: UnsafePointer(sha1Value), length: sha1Value.count).base64EncodedStringWithOptions(NSDataBase64EncodingOptions.Encoding64CharacterLineLength)
        
        let httpResponse = HTTPResponse(httpVersion: request.httpVersion, statusCode: HTTPStatusCode.WithRawValue(intValue: 101, reasonPhrase: "OK"), headers: [("Upgrade", "websocket"), ("Connection", "upgrade"), ("Sec-WebSocket-Accept", secWebSocketAccept)], body: nil)
        
        _ = try? socket.sendResponse(httpResponse)
        socket.close()
    }
    
    // MARK: -
    
    func httpServer(server: HTTPServer, didConnect socket: HTTPSocket) {
        do {
            if let request = try socket.readRequest() {
                if request.headers["Upgrade"] == "websocket" && request.headers["Connection"] == "Upgrade" {
                    handleWebsocket(request, socket: socket)
                    return
                }
                
                print("\(request)")
                
                let bodyText = "Hello, world!"
                let httpResponse = HTTPResponse(httpVersion: request.httpVersion, statusCode: .OK, headers: nil, body: [UInt8](bodyText.utf8))
                
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

private func gaiErrnoDescription(gaiErrno: Int32) -> String {
    return String.fromCString(Darwin.gai_strerror(gaiErrno))! + " (\(gaiErrno))"
}

private func errnoDescription(rawErrno: Int32) -> String {
    return String.fromCString(Darwin.strerror(rawErrno))! + " (\(rawErrno))"
}

