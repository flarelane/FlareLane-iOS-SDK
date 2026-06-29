import XCTest
@testable import FlareLane

class Tests: XCTestCase {

    // MARK: - Push action buttons
    //
    // These specs cover the action-button feature: JSON parsing, click-target resolution, and the
    // malformed-entry tolerance contract — kept to host-app-runnable logic only (no NSE / OS APIs).

    func testParseButtons_acceptsJSONString() {
        let json = "[{\"label\":\"Open\",\"link\":\"https://example.com/a\"},{\"label\":\"Share\"}]"
        let userInfo: [AnyHashable: Any] = [
            "isFlareLane": true,
            "aps": ["alert": ["body": "hello", "title": "Title"]],
            "notificationId": "notif-1",
            "url": "https://example.com/body",
            "buttons": json
        ]

        let notification = FlareLaneNotification.getFlareLaneNotificationFromUserInfo(userInfo: userInfo)
        XCTAssertNotNil(notification)
        XCTAssertEqual(notification?.buttons?.count, 2)
        XCTAssertEqual(notification?.buttons?[0].label, "Open")
        XCTAssertEqual(notification?.buttons?[0].link, "https://example.com/a")
        XCTAssertEqual(notification?.buttons?[1].label, "Share")
        XCTAssertNil(notification?.buttons?[1].link)
    }

    func testParseButtons_acceptsNativeArray() {
        let userInfo: [AnyHashable: Any] = [
            "isFlareLane": true,
            "aps": ["alert": ["body": "hello"]],
            "notificationId": "notif-2",
            "buttons": [
                ["label": "First", "link": "https://example.com/1"]
            ]
        ]

        let notification = FlareLaneNotification.getFlareLaneNotificationFromUserInfo(userInfo: userInfo)
        XCTAssertEqual(notification?.buttons?.count, 1)
        XCTAssertEqual(notification?.buttons?[0].label, "First")
    }

    func testParseButtons_skipsEmptyLabelEntries() {
        let json = "[{\"label\":\"Good\"},{\"label\":\"\"},{\"link\":\"https://example.com/no-label\"},{\"label\":\"AlsoGood\"}]"
        let userInfo: [AnyHashable: Any] = [
            "isFlareLane": true,
            "aps": ["alert": ["body": "hello"]],
            "notificationId": "notif-3",
            "buttons": json
        ]

        let notification = FlareLaneNotification.getFlareLaneNotificationFromUserInfo(userInfo: userInfo)
        XCTAssertEqual(notification?.buttons?.count, 2)
        XCTAssertEqual(notification?.buttons?[0].label, "Good")
        XCTAssertEqual(notification?.buttons?[1].label, "AlsoGood")
    }

    func testParseButtons_returnsNilForMalformedJSON() {
        let userInfo: [AnyHashable: Any] = [
            "isFlareLane": true,
            "aps": ["alert": ["body": "hello"]],
            "notificationId": "notif-4",
            "buttons": "not a json array"
        ]

        let notification = FlareLaneNotification.getFlareLaneNotificationFromUserInfo(userInfo: userInfo)
        XCTAssertNil(notification?.buttons)
    }

    func testClickedButton_resolvedByWithClickedButtonIdx() {
        let buttons = [
            FlareLaneNotificationButton(label: "First", link: "https://example.com/1"),
            FlareLaneNotificationButton(label: "Second", link: "https://example.com/2")
        ]
        let notification = FlareLaneNotification(
            id: "notif-5",
            body: "hello",
            title: nil,
            url: "https://example.com/body",
            imageUrl: nil,
            data: nil,
            buttons: buttons
        )

        let withClick = notification.withClickedButtonIndex(1)
        XCTAssertEqual(withClick.clickedButton?.label, "Second")
        XCTAssertEqual(withClick.clickedUrl, "https://example.com/2")
    }

