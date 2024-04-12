/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import XCTest

#if FOCUS
@testable import Firefox_Focus
#else
@testable import Firefox_Klar
#endif

class SearchEngineTests: XCTestCase {
    private let engine = SearchEngineManager(prefs: UserDefaults.standard).activeEngine
    private let client = SearchSuggestClient()

    private let specialCharOccurance = "\""
    private let normalSearch = "example"
    private let beginWithWhiteSpaceSearch = "example"

    func testSpecialCharacterQuery() {
        let queryURL = engine.urlForQuery(specialCharOccurance)
        XCTAssertNotNil(queryURL)
    }

    func testSpecialCharacterSearchSuggestions() {
        let searchURL = engine.urlForSuggestions(specialCharOccurance)
        XCTAssertNotNil(searchURL)
    }

    func testNormalQuery() {
        let queryURL = engine.urlForQuery(normalSearch)
        XCTAssertNotNil(queryURL)
    }

    func testNormalSearchSuggestions() {
        let searchURL = engine.urlForSuggestions(normalSearch)
        XCTAssertNotNil(searchURL)
    }

    func testBeginWithWhiteSpaceQuery() {
        let normalQueryURL = engine.urlForQuery(normalSearch)
        let testQueryURL = engine.urlForQuery(beginWithWhiteSpaceSearch)
        XCTAssertEqual(normalQueryURL, testQueryURL)
    }

    func testBeginWithWhiteSpaceSearchSuggestions() {
        let normalSearchURL = engine.urlForSuggestions(normalSearch)
        let testSearchURL = engine.urlForSuggestions(beginWithWhiteSpaceSearch)
        XCTAssertEqual(normalSearchURL, testSearchURL)
    }

    /* This test is failing intermittently, issue 1821
    func testGetSuggestions() {
        client.getSuggestions(NORMAL_SEARCH, callback: { response, error in
            XCTAssertThrowsError(error)
            XCTAssertNil(response)
        })
    }
        
    func testResponseConsistency() {
        let client = SearchSuggestClient()
        client.getSuggestions(NORMAL_SEARCH, callback: { response, error in
            XCTAssertThrowsError(error)
            XCTAssertEqual(self.NORMAL_SEARCH, response?[0])
        })
    }
     */
}
