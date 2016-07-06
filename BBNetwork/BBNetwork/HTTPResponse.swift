//
//  HTTPResponse.swift
//
//  Copyright © 2016 OTAKE Takayoshi. All rights reserved.
//

import Foundation

/// HTTP/1.1 standard; RFC 7231
public enum HTTPStatusCode {
    case OK
    case WithRawValue(intValue: Int, reasonPhrase: String)
    
    var intValue: Int {
        switch self {
        case .OK:
            return 200
        case .WithRawValue(let intValue, _):
            return intValue
        }
    }
    
    var reasonPhrase: String {
        switch self {
        case .OK:
            return "OK"
        case .WithRawValue(_, let reasonPhrase):
            return reasonPhrase
        }
    }
}

public struct HTTPResponse {
    public let httpVersion: String
    public let statusCode: HTTPStatusCode
    public let body: [UInt8]?
    
    public var responseLine: String {
        return "\(httpVersion) \(statusCode.intValue) \(statusCode.reasonPhrase)"
    }
    
    public init(httpVersion: String, statusCode: HTTPStatusCode, body: [UInt8]?) {
        self.httpVersion = httpVersion
        self.statusCode = statusCode
        self.body = body
    }
    
    public func bytes() -> [UInt8] {
        var str = responseLine + "\r\n"
        // TODO: Append response headers
        str += "\r\n"
        guard let body = body else {
            return [UInt8](str.utf8)
        }
        return [UInt8](str.utf8) + body
    }
}
