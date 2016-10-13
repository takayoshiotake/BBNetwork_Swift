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
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(_:)), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive(_:)), name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
        httpServer = HTTPServer(tcpServer: TCPServer(supportedProtocol: .iPv6, port: 8080))
        httpServer.delegate = self
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        appears = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        appears = false
        super.viewWillDisappear(animated)
    }
    
    // MARK: -
    
    func applicationDidBecomeActive(_ notification: Notification) {
        isActive = true
    }
    
    func applicationWillResignActive(_ notification: Notification) {
        isActive = false
    }
    
    // MARK: -
    
    func didChangeViewControllerStatus() {
        if isActive && appears {
            do {
                try httpServer.start()
            }
            catch SocketServerErrorType.systemError(let rawErrno) {
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
    
    func httpServer(_ server: HTTPServer, didConnect socket: HTTPSocket) {
        do {
            if let request = try socket.readRequest() {
                print("\(request)")
                
                let bodyText = "Hello, world!"
                let response = HTTPResponse(httpVersion: request.httpVersion, statusCode: .ok, headers: nil, body: [UInt8](bodyText.utf8))
                
                try socket.sendResponse(response)
            }
        }
        catch {
        }
        socket.close()
    }
    
}

private func gaiErrnoDescription(_ gaiErrno: Int32) -> String {
    return String(cString: Darwin.gai_strerror(gaiErrno)) + " (\(gaiErrno))"
}

private func errnoDescription(_ rawErrno: Int32) -> String {
    return String(cString: Darwin.strerror(rawErrno)) + " (\(rawErrno))"
}
