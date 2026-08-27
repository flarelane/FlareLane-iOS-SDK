import UIKit
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

    func testRegisterCategory_repeatedNotificationIdReplacesStaleCategory() {
        let store = FakeCategoryStore()
        store.existing = [Self.makeCategory("host_category"), Self.makeCategory("flarelane_dynamic_a")]

        // Same notification ID delivered again with different buttons: the stale same-identifier
        // category must be replaced, not left to coexist (Set.insert is a no-op on equal members
        // and iOS picks arbitrarily between duplicate identifiers).
        let updatedAction = UNNotificationAction(identifier: "0", title: "Updated", options: [.foreground])
        let updated = UNNotificationCategory(
            identifier: "flarelane_dynamic_a", actions: [updatedAction], intentIdentifiers: [], options: []
        )

        let registered = FlareLaneNotificationServiceExtensionHelper.registerCategorySynchronously(
            updated, evicted: [], store: store, timeout: 1.0
        )

        XCTAssertTrue(registered)
        let ours = store.lastSetCategories?.filter { $0.identifier == "flarelane_dynamic_a" } ?? []
        XCTAssertEqual(ours.count, 1)
        XCTAssertEqual(ours.first?.actions.map(\.title), ["Updated"])
        XCTAssertTrue(store.lastSetCategories?.contains { $0.identifier == "host_category" } ?? false)
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

// Call-recording NotificationCategoryStore double. Completions are delivered asynchronously on a
// private queue, mirroring UNUserNotificationCenter's own internal queue, so the semaphore in
// fetchCategories genuinely blocks until the callback arrives; `swallowGetCalls` lists get-call
// indices whose completion is never invoked, simulating an unresponsive notification center so
// the timeout paths can be exercised.
private final class FakeCategoryStore: NotificationCategoryStore {
    var existing: Set<UNNotificationCategory> = []
    var swallowGetCalls: Set<Int> = []
    private(set) var calls: [String] = []
    private(set) var lastSetCategories: Set<UNNotificationCategory>?
    private var getCallIndex = 0
    private let callbackQueue = DispatchQueue(label: "com.flarelane.tests.fake-category-store")

    func getNotificationCategories(completionHandler: @escaping @Sendable (Set<UNNotificationCategory>) -> Void) {
        let index = getCallIndex
        getCallIndex += 1
        calls.append("get")
        if swallowGetCalls.contains(index) { return }
        // Snapshot on the calling thread; the caller's semaphore sequences all other state access.
        let snapshot = existing
        callbackQueue.async { completionHandler(snapshot) }
    }

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        calls.append("set")
        lastSetCategories = categories
        existing = categories
    }
}

// MARK: - threadId & communication payload parsing (1.11.0)

extension Tests {

    private static func makeFlareLaneUserInfo(extra: [String: Any] = [:]) -> [AnyHashable: Any] {
        var userInfo: [AnyHashable: Any] = [
            "isFlareLane": true,
            "notificationId": "notif_1",
            "aps": ["alert": ["title": "t", "body": "b"]]
        ]
        for (key, value) in extra { userInfo[key] = value }
        return userInfo
    }

    func testNotification_parsesThreadIdAndKeepsItThroughCopyAndBridge() {
        let notification = FlareLaneNotification.getFlareLaneNotificationFromUserInfo(
            userInfo: Self.makeFlareLaneUserInfo(extra: ["threadId": "promo"])
        )

        XCTAssertEqual(notification?.threadId, "promo")
        XCTAssertEqual(notification?.withClickedButtonIndex(0).threadId, "promo")
        XCTAssertEqual(notification?.toDictionary()["threadId"] as? String, "promo")
    }

    func testNotification_threadIdAbsentOrEmptyIsNil() {
        let absent = FlareLaneNotification.getFlareLaneNotificationFromUserInfo(userInfo: Self.makeFlareLaneUserInfo())
        let empty = FlareLaneNotification.getFlareLaneNotificationFromUserInfo(userInfo: Self.makeFlareLaneUserInfo(extra: ["threadId": ""]))

        XCTAssertNil(absent?.threadId)
        XCTAssertNil(empty?.threadId)
        XCTAssertNil(absent?.toDictionary()["threadId"])
    }

