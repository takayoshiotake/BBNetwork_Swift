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
    
    func handleWebsocket(httpRequest: HTTPRequest, connection: HTTPConnection) {
        guard let secWebSoketVersion = httpRequest.requestHeaders["Sec-WebSocket-Version"], secWebSoketKey = httpRequest.requestHeaders["Sec-WebSocket-Key"] where secWebSoketVersion == "13" else {
            connection.close()
            return
        }
        
        let key = (secWebSoketKey + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").cStringUsingEncoding(NSUTF8StringEncoding)!
        let sha1Value = sha1(UnsafePointer(key), len: key.count - 1)
        let secWebSocketAccept = NSData(bytes: UnsafePointer(sha1Value), length: sha1Value.count).base64EncodedStringWithOptions(NSDataBase64EncodingOptions.Encoding64CharacterLineLength)
        
        let httpResponse = HTTPResponse(httpVersion: httpRequest.httpVersion, statusCode: HTTPStatusCode.WithRawValue(intValue: 101, reasonPhrase: "OK"), responseHeaders: [("Upgrade", "websocket"), ("Connection", "upgrade"), ("Sec-WebSocket-Accept", secWebSocketAccept)], body: nil)
        
        try! connection.sendResponse(httpResponse)
        connection.close()
    }
    
    // MARK: -
    
    func httpServer(server: HTTPServer, didConnectConnection connection: HTTPConnection) {
        do {
            if let httpRequest = try connection.readRequest() {
                if httpRequest.requestHeaders["Upgrade"] == "websocket" && httpRequest.requestHeaders["Connection"] == "Upgrade" {
                    handleWebsocket(httpRequest, connection: connection)
                    return
                }
                
                print("\(httpRequest)")
                
                let bodyText = "Hello, world!"
                let httpResponse = HTTPResponse(httpVersion: httpRequest.httpVersion, statusCode: .OK, responseHeaders: nil, body: [UInt8](bodyText.utf8))
                
                try connection.sendResponse(httpResponse)
            }
            connection.close()
        }
        catch let error {
            print("\(error)")
            connection.close()
        }
    }
    
}

private func gaiErrnoDescription(gaiErrno: Int32) -> String {
    return String.fromCString(Darwin.gai_strerror(gaiErrno))! + " (\(gaiErrno))"
}

private func errnoDescription(rawErrno: Int32) -> String {
    return String.fromCString(Darwin.strerror(rawErrno))! + " (\(rawErrno))"
}

