import StoreKitTest
import XCTest

final class StockNoteUITests: XCTestCase {
    private func launch(reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = reset ? ["-resetData", "-seedSampleData"] : []
        app.launch()
        return app
    }

    private func slider(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.sliders.matching(NSPredicate(format: "label == %@", "\(name)の残量")).firstMatch
    }

    private func restockButton(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.buttons["restock-\(name)"]
    }

    /// 要素が画面に見えていて、下に固定した広告枠に隠れていない
    private func isClearlyVisible(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        guard element.exists, element.isHittable else { return false }
        let adLink = app.buttons["ad-remove-link"]
        guard adLink.exists else { return true }
        return element.frame.maxY < adLink.frame.minY
    }

    /// リストは画面外の行を作らないので、見えるまで上下にスクロールして探す
    @discardableResult
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        _ = element.waitForExistence(timeout: 5)
        if isClearlyVisible(element, in: app) { return true }
        for _ in 0..<6 {
            app.swipeUp()
            if isClearlyVisible(element, in: app) { return true }
        }
        for _ in 0..<12 {
            app.swipeDown()
            if isClearlyVisible(element, in: app) { return true }
        }
        return false
    }

    func testRestockResetsRemainingAndLeavesAttention() {
        let app = launch()
        let s = slider(app, "食器用洗剤")
        XCTAssertTrue(reveal(s, in: app))
        XCTAssertEqual(s.value as? String, "25%")

        restockButton(app, "食器用洗剤").tap()

        // 100% になった品は「要確認」から外れて下へ移るので、スクロールして探し直す
        let after = slider(app, "食器用洗剤")
        XCTAssertTrue(reveal(after, in: app))
        XCTAssertEqual(after.value as? String, "100%")
        XCTAssertFalse(restockButton(app, "食器用洗剤").exists, "買ったあとは要確認から外れ、ボタンも消える")
    }

    func testSliderChangePersistsAcrossRelaunch() {
        var app = launch()
        let s = slider(app, "シャンプー")
        XCTAssertTrue(reveal(s, in: app))
        XCTAssertEqual(s.value as? String, "50%")
        XCTAssertFalse(restockButton(app, "シャンプー").exists, "50% は要確認ではない")

        s.adjust(toNormalizedSliderPosition: 0)

        // 0% になると「要確認」の先頭側へ移り、買ったボタンが出る
        let moved = slider(app, "シャンプー")
        XCTAssertTrue(reveal(moved, in: app))
        XCTAssertEqual(moved.value as? String, "0%")
        XCTAssertTrue(restockButton(app, "シャンプー").waitForExistence(timeout: 3))

        app.terminate()
        app = launch(reset: false)
        let again = slider(app, "シャンプー")
        XCTAssertTrue(reveal(again, in: app))
        XCTAssertEqual(again.value as? String, "0%")
    }

    func testDisasterItemHasNoSliderAndCheckButton() {
        let app = launch()
        XCTAssertTrue(app.buttons["飲料水"].waitForExistence(timeout: 10))
        XCTAssertFalse(slider(app, "飲料水").exists)
        let check = app.buttons["check-飲料水"]
        XCTAssertTrue(reveal(check, in: app), "広告枠の下に隠れたままではなく、スクロールで押せる位置に来る")
        check.tap()
    }

    func testAddItemFromForm() {
        let app = launch()
        XCTAssertTrue(app.buttons["食器用洗剤"].waitForExistence(timeout: 10))
        app.navigationBars.buttons["追加"].tap()
        app.buttons["品目を追加"].tap()
        let field = app.textFields["品名"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("ハンドソープ")
        app.buttons["保存"].tap()

        let added = slider(app, "ハンドソープ")
        XCTAssertTrue(reveal(added, in: app))
        XCTAssertEqual(added.value as? String, "100%")
    }

    /// StoreKit のテスト設定(StockNote.storekit)で、購入 → 広告が消えた表示 → 復元、までを通す
    func testRemoveAdsPurchase() throws {
        let session = try SKTestSession(configurationFileNamed: "StockNote")
        session.disableDialogs = true
        session.clearTransactions()
        addTeardownBlock { session.clearTransactions() }   // 購入済みの状態をシミュレータに残さない

        let app = launch()
        XCTAssertTrue(app.buttons["食器用洗剤"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["ad-remove-link"].waitForExistence(timeout: 10), "未購入なら、一覧の下に広告枠(と「広告を消す」)が出る")
        app.navigationBars.buttons["設定"].tap()
        let buy = app.buttons["remove-ads"]
        XCTAssertTrue(buy.waitForExistence(timeout: 5))
        // 商品情報の読み込みを待つ(価格が入る)
        let priced = expectation(for: NSPredicate(format: "label CONTAINS '160'"), evaluatedWith: buy)
        wait(for: [priced], timeout: 20)
        buy.tap()

        XCTAssertTrue(app.staticTexts["広告を消しました。ありがとうございます"].waitForExistence(timeout: 20))
        XCTAssertFalse(buy.exists)

        app.buttons["完了"].tap()
        XCTAssertTrue(app.buttons["食器用洗剤"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["ad-remove-link"].exists, "購入後は広告枠が消える")
    }

    /// App Store 用のスクリーンショット。`TEST_RUNNER_SCREENSHOT_DIR=出力先` を付けたときだけ動く(普段はスキップ)。
    func testAppStoreScreenshots() throws {
        let env = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"]
        try XCTSkipUnless(env != nil, "SCREENSHOT_DIR がないのでスキップ")
        let dir = env!
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        func shot(_ app: XCUIApplication, _ name: String) throws {
            Thread.sleep(forTimeInterval: 1)
            try app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }

        let session = try SKTestSession(configurationFileNamed: "StockNote")
        session.disableDialogs = true
        session.clearTransactions()
        addTeardownBlock { session.clearTransactions() }

        let app = XCUIApplication()
        app.launchArguments = ["-resetData", "-seedSampleData", "-hideAds"]
        app.launch()
        XCTAssertTrue(app.buttons["食器用洗剤"].waitForExistence(timeout: 10))
        try shot(app, "01-list")

        app.buttons["防災バッグ"].tap()
        XCTAssertTrue(app.buttons["飲料水"].waitForExistence(timeout: 5))
        try shot(app, "02-disaster")

        app.buttons["すべて"].tap()
        app.navigationBars.buttons["追加"].tap()
        app.buttons["品目を追加"].tap()
        let field = app.textFields["品名"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("洗濯洗剤\n")   // 改行でキーボードを閉じる
        XCTAssertFalse(app.keyboards.firstMatch.waitForExistence(timeout: 2), "キーボードが閉じている")
        app.swipeUp()   // 残量と期限の欄を見せる
        let expiryToggle = app.switches["期限がある"]
        XCTAssertTrue(expiryToggle.waitForExistence(timeout: 3))
        // 行の中央ではなく、右端のスイッチ本体を押す
        expiryToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5)).tap()
        XCTAssertEqual(expiryToggle.value as? String, "1", "期限のスイッチがオンになる")
        XCTAssertTrue(app.datePickers.firstMatch.exists || app.buttons.matching(NSPredicate(format: "label CONTAINS '警告を出す時期'")).firstMatch.waitForExistence(timeout: 3), "期限の入力欄が現れる")
        try shot(app, "03-edit")
        app.buttons["キャンセル"].tap()

        app.navigationBars.buttons["追加"].tap()
        app.buttons["防災バッグの定番から追加"].tap()
        for name in ["懐中電灯", "携帯ラジオ", "簡易カイロ"] {
            let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 5))
            row.tap()
        }
        try shot(app, "04-disaster-kit")
        app.buttons["キャンセル"].tap()

        app.navigationBars.buttons["設定"].tap()
        let priced = expectation(for: NSPredicate(format: "label CONTAINS '160'"), evaluatedWith: app.buttons["remove-ads"])
        wait(for: [priced], timeout: 20)
        try shot(app, "05-settings")
    }

    /// 初めて期限を入れたときに通知の許可を聞き、許可すると予約されること。
    /// `TEST_RUNNER_PENDING_DUMP=書き出し先` を付けたときだけ動く。
    func testExpiryNotificationIsScheduledAfterPermission() throws {
        let env = ProcessInfo.processInfo.environment["PENDING_DUMP"]
        try XCTSkipUnless(env != nil, "PENDING_DUMP がないのでスキップ")
        let dump = env!
        try? FileManager.default.removeItem(atPath: dump)

        let app = XCUIApplication()
        app.launchArguments = ["-resetData", "-hideAds"]
        app.launchEnvironment["PENDING_DUMP"] = dump
        app.launch()

        app.buttons["品目を追加"].firstMatch.tap()   // 空の画面の「品目を追加」
        let field = app.textFields["品名"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("牛乳\n")
        app.swipeUp()
        let toggle = app.switches["期限がある"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5)).tap()
        XCTAssertEqual(toggle.value as? String, "1")
        app.buttons["保存"].tap()

        // 初めて期限を入れたので、通知の許可を聞かれる
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.alerts.buttons.matching(NSPredicate(format: "label IN {'許可', 'Allow'}")).firstMatch
        XCTAssertTrue(allow.waitForExistence(timeout: 10), "通知の許可ダイアログが出る")
        allow.tap()

        // 許可のあと、予約される(書き出しファイルに牛乳が現れる)
        let deadline = Date().addingTimeInterval(15)
        var text = ""
        while Date() < deadline {
            text = (try? String(contentsOfFile: dump, encoding: .utf8)) ?? ""
            if text.contains("牛乳") { break }
            Thread.sleep(forTimeInterval: 0.5)
        }
        print("PENDING-DUMP: \(text)")
        XCTAssertTrue(text.contains("牛乳"), "許可した直後に、期限の通知が予約される")
    }

    /// 通知を「許可しない」にしても、品目は普通に保存・表示でき、通知は予約されない。
    func testDenyingNotificationPermissionKeepsAppWorking() throws {
        let env = ProcessInfo.processInfo.environment["PENDING_DUMP"]
        try XCTSkipUnless(env != nil, "PENDING_DUMP がないのでスキップ")
        let dump = env!
        try? FileManager.default.removeItem(atPath: dump)

        let app = XCUIApplication()
        app.launchArguments = ["-resetData", "-hideAds"]
        app.launchEnvironment["PENDING_DUMP"] = dump
        app.launch()

        app.buttons["品目を追加"].firstMatch.tap()
        let field = app.textFields["品名"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("牛乳\n")
        app.swipeUp()
        let toggle = app.switches["期限がある"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5)).tap()
        app.buttons["保存"].tap()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deny = springboard.alerts.buttons["許可しない"]
        XCTAssertTrue(deny.waitForExistence(timeout: 10), "通知の許可ダイアログが出る")
        deny.tap()

        // 品目は保存されて一覧に出る。アプリは落ちていない
        XCTAssertTrue(app.buttons["牛乳"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.state, .runningForeground)

        // 続けて品目を編集しても問題なく保存でき、聞き直しのダイアログは出ない
        app.buttons["牛乳"].tap()
        let name = app.textFields["品名"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("パック\n")
        app.buttons["保存"].tap()
        XCTAssertTrue(app.buttons["牛乳パック"].waitForExistence(timeout: 10))
        XCTAssertFalse(springboard.alerts.firstMatch.waitForExistence(timeout: 2), "拒否したあとは、許可を聞き直さない")

        // 通知は予約されていない(予約すれば書き出しファイルに現れる)
        let text = (try? String(contentsOfFile: dump, encoding: .utf8)) ?? ""
        XCTAssertFalse(text.contains("牛乳"), "許可がないので、通知は予約されない")
    }
}