    func testCommunication_parsesDictionaryAndJsonString() {
        let fromDict = FlareLaneNotificationCommunication.parse(
            from: ["senderName": "Kim", "senderImageUrl": "https://cdn.example.com/a.png"]
        )
        XCTAssertEqual(fromDict?.senderName, "Kim")
        XCTAssertEqual(fromDict?.senderImageUrl, "https://cdn.example.com/a.png")

        // FCM data values arrive as JSON strings; both forms must parse identically.
        let fromString = FlareLaneNotificationCommunication.parse(
            from: "{\"senderName\":\"Kim\",\"senderImageUrl\":\"https://cdn.example.com/a.png\"}"
        )
        XCTAssertEqual(fromString?.senderName, "Kim")
        XCTAssertEqual(fromString?.senderImageUrl, "https://cdn.example.com/a.png")
    }

    func testCommunication_requiresBothFieldsAndNeverThrows() {
        XCTAssertNil(FlareLaneNotificationCommunication.parse(from: ["senderName": "Kim"]))
        XCTAssertNil(FlareLaneNotificationCommunication.parse(from: ["senderImageUrl": "https://x/a.png"]))
        XCTAssertNil(FlareLaneNotificationCommunication.parse(from: ["senderName": "", "senderImageUrl": "https://x/a.png"]))
        XCTAssertNil(FlareLaneNotificationCommunication.parse(from: "not json"))
        XCTAssertNil(FlareLaneNotificationCommunication.parse(from: 42))
        XCTAssertNil(FlareLaneNotificationCommunication.parse(from: nil))
    }

    func testNotification_communicationRoundTripsThroughBridgeDictionary() {
        let notification = FlareLaneNotification.getFlareLaneNotificationFromUserInfo(
            userInfo: Self.makeFlareLaneUserInfo(
                extra: ["communication": ["senderName": "Kim", "senderImageUrl": "https://x/a.png"]]
            )
        )

        let bridged = notification?.toDictionary()["communication"] as? [String: Any]
        XCTAssertEqual(bridged?["senderName"] as? String, "Kim")
        XCTAssertEqual(bridged?["senderImageUrl"] as? String, "https://x/a.png")
        XCTAssertTrue(JSONSerialization.isValidJSONObject(notification?.toDictionary() ?? [:]))
    }
}

// MARK: - Communication intent builder + NSE media sequencing (1.11.0)

extension Tests {

