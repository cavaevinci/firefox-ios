/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import XCTest

#if FOCUS
@testable import Firefox_Focus
#else
@testable import Firefox_Klar
#endif

class DomainCompletionTests: XCTestCase {
    private let simpleDomain = "example.com"
    private let httpDomain = "http://example.com"
    private let httpsDomain = "https://example.com"
    private let wwwDomain = "https://www.example.com"
    private let testNoPeriod = "example"
    private let testCaseInsensitive = "https://www.EXAMPLE.com"

    func testAddCustomDomain() {
        addADomain(domain: simpleDomain)
    }

    func testAddCustomDomainWithHttp() {
        addADomain(domain: httpDomain)
    }

    func testAddCustomDomainWithHttps() {
        addADomain(domain: httpsDomain)
    }

    func testAddCustomDomainWithWWW() {
        addADomain(domain: wwwDomain)
    }

    func testAddCustomDomainDuplicate() {
        Settings.setCustomDomainSetting(domains: [simpleDomain])
        [wwwDomain, testCaseInsensitive].forEach {
            let sut = CustomCompletionSource(
                enableCustomDomainAutocomplete: { Settings.getToggle(.enableCustomDomainAutocomplete) },
                getCustomDomainSetting: { Settings.getCustomDomainSetting() },
                setCustomDomainSetting: { Settings.setCustomDomainSetting(domains: $0) }
            )
            switch sut.add(suggestion: $0) {
            case .failure(let error):
                XCTAssertEqual(error, .duplicateDomain)
            case .success:
                XCTFail("Failed to add custom domain duplicate")
            }
        }
    }

    func testRemoveCustomDomain() {
        Settings.setCustomDomainSetting(domains: [simpleDomain])
        let sut = CustomCompletionSource(
            enableCustomDomainAutocomplete: { Settings.getToggle(.enableCustomDomainAutocomplete) },
            getCustomDomainSetting: { Settings.getCustomDomainSetting() },
            setCustomDomainSetting: { Settings.setCustomDomainSetting(domains: $0) }
        )
        switch sut.remove(at: 0) {
        case .failure:
            XCTFail("Failed to remove custom domain")
        case .success:
            XCTAssertEqual(0, Settings.getCustomDomainSetting().count)
        }
    }

    func testAddCustomDomainWithoutPeriod() {
        Settings.setCustomDomainSetting(domains: [])
        let sut = CustomCompletionSource(
            enableCustomDomainAutocomplete: { Settings.getToggle(.enableCustomDomainAutocomplete) },
            getCustomDomainSetting: { Settings.getCustomDomainSetting() },
            setCustomDomainSetting: { Settings.setCustomDomainSetting(domains: $0) }
        )
        switch sut.add(suggestion: testNoPeriod) {
        case .failure(let error):
            XCTAssertEqual(error, .invalidUrl)
        case .success:
            XCTFail("Failed to add custom domain without period")
        }
    }

    private func addADomain(domain: String) {
        Settings.setCustomDomainSetting(domains: [])
        let sut = CustomCompletionSource(
            enableCustomDomainAutocomplete: { Settings.getToggle(.enableCustomDomainAutocomplete) },
            getCustomDomainSetting: { Settings.getCustomDomainSetting() },
            setCustomDomainSetting: { Settings.setCustomDomainSetting(domains: $0) }
        )
        switch sut.add(suggestion: domain) {
        case .failure:
            XCTFail("Failed to add a domain")
        case .success:
            let domains = Settings.getCustomDomainSetting()
            XCTAssertEqual(domains.count, 1)
        }
    }
}
