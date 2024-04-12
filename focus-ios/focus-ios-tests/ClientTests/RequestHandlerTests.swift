// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import XCTest

#if FOCUS
@testable import Firefox_Focus
#else
@testable import Firefox_Klar
#endif

class RequestHandlerTests: XCTestCase {
    private let alertCallback: (UIAlertController) -> Void = { _ in }
    private let reguestHandler = RequestHandler()
    private let externalScheme = "itms-appss"
    private let invalidURL = "Invalid URL"
    private let httpsInternalScheme = "https"
    private let exampleHost = "www.example.com"

    func testValidURLAndScheme() {
        let urlRequest = URLRequest(url: URL(string: "\(httpsInternalScheme)://\(exampleHost)")!)
        let sut = reguestHandler.handle(request: urlRequest, alertCallback: alertCallback)
        XCTAssertTrue(sut)
    }

    func testInvalidURLAndScheme() {
        var urlRequest = URLRequest(url: URL(string: "\(httpsInternalScheme)://\(exampleHost)")!)
        urlRequest.url = URL(string: invalidURL)
        let sut = reguestHandler.handle(request: urlRequest, alertCallback: alertCallback)
        XCTAssertFalse(sut)
    }

    func testSchemeIsNotInternalScheme() {
        let urlRequest = URLRequest(url: URL(string: "\(externalScheme)://\(exampleHost)")!)
        let sut = reguestHandler.handle(request: urlRequest, alertCallback: alertCallback)
        XCTAssertFalse(sut)
    }

    func testInternalSchemeAndHostIsNil() {
        let urlRequest = URLRequest(url: URL(string: "\(httpsInternalScheme)://")!)
        let sut = reguestHandler.handle(request: urlRequest, alertCallback: alertCallback)
        XCTAssertTrue(sut)
    }

    func testInternalSchemeAndSpecialCaseHosts() {
        var urlRequest = URLRequest(url: URL(string: "\(httpsInternalScheme)://\("maps.apple.com")")!)
        var sut = reguestHandler.handle(request: urlRequest, alertCallback: alertCallback)
        XCTAssertFalse(sut)
        urlRequest = URLRequest(url: URL(string: "\(httpsInternalScheme)://\("itunes.apple.com")")!)
        sut = reguestHandler.handle(request: urlRequest, alertCallback: alertCallback)
        XCTAssertFalse(sut)
    }
}
