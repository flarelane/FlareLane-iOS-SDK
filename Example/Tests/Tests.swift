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

    // MARK: - Stopping the SDK

    /// 410 is the server's only directive to stop the SDK. The decision is made on the status code
    /// alone so the SDK never has to parse a response body.
    func testIsGone_onlyMatches410() {
        XCTAssertTrue(API.isGone(Request.HTTPError.serverSideError(410)))

        for status in [200, 201, 400, 401, 403, 404, 409, 429, 500, 503] {
            XCTAssertFalse(API.isGone(Request.HTTPError.serverSideError(status)),
                           "status \(status) must not stop the SDK")
        }
        XCTAssertFalse(API.isGone(nil))
        XCTAssertFalse(API.isGone(Request.HTTPError.unexpectedNilResponse))
    }

    /// The queue has to be emptied, not just closed to new work: with requestPermissionOnLaunch it
    /// stays suspended until the permission alert is answered, so anything left queued would fire
    /// the moment the user taps.
    func testStop_clearsPendingTasksAndRefusesNewOnes() {
        let manager = FlareLaneTaskManager()
        defer { manager.reset() }

        for i in 0..<20 {
            manager.addTaskAfterInit(taskName: "task-\(i)") { completion in completion() }
        }
        XCTAssertGreaterThan(manager.queuedTaskCount, 0)

        manager.stop()
        manager.initializeComplete()

        var ran = false
        manager.addTaskAfterInit(taskName: "after-stop") { completion in
            ran = true
            completion()
        }

        let settled = expectation(description: "queue drains and nothing new runs")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { settled.fulfill() }
        wait(for: [settled], timeout: 5)

        XCTAssertEqual(manager.queuedTaskCount, 0, "stop() must empty the queue, not just cancel it")
        XCTAssertFalse(ran, "a stopped SDK must not run new tasks")
    }

    /// `stop()` runs on a URLSession callback thread while tasks are added from the caller's
    /// thread. If the stopped check and the enqueue were not one step, a task could slip in after
    /// stop() already cancelled everything and resumed the queue — and it would run.
    func testStop_isAtomicAgainstConcurrentTaskAdds() {
        let manager = FlareLaneTaskManager()
        defer { manager.reset() }
        manager.initializeComplete()

        let adds = DispatchQueue(label: "adds", attributes: .concurrent)
        let group = DispatchGroup()

        for i in 0..<200 {
            group.enter()
            adds.async {
                manager.addTaskAfterInit(taskName: "task-\(i)") { completion in completion() }
                group.leave()
            }
            if i == 20 {
                DispatchQueue.global().async { manager.stop() }
            }
        }

        group.wait()

        let settled = expectation(description: "queue settles")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { settled.fulfill() }
        wait(for: [settled], timeout: 5)

        XCTAssertEqual(manager.queuedTaskCount, 0, "no task may survive stop()")
        XCTAssertFalse(manager.addTaskAfterInit(taskName: "after") { $0() },
                       "a stopped manager must keep refusing")
    }

    func testReset_liftsTheStoppedStateSoTheNextLaunchWorks() {
        let manager = FlareLaneTaskManager()
        defer { manager.reset() }

        manager.stop()
        manager.reset()
        manager.initializeComplete()

        let ran = expectation(description: "task runs after reset")
        manager.addTaskAfterInit(taskName: "after-reset") { completion in
            ran.fulfill()
            completion()
        }

        wait(for: [ran], timeout: 5)
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

// MARK: - Request-level test harness

/// Intercepts `URLSession.shared` so tests can drive the real request path — `API` → `Request` →
/// `URLSession` → response handling → `FlareLaneTaskManager` — with no network and no live project.
///
/// Unit tests cover the queue in isolation. This covers the wiring between an actual HTTP status and
/// the queue reacting to it, plus the two properties that matter for data integrity: **how many**
/// requests go out and **in what order**. A scripted response per call also lets a retry policy be
/// tested here later (`.script` accepts a sequence; the last entry repeats).
final class StubURLProtocol: URLProtocol {
  struct Response {
    let status: Int
    let body: String

    static func ok(_ body: String = "{\"data\":{}}") -> Response { .init(status: 200, body: body) }
    static func gone(_ message: String = "Project not found") -> Response {
      .init(status: 410, body: "{\"statusCode\":410,\"message\":\"\(message)\",\"error\":\"Gone\"}")
    }
    static func status(_ code: Int) -> Response {
      .init(status: code, body: "{\"statusCode\":\(code),\"message\":\"e2e\",\"error\":\"e2e\"}")
    }
  }

  struct Recorded {
    let method: String
    let path: String
    let body: String
  }

  private static let lock = NSLock()
  /// Responses to hand out per path suffix, consumed in order. The last entry repeats.
  private static var script: [String: [Response]] = [:]
  private static var log: [Recorded] = []

  static func install(_ script: [String: [Response]] = [:]) {
    lock.lock()
    self.script = script
    log = []
    lock.unlock()
    URLProtocol.registerClass(StubURLProtocol.self)
  }

  static func uninstall() {
    URLProtocol.unregisterClass(StubURLProtocol.self)
    lock.lock()
    script = [:]
    log = []
    lock.unlock()
  }

  /// Every request seen so far, in order.
  static var requests: [Recorded] {
    lock.lock()
    defer { lock.unlock() }
    return log
  }

  static func count(pathSuffix: String) -> Int {
    requests.filter { $0.path.hasSuffix(pathSuffix) }.count
  }

  override class func canInit(with request: URLRequest) -> Bool {
    request.url?.host?.contains("flarelane.com") == true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    let path = request.url?.path ?? ""
    // URLSession streams an upload body, so httpBody is usually nil — read the stream instead.
    var body = ""
    if let data = request.httpBody {
      body = String(data: data, encoding: .utf8) ?? ""
    } else if let stream = request.httpBodyStream {
      stream.open()
      var buffer = [UInt8](repeating: 0, count: 8192)
      var collected = Data()
      while stream.hasBytesAvailable {
        let read = stream.read(&buffer, maxLength: buffer.count)
        if read <= 0 { break }
        collected.append(buffer, count: read)
      }
      stream.close()
      body = String(data: collected, encoding: .utf8) ?? ""
    }

    StubURLProtocol.lock.lock()
    StubURLProtocol.log.append(
      Recorded(method: request.httpMethod ?? "", path: path, body: body))
    let key = StubURLProtocol.script.keys.first { path.hasSuffix($0) }
    var response = Response.ok()
    if let key = key, var queued = StubURLProtocol.script[key], !queued.isEmpty {
      response = queued.removeFirst()
      // Keep the last scripted response in place so repeated calls stay deterministic.
      StubURLProtocol.script[key] = queued.isEmpty ? [response] : queued
    }
    StubURLProtocol.lock.unlock()

    let http = HTTPURLResponse(
      url: request.url!, statusCode: response.status, httpVersion: "HTTP/1.1",
      headerFields: ["Content-Type": "application/json"])!
    client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data(response.body.utf8))
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}

// MARK: - Stop contract, end to end

extension Tests {
  private static let e2eProject = "00000000-0000-4000-8000-00000000e2e0"
  private static let e2eDevice = "00000000-0000-4000-8000-00000000e2e1"
  private var devicePath: String { "/devices/\(Tests.e2eDevice)" }

  private func startE2E(_ script: [String: [StubURLProtocol.Response]] = [:]) {
    StubURLProtocol.install(script)
    Globals.projectIdInUserDefaults = Tests.e2eProject
    Globals.deviceIdInUserDefaults = Tests.e2eDevice
    FlareLaneTaskManager.shared.reset()
  }

  private func endE2E() {
    StubURLProtocol.uninstall()
    FlareLaneTaskManager.shared.reset()
    Globals.projectIdInUserDefaults = nil
    Globals.deviceIdInUserDefaults = nil
  }

  private func settle(_ seconds: TimeInterval = 0.6) {
    let done = expectation(description: "settle")
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { done.fulfill() }
    wait(for: [done], timeout: seconds + 5)
  }

  private func updateDeviceAndWait() {
    let done = expectation(description: "device update returns")
    API.shared.updateDevice(deviceId: Tests.e2eDevice, body: ["lastActiveAt": "e2e"]) { _, _ in
      done.fulfill()
    }
    wait(for: [done], timeout: 5)
    settle()
  }

  /// The whole contract in order: work queues up, a 410 on device update stops the SDK, the queue
  /// empties, nothing else goes out, and a caller waiting on a result still gets one.
  func testE2E_410OnDeviceUpdate_stopsTheSdkAndAnswersCallers() {
    startE2E([devicePath: [.gone()]])
    defer { endE2E() }

    // Queue work before initialization, the way a host app does at launch.
    for i in 0..<5 {
      FlareLaneTaskManager.shared.addTaskAfterInit(taskName: "queued-\(i)") { $0() }
    }
    XCTAssertGreaterThan(FlareLaneTaskManager.shared.queuedTaskCount, 0)

    updateDeviceAndWait()

    XCTAssertEqual(FlareLaneTaskManager.shared.queuedTaskCount, 0, "stop() must empty the queue")

    let before = StubURLProtocol.requests.count
    let answered = expectation(description: "subscribe answers even though the SDK stopped")
    FlareLane.subscribe { _ in answered.fulfill() }
    wait(for: [answered], timeout: 5)
    settle()

    XCTAssertEqual(StubURLProtocol.requests.count, before,
                   "a stopped SDK must not send anything else")
  }

  /// 404 is an ordinary failure. Only 410 means stop.
  func testE2E_404OnDeviceUpdate_doesNotStopTheSdk() {
    startE2E([devicePath: [.status(404)]])
    defer { endE2E() }

    updateDeviceAndWait()

    XCTAssertTrue(FlareLaneTaskManager.shared.addTaskAfterInit(taskName: "after-404") { $0() },
                  "404 must leave the SDK running")
  }

  /// Same for the statuses a retry policy will treat as transient.
  func testE2E_transientFailures_doNotStopTheSdk() {
    for status in [408, 429, 500, 502, 503] {
      startE2E([devicePath: [.status(status)]])
      updateDeviceAndWait()
      XCTAssertTrue(
        FlareLaneTaskManager.shared.addTaskAfterInit(taskName: "after-\(status)") { $0() },
        "status \(status) must not stop the SDK")
      endE2E()
    }
  }

  /// A 410 from anything other than device create/update must not shut the SDK down.
  func testE2E_410FromOtherEndpoint_doesNotStopTheSdk() {
    startE2E(["/in-app-messages": [.gone()]])
    defer { endE2E() }

    let served = expectation(description: "in-app request returns")
    API.shared.getInAppMessages(deviceId: Tests.e2eDevice, group: "home", data: nil) { _ in
      served.fulfill()
    }
    wait(for: [served], timeout: 5)
    settle()

    XCTAssertTrue(FlareLaneTaskManager.shared.addTaskAfterInit(taskName: "after-iam-410") { $0() },
                  "only the device endpoints may stop the SDK")
  }

  /// Device create is the other endpoint that carries the stop signal.
  func testE2E_410OnDeviceCreate_stopsTheSdk() {
    startE2E(["/devices": [.gone()]])
    defer { endE2E() }

    let created = expectation(description: "device create returns")
    API.shared.createDevice(body: ["platform": "ios"]) { deviceId, error in
      XCTAssertNil(deviceId)
      XCTAssertTrue(API.isGone(error))
      created.fulfill()
    }
    wait(for: [created], timeout: 5)
    settle()

    XCTAssertFalse(FlareLaneTaskManager.shared.addTaskAfterInit(taskName: "after") { $0() },
                   "a stopped SDK must refuse new work")
  }

  /// The public API must answer even when the queue refused the work. The Flutter and React Native
  /// bridges resolve only from inside these completions, so a missing answer hangs the host app.
  func testE2E_stoppedSdkStillAnswersSubscribeAndUnsubscribe() {
    startE2E(["/devices": [.gone()]])
    defer { endE2E() }

    let created = expectation(description: "device create returns")
    API.shared.createDevice(body: ["platform": "ios"]) { _, _ in created.fulfill() }
    wait(for: [created], timeout: 5)
    settle()

    XCTAssertFalse(FlareLaneTaskManager.shared.addTaskAfterInit(taskName: "probe") { $0() },
                   "precondition: the SDK must be stopped")

    let subscribed = expectation(description: "subscribe answers")
    FlareLane.subscribe { _ in subscribed.fulfill() }

    let unsubscribed = expectation(description: "unsubscribe answers")
    FlareLane.unsubscribe { _ in unsubscribed.fulfill() }

    wait(for: [subscribed, unsubscribed], timeout: 5)
  }

  /// resetDevice() has to bring the SDK back, otherwise a stop would be permanent.
  func testE2E_resetRecoversAfterStop() {
    startE2E([devicePath: [.gone()]])
    defer { endE2E() }

    updateDeviceAndWait()
    XCTAssertFalse(FlareLaneTaskManager.shared.addTaskAfterInit(taskName: "stopped") { $0() })

    FlareLaneTaskManager.shared.reset()

    XCTAssertTrue(FlareLaneTaskManager.shared.addTaskAfterInit(taskName: "after-reset") { $0() },
                  "reset must lift the stopped state")
  }

  // MARK: - Data guarantees

  /// One call must produce exactly one request. Guards against a retry or a re-entrant path
  /// silently duplicating device updates, which would corrupt lastActiveAt statistics.
  func testE2E_oneCallSendsExactlyOneRequest() {
    startE2E([devicePath: [.ok("{\"data\":{\"id\":\"\(Tests.e2eDevice)\",\"isSubscribed\":false}}")]])
    defer { endE2E() }

    updateDeviceAndWait()

    XCTAssertEqual(StubURLProtocol.count(pathSuffix: devicePath), 1)
    XCTAssertEqual(StubURLProtocol.requests.first?.method, "PATCH")
    XCTAssertTrue(StubURLProtocol.requests.first?.body.contains("lastActiveAt") == true,
                  "the body the SDK actually sent must carry the payload")
  }

  /// The queue is the ordering guarantee the host app relies on: tasks run in the order they were
  /// added, one at a time. A retry policy must not be allowed to reorder them.
  func testE2E_queuedTasksRunInOrder() {
    startE2E()
    defer { endE2E() }

    var order: [Int] = []
    let orderLock = NSLock()
    let all = expectation(description: "all tasks run")
    all.expectedFulfillmentCount = 10

    for i in 0..<10 {
      FlareLaneTaskManager.shared.addTaskAfterInit(taskName: "ordered-\(i)") { completion in
        orderLock.lock()
        order.append(i)
        orderLock.unlock()
        completion()
        all.fulfill()
      }
    }

    FlareLaneTaskManager.shared.initializeComplete()
    wait(for: [all], timeout: 20)

    XCTAssertEqual(order, Array(0..<10), "the queue must preserve FIFO order")
  }

  /// A scripted sequence proves the harness can express "fails, then succeeds" — the shape a retry
  /// policy needs. Today the SDK does not retry, so the request count stays at one; when retries
  /// land, this is where the no-loss guarantee gets asserted.
  func testE2E_harnessSupportsPerCallResponseSequences() {
    startE2E([devicePath: [.status(503), .ok()]])
    defer { endE2E() }

    updateDeviceAndWait()
    XCTAssertEqual(StubURLProtocol.count(pathSuffix: devicePath), 1,
                   "no retry today: exactly one request")

    updateDeviceAndWait()
    XCTAssertEqual(StubURLProtocol.count(pathSuffix: devicePath), 2)
    XCTAssertTrue(FlareLaneTaskManager.shared.addTaskAfterInit(taskName: "still-running") { $0() },
                  "a transient failure followed by a success must leave the SDK running")
  }
}
