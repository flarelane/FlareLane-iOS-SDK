import XCTest
import UserNotifications
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

// MARK: - InAppMessageService completion contract
//
// showInAppMessageIfNeeded MUST invoke its completion exactly once on every exit path so the
// FlareLaneTaskManager slot is released without waiting for its TIMEOUT_MS (10s). These specs
// pin that contract; a regression here re-introduces the "next displayInApp takes 10s" bug
// reported in production.

extension Tests {

    func testShowInAppMessageIfNeeded_callsCompletionWhenDeviceIdMissing() {
        Globals.deviceIdInUserDefaults = nil

        let exp = expectation(description: "completion invoked (device-id guard)")
        var callCount = 0
        InAppMessageService.shared.showInAppMessageIfNeeded(group: "TabHome", data: nil) {
            callCount += 1
            exp.fulfill()
        }

        wait(for: [exp], timeout: 2.0)
        XCTAssertEqual(callCount, 1)
    }

    func testShowInAppMessageIfNeeded_callsCompletionOnAPIFailure() {
        // Emulate the bug reproducer: the API responds with a 200 body that isn't JSON, which
        // Request.post surfaces as `.failure(unexpectedNilResponse)`. Our fix routes the failure
        // through `completion()` instead of dropping the callback silently.
        Globals.projectIdInUserDefaults = "test-project-id"
        Globals.deviceIdInUserDefaults = "device-1"
        defer {
            Globals.projectIdInUserDefaults = nil
            Globals.deviceIdInUserDefaults = nil
        }

        URLProtocol.registerClass(NonJSON200ResponseStub.self)
        defer { URLProtocol.unregisterClass(NonJSON200ResponseStub.self) }

        let exp = expectation(description: "completion invoked (API failure)")
        var callCount = 0
        InAppMessageService.shared.showInAppMessageIfNeeded(group: "TabHome", data: nil) {
            callCount += 1
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
        XCTAssertEqual(callCount, 1)
    }

    func testShowInAppMessageIfNeeded_callsCompletionOnEmptyDataArray() {
        // Success response with `data: []` — the "no displayable IAM" branch. Must still
        // release the task slot; otherwise the next displayInApp waits for TIMEOUT_MS.
        Globals.projectIdInUserDefaults = "test-project-id"
        Globals.deviceIdInUserDefaults = "device-1"
        defer {
            Globals.projectIdInUserDefaults = nil
            Globals.deviceIdInUserDefaults = nil
        }

        URLProtocol.registerClass(EmptyDataArrayResponseStub.self)
        defer { URLProtocol.unregisterClass(EmptyDataArrayResponseStub.self) }

        let exp = expectation(description: "completion invoked (empty data)")
        var callCount = 0
        InAppMessageService.shared.showInAppMessageIfNeeded(group: "TabHome", data: nil) {
            callCount += 1
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
        XCTAssertEqual(callCount, 1)
    }
}

// MARK: - NSE category registration sequencing (iOS 16 buttons regression)
//
// registerCategorySynchronously must finish its get -> set -> get(flush) round-trips BEFORE
// returning, and the caller attaches categoryIdentifier only when it returns true. The previous
// fire-and-forget registration raced contentHandler: the NSE could be suspended before
// setNotificationCategories ran, so the notification rendered without buttons (reported on
// iOS 16 with image-less pushes).

extension Tests {

    private static func makeCategory(_ id: String) -> UNNotificationCategory {
        UNNotificationCategory(identifier: id, actions: [], intentIdentifiers: [], options: [])
    }

    func testRegisterCategory_completesGetSetGetBeforeReturning() {
        let store = FakeCategoryStore()

        let registered = FlareLaneNotificationServiceExtensionHelper.registerCategorySynchronously(
            Self.makeCategory("flarelane_dynamic_a"), evicted: [], store: store, timeout: 1.0
        )

        XCTAssertTrue(registered)
        // The flush read-back must have happened before the function returned — this ordering is
        // the whole fix; without it the content ships while registration is still pending.
        XCTAssertEqual(store.calls, ["get", "set", "get"])
    }

    func testRegisterCategory_mergePreservesHostCategoriesAndDropsEvicted() {
        let store = FakeCategoryStore()
        store.existing = [Self.makeCategory("host_category"), Self.makeCategory("flarelane_dynamic_old")]

        let registered = FlareLaneNotificationServiceExtensionHelper.registerCategorySynchronously(
            Self.makeCategory("flarelane_dynamic_new"),
            evicted: ["flarelane_dynamic_old"],
            store: store,
            timeout: 1.0
        )

        XCTAssertTrue(registered)
        let ids = Set(store.lastSetCategories?.map { $0.identifier } ?? [])
        XCTAssertEqual(ids, ["host_category", "flarelane_dynamic_new"])
    }

    func testRegisterCategory_firstGetTimeoutSkipsSetAndReturnsFalse() {
        let store = FakeCategoryStore()
        store.swallowGetCalls = [0]

        let registered = FlareLaneNotificationServiceExtensionHelper.registerCategorySynchronously(
            Self.makeCategory("flarelane_dynamic_a"), evicted: [], store: store, timeout: 0.1
        )

        // With no merge base, calling set would wipe host-app categories — it must be skipped
        // entirely, and the caller must not attach the identifier.
        XCTAssertFalse(registered)
        XCTAssertEqual(store.calls, ["get"])
        XCTAssertNil(store.lastSetCategories)
    }

    func testRegisterCategory_flushTimeoutStillRegistersAndReturnsTrue() {
        let store = FakeCategoryStore()
        store.swallowGetCalls = [1]

        let registered = FlareLaneNotificationServiceExtensionHelper.registerCategorySynchronously(
            Self.makeCategory("flarelane_dynamic_a"), evicted: [], store: store, timeout: 0.1
        )

        // set was already submitted, so this is best effort: identifier still attaches.
        XCTAssertTrue(registered)
        XCTAssertEqual(store.calls, ["get", "set", "get"])
        XCTAssertEqual(store.lastSetCategories?.map { $0.identifier }, ["flarelane_dynamic_a"])
    }
}

// Call-recording NotificationCategoryStore double. Completions run synchronously on the calling
// thread; `swallowGetCalls` lists get-call indices whose completion is never invoked, simulating
// an unresponsive notification center so the semaphore timeout paths can be exercised.
private final class FakeCategoryStore: NotificationCategoryStore {
    var existing: Set<UNNotificationCategory> = []
    var swallowGetCalls: Set<Int> = []
    private(set) var calls: [String] = []
    private(set) var lastSetCategories: Set<UNNotificationCategory>?
    private var getCallIndex = 0

    func getNotificationCategories(completionHandler: @escaping (Set<UNNotificationCategory>) -> Void) {
        let index = getCallIndex
        getCallIndex += 1
        calls.append("get")
        if swallowGetCalls.contains(index) { return }
        completionHandler(existing)
    }

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        calls.append("set")
        lastSetCategories = categories
        existing = categories
    }
}

// Returns a well-formed but empty IAM response body so the caller reaches the "nothing to
// show" branch without touching UIKit.
private final class EmptyDataArrayResponseStub: URLProtocol {
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
                headerFields: ["Content-Type": "application/json"]
              ) else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{\"data\":[]}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
