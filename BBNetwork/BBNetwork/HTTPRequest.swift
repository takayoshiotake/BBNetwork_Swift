//
//  HTTPRequest.swift
//
//  Copyright © 2016 OTAKE Takayoshi. All rights reserved.
//

import Foundation

public struct HTTPRequest {
    public let method: String
    public let requestURI: String
    public let httpVersion: String
    public let requestHeaders: [String: String]
}