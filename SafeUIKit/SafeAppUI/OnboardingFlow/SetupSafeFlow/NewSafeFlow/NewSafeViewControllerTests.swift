//
//  Copyright © 2018 Gnosis Ltd. All rights reserved.
//

import XCTest
@testable import SafeAppUI
import IdentityAccessApplication
import CommonTestSupport
import SafeUIKit

class NewSafeViewControllerTests: SafeTestCase {

    // swiftlint:disable:next weak_delegate
    private let delegate = MockNewSafeDelegate()
    private var controller: NewSafeViewController!

    override func setUp() {
        super.setUp()
        walletService.createNewDraftWallet()
        controller = NewSafeViewController.create(delegate: delegate)
        controller.loadViewIfNeeded()
    }

    func test_canCreate() {
        XCTAssertNotNil(controller)
        XCTAssertNotNil(controller.mobileAppButton)
        XCTAssertNotNil(controller.browserExtensionButton)
        XCTAssertNotNil(controller.recoveryPhraseButton)
        XCTAssertFalse(controller.mobileAppButton.isEnabled)
        XCTAssertFalse(controller.nextButton.isEnabled)
    }

    func test_setupRecoveryPhrase_callsDelegate() {
        controller.setupRecoveryPhrase(self)
        XCTAssertTrue(delegate.hasSelectedPaperWalletSetup)
    }

    func test_setupBrowserExtension_callsDelegate() {
        controller.setupBrowserExtension(self)
        XCTAssertTrue(delegate.hasSelectedBrowserExtensionSetup)
    }

    func test_viewDidLoad_whenNoDraftSafe_thenDismissesAndLogs() {
        walletService.expect_hasSelectedWallet(false)
        controller = NewSafeViewController.create(delegate: delegate)
        createWindow(controller)
        controller.viewDidLoad()
        delay(1)
        XCTAssertNil(controller.view.window)
        XCTAssertTrue(logger.errorLogged)
    }

    func test_viewWillAppear_whenDraftSafeHasConfiguredAddress_thenCheckmarksAreSet() {
        walletService.addOwner(address: "address", type: .thisDevice)
        controller.viewWillAppear(false)
        assertButtonCheckmarks(.selected, .normal, .normal)

        walletService.addOwner(address: "address", type: .paperWallet)
        controller.viewWillAppear(false)
        assertButtonCheckmarks(.selected, .selected, .normal)

        walletService.addOwner(address: "address", type: .browserExtension)
        controller.viewWillAppear(false)
        assertButtonCheckmarks(.selected, .selected, .selected)
    }

    func test_viewWillAppear_whenDraftIsReady_thenNextButtonIsEnabled() {
        walletService.createReadyToDeployWallet()
        controller.viewWillAppear(false)
        XCTAssertTrue(controller.nextButton.isEnabled)
    }

    func test_navigateNext_callsDelegate() {
        controller.navigateNext(self)
        delay()
        XCTAssertTrue(delegate.nextSelected)
    }

}

extension NewSafeViewControllerTests {

    private func assertButtonCheckmarks(_ thisDeviceCheckmark: CheckmarkButton.CheckmarkStatus,
                                        _ paperWalletCheckmark: CheckmarkButton.CheckmarkStatus,
                                        _ browserExtensionCheckmark: CheckmarkButton.CheckmarkStatus,
                                        line: UInt = #line) {
        XCTAssertEqual(controller.mobileAppButton.checkmarkStatus, thisDeviceCheckmark, line: line)
        XCTAssertEqual(controller.recoveryPhraseButton.checkmarkStatus, paperWalletCheckmark, line: line)
        XCTAssertEqual(controller.browserExtensionButton.checkmarkStatus, browserExtensionCheckmark, line: line)
    }

}

class MockNewSafeDelegate: NewSafeDelegate {

    var hasSelectedPaperWalletSetup = false
    var hasSelectedBrowserExtensionSetup = false
    var nextSelected = false

    func didSelectPaperWalletSetup() {
        hasSelectedPaperWalletSetup = true
    }

    func didSelectBrowserExtensionSetup() {
        hasSelectedBrowserExtensionSetup = true
    }

    func didSelectNext() {
        nextSelected = true
    }

}
