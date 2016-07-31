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
    
    func httpServer(server: HTTPServer, didConnectConnection connection: HTTPConnection) {
        defer {
            connection.close()
        }
        do {
            if let httpRequest = try connection.readRequest() {
                print("\(httpRequest)")
                
                let bodyText = "Hello, world!"
                let httpResponse = HTTPResponse(httpVersion: httpRequest.httpVersion, statusCode: .OK, responseHeaders: nil, body: [UInt8](bodyText.utf8))
                
                try connection.sendResponse(httpResponse)
            }
        }
        catch let error {
            print("\(error)")
        }
    }
    
}

private func gaiErrnoDescription(gaiErrno: Int32) -> String {
    return String.fromCString(Darwin.gai_strerror(gaiErrno))! + " (\(gaiErrno))"
}

private func errnoDescription(rawErrno: Int32) -> String {
    return String.fromCString(Darwin.strerror(rawErrno))! + " (\(rawErrno))"
}