    func testClickedUrl_isBodyUrlForBodyClick() {
        let notification = FlareLaneNotification(
            id: "notif-6",
            body: "hello",
            title: nil,
            url: "https://example.com/body",
            imageUrl: nil,
            data: nil
        )
        // Body click branch: `clickedUrl` resolves to the notification body's `url`.
        XCTAssertNil(notification.clickedButton)
        XCTAssertEqual(notification.clickedUrl, "https://example.com/body")
    }

    func testClickedUrl_isNilOnButtonClickWithoutLink() {
        let buttons = [FlareLaneNotificationButton(label: "Only", link: "https://example.com/only")]
        let notification = FlareLaneNotification(
            id: "notif-7",
            body: "hello",
            title: nil,
            url: "https://example.com/body",
            imageUrl: nil,
            data: nil,
            buttons: buttons
        ).withClickedButtonIndex(5)

        XCTAssertNil(notification.clickedButton)
        // Out-of-range index is still a button click — but with no resolvable link, this
        // returns nil. Critically, it does NOT fall through to the body's url:
        // button and body URLs are distinct destinations and must not be conflated.
        XCTAssertNil(notification.clickedUrl)
        // Sanity: the body still has its own url; we're just not surfacing it via clickedUrl.
        XCTAssertEqual(notification.url, "https://example.com/body")
    }

    // MARK: - API.getInAppMessages crash regression
    //
    // These specs prove the SDK no longer trips `fatalError("Unreachable")` when `Request.post`
    // legitimately callbacks `(result: nil, error: nil)`. If a future change re-introduces a
    // fatalError on this path the XCTest runner itself crashes — so these tests double as a
    // hard guarantee that the in-app message fetcher cannot tear down the host app.

    func testGetInAppMessages_failsGracefullyOnMalformedBody() {
        // Request.swift:113-117 — `JSONSerialization.isValidJSONObject(body)` returns false for
        // NaN/Infinity, so `getRequestWithBody` is nil and `Request.post` calls `completion(nil, nil)`
        // synchronously. Previously crashed via fatalError; now resolves to .failure.
        Globals.projectIdInUserDefaults = "test-project-id"
        defer { Globals.projectIdInUserDefaults = nil }

        let exp = expectation(description: "completion invoked")
        var captured: Result<[String: Any], Error>?

        API.shared.getInAppMessages(
            deviceId: "device-1",
            group: "default",
            data: ["bad": Double.nan]
        ) { result in
            captured = result
            exp.fulfill()
        }

        wait(for: [exp], timeout: 2.0)
        guard case let .failure(error) = captured else {
            XCTFail("expected failure, got \(String(describing: captured))")
            return
        }
        guard case Request.HTTPError.unexpectedNilResponse = error else {
            XCTFail("expected HTTPError.unexpectedNilResponse, got \(error)")
            return
        }
    }

    func testGetInAppMessages_failsGracefullyOnNonJSON200Body() {
        // Request.swift:131-137 — a 200 response whose body isn't JSON makes `Request.post`
        // call `completion(nil, nil)`. Previously crashed via fatalError; now resolves to .failure.
        Globals.projectIdInUserDefaults = "test-project-id"
        defer { Globals.projectIdInUserDefaults = nil }

        URLProtocol.registerClass(NonJSON200ResponseStub.self)
        defer { URLProtocol.unregisterClass(NonJSON200ResponseStub.self) }

        let exp = expectation(description: "completion invoked")
        var captured: Result<[String: Any], Error>?

        API.shared.getInAppMessages(
            deviceId: "device-1",
            group: "default",
            data: nil
        ) { result in
            captured = result
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
        guard case let .failure(error) = captured else {
            XCTFail("expected failure, got \(String(describing: captured))")
            return
        }
        guard case Request.HTTPError.unexpectedNilResponse = error else {
            XCTFail("expected HTTPError.unexpectedNilResponse, got \(error)")
            return
        }
    }
}

// URLSession.shared honors URLProtocol subclasses registered via `URLProtocol.registerClass`,
// which lets us intercept the FlareLane service host and return a non-JSON 200 body without
// touching `Request`'s internals.
private final class NonJSON200ResponseStub: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "service-api.flarelane.com"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "text/html"]
              ) else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("<html>not-json</html>".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