    private static func makeStyledContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "t"
        content.body = "b"
        content.userInfo = ["notificationId": "notif_1"]
        content.categoryIdentifier = "flarelane_dynamic_notif_1"
        content.threadIdentifier = "promo"
        return content
    }

    private static func makeAvatarData() -> Data? {
        // The builder decode-checks avatar bytes (UIImage(data:)) before styling, so the
        // fixture must be a real decodable image, not just a PNG magic header.
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let image = renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        // The Tests target still builds with the pre-4.2 Swift setting, hence the old API name.
        return UIImagePNGRepresentation(image)
    }

    // MARK: - Log level

    func testLogLevel_rawValuesAreTheSharedWireFormat() {
        // The four SDKs send one value per level, so these must not drift.
        XCTAssertEqual(LogLevel.none.rawValue, 0)
        XCTAssertEqual(LogLevel.error.rawValue, 1)
        XCTAssertEqual(LogLevel.verbose.rawValue, 5)
    }

    func testInitialize_rePublishesTheLevelSoAnOldOneCannotOutliveTheApp() {
        let original = Globals.logLevel
        let originalStored = Globals.logLevelInUserDefaults
        defer {
            Globals.logLevel = original
            Globals.logLevelInUserDefaults = originalStored
        }

        // An earlier launch silenced everything, and this launch no longer calls setLogLevel.
        Globals.logLevelInUserDefaults = LogLevel.none.rawValue
        Globals.logLevel = .verbose

        // What initWithLaunchOptions does first: republish the level this launch actually uses.
        Globals.logLevelInUserDefaults = Globals.logLevel.rawValue

        XCTAssertEqual(Globals.logLevelInUserDefaults, LogLevel.verbose.rawValue,
                       "a stale persisted level must not keep an extension silent")
    }

    func testSetLogLevel_appliesInProcessAndPublishesForExtensions() {
        let original = Globals.logLevel
        let originalStored = Globals.logLevelInUserDefaults
        defer {
            Globals.logLevel = original
            Globals.logLevelInUserDefaults = originalStored
        }

        FlareLane.setLogLevel(level: .none)
        XCTAssertEqual(Globals.logLevel, .none)
        // The extension is a separate process; the published value is the only way it can adopt
        // the app's level.
        XCTAssertEqual(Globals.logLevelInUserDefaults, LogLevel.none.rawValue)

        FlareLane.setLogLevel(level: .error)
        XCTAssertEqual(Globals.logLevel, .error)
        XCTAssertEqual(Globals.logLevelInUserDefaults, LogLevel.error.rawValue)
    }

    @available(iOS 15.0, *)
    func testCommunicationBuilder_withoutAvatarFallsBackToOriginalContent() {
        let content = Self.makeStyledContent()

        let result = FlareLaneCommunicationIntentBuilder.apply(
            communication: FlareLaneNotificationCommunication(senderName: "Kim", senderImageUrl: "https://x/a.png"),
            notificationId: "notif_1",
            threadId: nil,
            avatarData: nil,
            to: content
        )

        // Product decision: no avatar -> plain app-icon notification, not a gray monogram bubble.
        XCTAssertTrue(result === content)
    }

    @available(iOS 15.0, *)
    func testCommunicationBuilder_appliedContentPreservesExistingFields() throws {
        let content = Self.makeStyledContent()
        let avatar = try XCTUnwrap(Self.makeAvatarData())

        let result = FlareLaneCommunicationIntentBuilder.apply(
            communication: FlareLaneNotificationCommunication(senderName: "Kim", senderImageUrl: "https://x/a.png"),
            notificationId: "notif_1",
            threadId: "promo",
            avatarData: avatar,
            to: content
        )

        // updating(from:) returns a restyled copy carrying everything set beforehand.
        XCTAssertFalse(result === content)
        XCTAssertEqual(result.categoryIdentifier, "flarelane_dynamic_notif_1")
        XCTAssertEqual(result.threadIdentifier, "promo")
        XCTAssertEqual(result.userInfo["notificationId"] as? String, "notif_1")
        XCTAssertEqual(result.body, "b")
    }

    func testDidReceive_threadsEarlyAndAppliesCommunicationExactlyOnce() throws {
        let helper = FlareLaneNotificationServiceExtensionHelper.shared
        let fake = FakeMediaDownloader()
        fake.avatarData = try XCTUnwrap(Self.makeAvatarData())
        helper.mediaDownloader = fake
        defer { helper.mediaDownloader = URLSessionMediaDownloader() }

        let content = UNMutableNotificationContent()
        content.body = "b"
        content.userInfo = Self.makeFlareLaneUserInfo(
            extra: [
                "threadId": "promo",
                "communication": ["senderName": "Kim", "senderImageUrl": "https://x/a.png"]
            ]
        ) as! [String: Any]
        let request = UNNotificationRequest(identifier: "notif_1", content: content, trigger: nil)

        var delivered: UNNotificationContent?
        var callCount = 0
        let expectation = expectation(description: "contentHandler")
        helper.didReceive(request) { finalContent in
            delivered = finalContent
            callCount += 1
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5)

        XCTAssertEqual(callCount, 1)
        XCTAssertTrue(fake.requestedAvatar)
        XCTAssertFalse(fake.requestedAttachment) // payload has no imageUrl
        XCTAssertEqual(delivered?.threadIdentifier, "promo")
        if #available(iOS 15.0, *) {
            // Avatar succeeded -> communication restyle applied -> delivered is the immutable copy.
            XCTAssertFalse(delivered === helper.bestAttemptContent)
        }
    }

    func testDidReceive_avatarFailureDeliversNormalNotification() {
        let helper = FlareLaneNotificationServiceExtensionHelper.shared
        let fake = FakeMediaDownloader()
        fake.avatarData = nil // download failure
        helper.mediaDownloader = fake
        defer { helper.mediaDownloader = URLSessionMediaDownloader() }

        let content = UNMutableNotificationContent()
        content.body = "b"
        content.userInfo = Self.makeFlareLaneUserInfo(
            extra: ["communication": ["senderName": "Kim", "senderImageUrl": "https://x/a.png"]]
        ) as! [String: Any]
        let request = UNNotificationRequest(identifier: "notif_1", content: content, trigger: nil)

        var delivered: UNNotificationContent?
        let expectation = expectation(description: "contentHandler")
        helper.didReceive(request) { finalContent in
            delivered = finalContent
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5)

        XCTAssertTrue(fake.requestedAvatar)
        // Fallback is the untouched bestAttemptContent — a plain app-icon notification.
        XCTAssertTrue(delivered === helper.bestAttemptContent)
    }
}

