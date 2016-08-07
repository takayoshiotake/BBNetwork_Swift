//
//  HTTPSocket.swift
//
//  Copyright © 2016 OTAKE Takayoshi. All rights reserved.
//

import Foundation

public class HTTPSocket {
    public let rawSocket: Socket
    
    public init(socket: Socket) {
        rawSocket = socket
    }
    
    public func readRequest() throws -> HTTPRequest? {
        let asciiCR = 0x0d as UInt8
        let asciiLF = 0x0a as UInt8
        
        var requestBuffer = try rawSocket.peek(1024)
        
        var requestEndIndex = -1
        var ii = 0
        let iend = requestBuffer.count - 3
        while ii < iend {
            if requestBuffer[ii] == asciiCR && requestBuffer[ii + 1] == asciiLF && requestBuffer[ii + 2] == asciiCR && requestBuffer[ii + 3] == asciiLF {
                requestEndIndex = ii + 3
                break
            }
            ii += 1
        }
        if requestEndIndex == -1 {
            return nil
        }
        
        requestBuffer = try rawSocket.recv(requestEndIndex)
        return HTTPRequest(bytes: requestBuffer, count: requestEndIndex)
    }
    
    public func sendResponse(httpResponse: HTTPResponse) throws {
        try rawSocket.send(httpResponse.bytes())
    }
    
    public func close() {
        rawSocket.close()
    }
}

public extension HTTPRequest {
    private init?(bytes: ArraySlice<UInt8>, count: Int) {
        if let requestText = String(bytes: bytes[0..<count-2], encoding: NSUTF8StringEncoding) {
            // The last empty line is removed
            var lines: [String] = []
            requestText.enumerateLines { (line, stop) in
                lines.append(line)
            }
            if lines.count == 0 {
                return nil
            }
            let method: String
            let uri: String
            let httpVersion: String
            var headers: [String: String] = [:]
            do {
                let temp = lines.first!.componentsSeparatedByString(" ")
                if temp.count != 3 {
                    return nil
                }
                method = temp[0]
                uri = temp[1]
                httpVersion = temp[2]
            }
            for line in lines[1..<lines.count] {
                if let separatorIndex = line.characters.indexOf(":") where separatorIndex < line.endIndex {
                    let field = line.substringToIndex(separatorIndex)
                    var value = line.substringFromIndex(separatorIndex.advancedBy(1))
                    if value.characters.first == " " {
                        value = String(value.characters.dropFirst())
                    }
                    // TODO: Check field is not duplicated
                    headers[field] = value
                }
                else {
                    return nil
                }
            }
            self.init(method: method, uri: uri, httpVersion: httpVersion, headers: headers)
        }
        else {
            return nil
        }
    }
}
