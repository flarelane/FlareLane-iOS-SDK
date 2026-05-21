import XCTest
@testable import FlareLane

/// # FlareLane iOS SDK spec
///
/// session 개념을 SDK에서 들어내고 나서 남은 spec들 — 호스트 event payload에 SDK가 키를 끼워
/// 넣는 것은 무결성 위반이라 전부 제거. SDK가 보장하는 것:
///  - **push event 중복 차단** (EventDeduplicator)
///  - 호환성 shim (clearProcessedNotificationIds)
///  - TaskManager thread-safety (race 보호)
///  - UserDefaults round-trip
///  - SdkInfo metadata 무결성
class Tests: XCTestCase {

    override func tearDown() {
        // EventDeduplicator는 process-lifetime singleton. test 간 누설 막기 위해 cap 두 번 넘김.
        for i in 0...201 { _ = EventDeduplicator.markAndCheckDuplicate(eventType: "__purge1__", notificationId: "\(i)") }
        for i in 0...201 { _ = EventDeduplicator.markAndCheckDuplicate(eventType: "__purge2__", notificationId: "\(i)") }
        super.tearDown()
    }

    // MARK: - EventDeduplicator spec (Android의 EventDeduplicatorTest와 1:1)

    func test_EventDeduplicator_처음_본_이벤트는_false() {
        XCTAssertFalse(EventDeduplicator.markAndCheckDuplicate(eventType: "CLICKED", notificationId: "n1"))
    }

    func test_EventDeduplicator_두번째_같은_이벤트는_true() {
        _ = EventDeduplicator.markAndCheckDuplicate(eventType: "CLICKED", notificationId: "n2")
        XCTAssertTrue(EventDeduplicator.markAndCheckDuplicate(eventType: "CLICKED", notificationId: "n2"))
    }

    func test_EventDeduplicator_eventType이_다르면_별개() {
        XCTAssertFalse(EventDeduplicator.markAndCheckDuplicate(eventType: "CLICKED", notificationId: "n3"))
        XCTAssertFalse(EventDeduplicator.markAndCheckDuplicate(eventType: "RECEIVED", notificationId: "n3"))
        XCTAssertTrue(EventDeduplicator.markAndCheckDuplicate(eventType: "CLICKED", notificationId: "n3"))
        XCTAssertTrue(EventDeduplicator.markAndCheckDuplicate(eventType: "RECEIVED", notificationId: "n3"))
    }

    func test_EventDeduplicator_cap_초과_시_자동_wipe() {
        _ = EventDeduplicator.markAndCheckDuplicate(eventType: "CLICKED", notificationId: "early")
        XCTAssertTrue(EventDeduplicator.markAndCheckDuplicate(eventType: "CLICKED", notificationId: "early"))
        for i in 0..<220 { _ = EventDeduplicator.markAndCheckDuplicate(eventType: "FILL", notificationId: "\(i)") }
        XCTAssertFalse(
            EventDeduplicator.markAndCheckDuplicate(eventType: "CLICKED", notificationId: "early"),
            "wipe된 뒤엔 다시 첫 관찰로 처리돼야 함"
        )
    }

    // MARK: - NotificationClickProcessor source-compat shim
    //
    // 옛 SDK의 `@objc public static func clearProcessedNotificationIds()`가 deprecated no-op으로
    // 살아있어야 외부 caller가 컴파일 깨지지 않음.

    func test_clearProcessedNotificationIds_no_op_호출_가능() {
        NotificationClickProcessor.clearProcessedNotificationIds()
        XCTAssertFalse(EventDeduplicator.markAndCheckDuplicate(eventType: "CLICKED", notificationId: "after-shim"))
    }

    // MARK: - FlareLaneTaskManager thread-safety

    func test_TaskManager_정상_완료_경로() {
        FlareLaneTaskManager.shared.initializeComplete()
        let exp = expectation(description: "task completes")
        FlareLaneTaskManager.shared.addTaskAfterInit(taskName: "normal", timeout: 5.0) { completion in
            DispatchQueue.global().async {
                completion()
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 6.0)
    }

    func test_TaskManager_timeout_경로_후에도_다음_task_진행() {
        FlareLaneTaskManager.shared.initializeComplete()
        FlareLaneTaskManager.shared.addTaskAfterInit(taskName: "neverComplete", timeout: 0.3) { _ in
            // 의도적으로 completion 호출 안 함
        }
        let exp = expectation(description: "next task runs after prior timeout")
        FlareLaneTaskManager.shared.addTaskAfterInit(taskName: "next", timeout: 5.0) { completion in
            DispatchQueue.global().async {
                completion()
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 6.0)
    }

    // MARK: - Globals UserDefaults round-trip

    func test_Globals_projectId_round_trip() {
        let original = Globals.projectIdInUserDefaults
        defer { Globals.projectIdInUserDefaults = original }

        Globals.projectIdInUserDefaults = "spec-proj-id"
        XCTAssertEqual("spec-proj-id", Globals.projectIdInUserDefaults)

        Globals.projectIdInUserDefaults = nil
        XCTAssertNil(Globals.projectIdInUserDefaults)
    }

    // MARK: - SDK metadata

    func test_SdkInfo_metadata() {
        XCTAssertFalse(Globals.sdkVersion.isEmpty)
        XCTAssertEqual(Globals.sdkType, .native)
    }
}
