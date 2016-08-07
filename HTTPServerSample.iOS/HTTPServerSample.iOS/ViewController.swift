//
//  ViewController.swift
//  HTTPServerSample.iOS
//
//  Copyright © 2016 OTAKE Takayoshi. All rights reserved.
//

import UIKit
import BBNetwork

class ViewController: UIViewController, HTTPServerDelegate {
    
    var isActive: Bool = false {
        didSet {
            didChangeViewControllerStatus()
        }
    }
    var appears: Bool = false {
        didSet {
            didChangeViewControllerStatus()
        }
    }
    
    var httpServer: HTTPServer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(applicationDidBecomeActive(_:)), name: UIApplicationDidBecomeActiveNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(applicationWillResignActive(_:)), name: UIApplicationWillResignActiveNotification, object: nil)
        httpServer = HTTPServer(tcpServer: TCPServer(supportedProtocol: .IPv6, port: 8080))
        httpServer.delegate = self
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        appears = true
    }
    
    override func viewWillDisappear(animated: Bool) {
        appears = false
        super.viewWillDisappear(animated)
    }
    
    // MARK: -
    
    func applicationDidBecomeActive(notification: NSNotification) {
        isActive = true
    }
    
    func applicationWillResignActive(notification: NSNotification) {
        isActive = false
    }
    
    // MARK: -
    
    func didChangeViewControllerStatus() {
        if isActive && appears {
            do {
                try httpServer.start()
            }
            catch SocketServerErrorType.SystemError(let rawErrno) {
                print("System error: \(errnoDescription(rawErrno))")
            }
            catch {
            }
        }
        else if !isActive || !appears {
            httpServer.stop()
        }
    }
    
    // MARK: -
    
    func httpServer(server: HTTPServer, didConnect socket: HTTPSocket) {
        do {
            if let request = try socket.readRequest() {
                print("\(request)")
                
                let bodyText = "Hello, world!"
                let response = HTTPResponse(httpVersion: request.httpVersion, statusCode: .OK, headers: nil, body: [UInt8](bodyText.utf8))
                
                try socket.sendResponse(response)
            }
        }
        catch {
        }
        socket.close()
    }
    
}

private func gaiErrnoDescription(gaiErrno: Int32) -> String {
    return String.fromCString(Darwin.gai_strerror(gaiErrno))! + " (\(gaiErrno))"
}

private func errnoDescription(rawErrno: Int32) -> String {
    return String.fromCString(Darwin.strerror(rawErrno))! + " (\(rawErrno))"
}
