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
}