// Media downloader double: completions run synchronously on a private queue like the real
// URLSession-backed one; records which fetches were requested.
private final class FakeMediaDownloader: NotificationMediaDownloader {
    var avatarData: Data?
    var attachment: UNNotificationAttachment?
    private(set) var requestedAvatar = false
    private(set) var requestedAttachment = false
    private let callbackQueue = DispatchQueue(label: "com.flarelane.tests.fake-media-downloader")

    func downloadAttachment(from url: URL, completion: @escaping @Sendable (UNNotificationAttachment?) -> Void) {
        requestedAttachment = true
        let result = attachment
        callbackQueue.async { completion(result) }
    }

    func downloadData(from url: URL, completion: @escaping @Sendable (Data?) -> Void) {
        requestedAvatar = true
        let result = avatarData
        callbackQueue.async { completion(result) }
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


// MARK: - Retry contract
//
// Pins the retry policy and its wiring: what the caller sees, how many requests
// actually left the device, and that completions still fire exactly once now
// that a request can be sent more than once. Mirrors the Android suite.

extension Tests {

    func testRetry_transientFailuresAreRetriedRejectionsAreNot() {
        // No response at all, server-side errors, timeout and rate limit are worth another try.
        for code in [-1, 500, 502, 503, 504, 408, 429] {
            XCTAssertTrue(Request.shouldRetry(responseCode: code, attempt: 1), "\(code) should be retried")
        }
        // Every other 4xx is a decision the server would simply repeat — 410 included,
        // because it is the stop signal and must not be delayed by a backoff.
        for code in [400, 401, 403, 404, 409, 410, 422] {
            XCTAssertFalse(Request.shouldRetry(responseCode: code, attempt: 1), "\(code) should not be retried")
        }
        for code in [200, 201, 302] {
            XCTAssertFalse(Request.shouldRetry(responseCode: code, attempt: 1), "\(code) should not be retried")
        }
    }

    func testRetry_theLastAttemptIsNeverFollowedByAnother() {
        XCTAssertTrue(Request.shouldRetry(responseCode: 500, attempt: Request.maxAttempts - 1))
        XCTAssertFalse(Request.shouldRetry(responseCode: 500, attempt: Request.maxAttempts))
        XCTAssertFalse(Request.shouldRetry(responseCode: -1, attempt: Request.maxAttempts))
    }

    func testRetry_backoffStaysInsideTheAdvertisedBoundsAndIsJittered() {
        let first = (1...200).map { _ in Request.delayMillis(attempt: 1) }
        let second = (1...200).map { _ in Request.delayMillis(attempt: 2) }

        XCTAssertTrue(first.allSatisfy { (500...1000).contains($0) }, "first delays out of range")
        XCTAssertTrue(second.allSatisfy { (1500...3000).contains($0) }, "second delays out of range")
        // The random share is what keeps devices that reconnect together from retrying as one burst.
        XCTAssertGreaterThan(Set(first).count, 1)
    }

    func testRetry_aRequestThatFailsOnceSucceedsOnTheRetry() {
        Globals.projectIdInUserDefaults = "test-project-id"
        ScriptedResponseStub.script = [(503, "{}"), (200, #"{"data":{"id":"device-1"}}"#)]
        URLProtocol.registerClass(ScriptedResponseStub.self)
        defer {
            URLProtocol.unregisterClass(ScriptedResponseStub.self)
            ScriptedResponseStub.reset()
            Globals.projectIdInUserDefaults = nil
        }

        let exp = expectation(description: "completion invoked")
        var completions = 0
        var received: [String: Any]?

        Request().post(path: "/events-v2", body: ["events": []], idempotent: true) { response, _ in
            completions += 1
            received = response
            exp.fulfill()
        }

        wait(for: [exp], timeout: 15.0)
        watchForStrayCallbacks(0.3)

        XCTAssertEqual(completions, 1, "exactly one completion")
        XCTAssertNotNil(received, "caller should see the successful retry")
        XCTAssertEqual(ScriptedResponseStub.requestCount, 2, "request should have gone out twice")
    }

    func testRetry_exhaustedRetriesReportTheRealStatus() {
        Globals.projectIdInUserDefaults = "test-project-id"
        ScriptedResponseStub.script = [(503, #"{"message":"unavailable"}"#)]
        URLProtocol.registerClass(ScriptedResponseStub.self)
        defer {
            URLProtocol.unregisterClass(ScriptedResponseStub.self)
            ScriptedResponseStub.reset()
            Globals.projectIdInUserDefaults = nil
        }

        let exp = expectation(description: "completion invoked")
        var captured: Error?

        Request().post(path: "/events-v2", body: ["events": []], idempotent: true) { _, error in
            captured = error
            exp.fulfill()
        }

        wait(for: [exp], timeout: 15.0)
        watchForStrayCallbacks(3.5) // outlasts the second backoff: no fourth attempt may follow

        XCTAssertEqual(ScriptedResponseStub.requestCount, Request.maxAttempts)
        guard case Request.HTTPError.serverSideError(let status)? = captured else {
            XCTFail("expected serverSideError, got \(String(describing: captured))")
            return
        }
        XCTAssertEqual(status, 503, "the caller must see the server's status, not a placeholder")
    }

    /// 410 is the stop signal; a backoff in front of it would delay the shutdown it orders.
    func testRetry_aRejectionIsNotRetried() {
        Globals.projectIdInUserDefaults = "test-project-id"
        ScriptedResponseStub.script = [(410, #"{"message":"Gone"}"#)]
        URLProtocol.registerClass(ScriptedResponseStub.self)
        defer {
            URLProtocol.unregisterClass(ScriptedResponseStub.self)
            ScriptedResponseStub.reset()
            Globals.projectIdInUserDefaults = nil
        }

        let exp = expectation(description: "completion invoked")
        Request().patch(path: "/devices/device-1", body: [:]) { _, _ in exp.fulfill() }

        wait(for: [exp], timeout: 5.0)
        watchForStrayCallbacks(1.2) // outlasts the first backoff a wrongly scheduled retry would use

        XCTAssertEqual(ScriptedResponseStub.requestCount, 1, "410 must not be retried")
    }

    /// A POST that reached the server but lost its response would be applied twice
    /// if resent, so only calls that declared themselves idempotent may retry.
    func testRetry_aNonIdempotentRequestIsNeverRetried() {
        Globals.projectIdInUserDefaults = "test-project-id"
        ScriptedResponseStub.script = [(503, "{}")]
        URLProtocol.registerClass(ScriptedResponseStub.self)
        defer {
            URLProtocol.unregisterClass(ScriptedResponseStub.self)
            ScriptedResponseStub.reset()
            Globals.projectIdInUserDefaults = nil
        }

        let exp = expectation(description: "completion invoked")
        Request().post(path: "/devices", body: [:]) { _, _ in exp.fulfill() }

        wait(for: [exp], timeout: 5.0)
        watchForStrayCallbacks(1.2)

        XCTAssertEqual(ScriptedResponseStub.requestCount, 1,
                       "a non-idempotent request must fail on the first attempt")
    }

    /// The airplane-mode shape end to end: the connection dies without any HTTP
    /// response (status -1), the retry fires, and the next attempt delivers.
    func testRetry_aDroppedConnectionIsRetriedAndSucceeds() {
        Globals.projectIdInUserDefaults = "test-project-id"
        ScriptedResponseStub.script = [(0, ""), (200, #"{"data":{}}"#)]
        URLProtocol.registerClass(ScriptedResponseStub.self)
        defer {
            URLProtocol.unregisterClass(ScriptedResponseStub.self)
            ScriptedResponseStub.reset()
            Globals.projectIdInUserDefaults = nil
        }

        let exp = expectation(description: "completion invoked")
        var completions = 0
        var received: [String: Any]?

        Request().post(path: "/events-v2", body: ["events": []], idempotent: true) { response, _ in
            completions += 1
            received = response
            exp.fulfill()
        }

        wait(for: [exp], timeout: 15.0)
        watchForStrayCallbacks(0.3)

        XCTAssertEqual(completions, 1, "exactly one completion")
        XCTAssertNotNil(received, "caller should see the successful retry")
        XCTAssertEqual(ScriptedResponseStub.requestCount, 2, "request should have gone out twice")
    }

    func testRetry_aRetrySendsTheExactSameBody() {
        Globals.projectIdInUserDefaults = "test-project-id"
        ScriptedResponseStub.script = [(500, "{}"), (200, "{}")]
        URLProtocol.registerClass(ScriptedResponseStub.self)
        defer {
            URLProtocol.unregisterClass(ScriptedResponseStub.self)
            ScriptedResponseStub.reset()
            Globals.projectIdInUserDefaults = nil
        }

        let exp = expectation(description: "completion invoked")
        Request().post(path: "/events-v2", body: ["events": [["id": "fixed-uuid"]]], idempotent: true) { _, _ in exp.fulfill() }

        wait(for: [exp], timeout: 15.0)
        watchForStrayCallbacks(0.3)

        XCTAssertEqual(ScriptedResponseStub.bodies.count, 2)
        XCTAssertEqual(ScriptedResponseStub.bodies.first, ScriptedResponseStub.bodies.last,
                       "the retried body must be byte-identical, or the backend cannot deduplicate it")
    }

    /// Keeps watching after the completion fired: a spec asserting that no retry
    /// happened has to outlast the backoff that retry would have used, or a
    /// scheduled-but-not-fired attempt slips past the assertion unseen.
    private func watchForStrayCallbacks(_ seconds: TimeInterval) {
        let idle = expectation(description: "watch")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { idle.fulfill() }
        wait(for: [idle], timeout: seconds + 2.0)
    }
}

// MARK: - userId clear contract
//
// The server persists synchronously and echoes the full fixed device field set,
// but a cleared userId is omitted from the echo rather than sent as null. These
// specs pin that a logout actually clears the local userId — before this, the
// stale id survived forever and every later event stayed attributed to the old
// user (subjectType "user").

extension Tests {

    /// The echo omits the cleared key — an absent userId in a device echo means "no user".
    func testUserId_clearedByAnEchoThatOmitsTheKey() {
        Globals.projectIdInUserDefaults = "test-project-id"
        Globals.deviceIdInUserDefaults = "device-1"
        Globals.userIdInUserDefaults = "stale-user"
        ScriptedResponseStub.script = [(200, #"{"data":{"id":"device-1","isSubscribed":true,"tags":{}}}"#)]
        URLProtocol.registerClass(ScriptedResponseStub.self)
        defer {
            URLProtocol.unregisterClass(ScriptedResponseStub.self)
            ScriptedResponseStub.reset()
            Globals.projectIdInUserDefaults = nil
            Globals.deviceIdInUserDefaults = nil
            Globals.userIdInUserDefaults = nil
        }

        let exp = expectation(description: "update completed")
        DeviceService.update(body: ["userId": nil]) { device in
            XCTAssertNotNil(device, "the update itself must succeed")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        XCTAssertNil(Globals.userIdInUserDefaults,
                     "a device echo without a userId key must clear the stale local userId")
    }

    /// A present key still wins — set and change keep working through the same path.
    func testUserId_setByAnEchoThatCarriesTheKey() {
        Globals.projectIdInUserDefaults = "test-project-id"
        Globals.deviceIdInUserDefaults = "device-1"
        Globals.userIdInUserDefaults = nil
        ScriptedResponseStub.script = [(200, #"{"data":{"id":"device-1","isSubscribed":true,"userId":"user-a","tags":{}}}"#)]
        URLProtocol.registerClass(ScriptedResponseStub.self)
        defer {
            URLProtocol.unregisterClass(ScriptedResponseStub.self)
            ScriptedResponseStub.reset()
            Globals.projectIdInUserDefaults = nil
            Globals.deviceIdInUserDefaults = nil
            Globals.userIdInUserDefaults = nil
        }

        let exp = expectation(description: "update completed")
        DeviceService.update(body: ["userId": "user-a"]) { _ in exp.fulfill() }
        wait(for: [exp], timeout: 5.0)

        XCTAssertEqual(Globals.userIdInUserDefaults, "user-a")
    }
}

// MARK: - Stop-and-bound contract
//
// A 410 from a device endpoint shuts the SDK down for the rest of the process,
// no other outcome does, and the pending queue can never grow without limit.

extension Tests {

    func testStop_only410StopsTheSdk() {
        let manager = FlareLaneTaskManager.shared
        manager.reset()
        defer { manager.reset() }

        API.stopSdkIfGone(nil)
        API.stopSdkIfGone(URLError(.networkConnectionLost))
        for code in [400, 404, 408, 429, 500, 503] {
            API.stopSdkIfGone(Request.HTTPError.serverSideError(code))
        }

        let exp = expectation(description: "queue must still be alive")
        manager.addTaskAfterInit(taskName: "probe") { done in
            done()
            exp.fulfill()
        }
        manager.initializeComplete()
        wait(for: [exp], timeout: 5.0)
    }

    func testStop_410DropsPendingTasksAndRefusesNewOnes() {
        let manager = FlareLaneTaskManager.shared
        manager.reset()
        defer { manager.reset() }

        // NSCounter, not a plain var: the task body runs on a background queue, so
        // if a regression ever lets it execute, the assertion must fail cleanly
        // instead of reading a racy value.
        let ran = NSCounter()
        manager.addTaskAfterInit(taskName: "pending") { done in ran.increment(); done() }

        API.stopSdkIfGone(Request.HTTPError.serverSideError(410))

        manager.addTaskAfterInit(taskName: "refused") { done in ran.increment(); done() }
        manager.initializeComplete()

        let idle = expectation(description: "settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { idle.fulfill() }
        wait(for: [idle], timeout: 2.0)

        XCTAssertEqual(ran.value, 0, "neither the pending nor the new task may run after 410")
    }

    func testStop_resetLiftsTheStopSoTheNextLaunchStartsClean() {
        let manager = FlareLaneTaskManager.shared
        manager.reset()
        defer { manager.reset() }

        API.stopSdkIfGone(Request.HTTPError.serverSideError(410))
        manager.reset()

        let exp = expectation(description: "queue alive again")
        manager.addTaskAfterInit(taskName: "probe") { done in
            done()
            exp.fulfill()
        }
        manager.initializeComplete()
        wait(for: [exp], timeout: 5.0)
    }

    /// Pins the reset() drain: cancelled operations must leave operationCount, or
    /// they would keep counting against maxPendingTasks forever on a suspended queue.
    func testStop_resetDrainsCancelledTasksSoTheCapIsNotConsumed() {
        let manager = FlareLaneTaskManager.shared
        manager.reset()
        defer { manager.reset() }

        // Fill the suspended queue to its cap, then reset. Without the drain,
        // these would linger in operationCount and refuse everything below.
        for _ in 0 ..< FlareLaneTaskManager.maxPendingTasks {
            manager.addTaskAfterInit(taskName: "stale") { done in done() }
        }
        manager.reset()

        let exp = expectation(description: "a fresh task runs after reset")
        manager.addTaskAfterInit(taskName: "fresh") { done in
            done()
            exp.fulfill()
        }
        manager.initializeComplete()
        wait(for: [exp], timeout: 5.0)
    }

    func testStop_thePendingQueueNeverGrowsPastItsCap() {
        let manager = FlareLaneTaskManager.shared
        manager.reset()
        defer { manager.reset() }

        let counter = NSLock()
        var ran = 0
        let all = expectation(description: "capped tasks run")
        all.expectedFulfillmentCount = FlareLaneTaskManager.maxPendingTasks

        for _ in 0 ..< (FlareLaneTaskManager.maxPendingTasks + 20) {
            manager.addTaskAfterInit(taskName: "bulk") { done in
                counter.lock(); ran += 1; counter.unlock()
                all.fulfill()
                done()
            }
        }
        manager.initializeComplete()

        wait(for: [all], timeout: 30.0)
        let idle = expectation(description: "settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { idle.fulfill() }
        wait(for: [idle], timeout: 2.0)

        counter.lock(); let total = ran; counter.unlock()
        XCTAssertEqual(total, FlareLaneTaskManager.maxPendingTasks,
                       "tasks beyond the cap must have been refused at add time")
    }
}

// Replays a scripted sequence of responses, one per request, and records the bodies that were sent.
// Past the end of the script the last entry repeats, so a test only spells out what it cares about.
private final class ScriptedResponseStub: URLProtocol {
    static var script: [(status: Int, body: String)] = []
    private static let lock = NSLock()
    private static var sentBodies: [Data] = []

    static var requestCount: Int { lock.withLock { sentBodies.count } }
    static var bodies: [Data] { lock.withLock { sentBodies } }

    static func reset() {
        script = []
        lock.withLock { sentBodies = [] }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "service-api.flarelane.com"
    }

    // URLProtocol strips httpBody from the request it hands over, so the bytes are read from
    // httpBodyStream when that is where they ended up.
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let index = Self.lock.withLock { () -> Int in
            let index = Self.sentBodies.count
            Self.sentBodies.append(Self.body(of: request))
            return index
        }

        let entry = Self.script.isEmpty ? nil : (Self.script.count > index ? Self.script[index] : Self.script.last)

        // status 0 slams the connection without an HTTP response — the airplane-mode
        // shape: the client sees a transport error and no status code at all.
        if entry?.status == 0 {
            client?.urlProtocol(self, didFailWithError: URLError(.networkConnectionLost))
            return
        }

        guard let url = request.url,
              let entry = entry,
              let response = HTTPURLResponse(
                url: url,
                statusCode: entry.status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
              ) else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(entry.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func body(of request: URLRequest) -> Data {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return Data()
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

private extension NSLock {
    func withLock<T>(_ block: () -> T) -> T {
        lock()
        defer { unlock() }
        return block()
    }
}

/// Thread-safe counter for the concurrency spec above.
private final class NSCounter {
    private let lock = NSLock()
    private var count = 0

    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
}
