//
//  Copyright © 2018 Gnosis Ltd. All rights reserved.
//

import UIKit
import MultisigWalletApplication

final class NewSafeFlowCoordinator: FlowCoordinator {

    var paperWalletFlowCoordinator = PaperWalletFlowCoordinator()
    var pairController: PairWithBrowserExtensionViewController?

    var isSafeCreationInProgress: Bool {
        return ApplicationServiceRegistry.walletService.isSafeCreationInProgress
    }

    override func setUp() {
        super.setUp()
        if ApplicationServiceRegistry.walletService.hasReadyToUseWallet {
            exitFlow()
            return
        }
        push(GuidelinesViewController.createNewSafeGuidelines(delegate: self))
        saveCheckpoint()
        if ApplicationServiceRegistry.walletService.isSafeCreationInProgress {
            push(NewSafeViewController.create(delegate: self))
            push(SafeCreationViewController.create(delegate: self))
        }
    }

}

extension NewSafeFlowCoordinator {

    func enterAndComeBack(from coordinator: FlowCoordinator) {
        saveCheckpoint()
        enter(flow: coordinator) {
            self.popToLastCheckpoint()
        }
    }

}

extension NewSafeFlowCoordinator: GuidelinesViewControllerDelegate {

    func didPressNext() {
        push(NewSafeViewController.create(delegate: self))
    }

}

extension NewSafeFlowCoordinator: NewSafeDelegate {

    func didSelectPaperWalletSetup() {
        enterAndComeBack(from: paperWalletFlowCoordinator)
    }

    func didSelectBrowserExtensionSetup() {
        pairController = newPairController()
        push(pairController!)
    }

    func newPairController() -> PairWithBrowserExtensionViewController {
        let controller = PairWithBrowserExtensionViewController.create(delegate: self)
        controller.screenTitle = LocalizedString("new_safe.browser_extension.title",
                                                 comment: "Title for add browser extension screen")
        controller.screenHeader = LocalizedString("new_safe.browser_extension.header",
                                                  comment: "Header for add browser extension screen")
        controller.descriptionText = LocalizedString("new_safe.browser_extension.description",
                                                     comment: "Description for add browser extension screen")
        return controller
    }

    func didSelectNext() {
        push(SafeCreationViewController.create(delegate: self))
    }

}

extension NewSafeFlowCoordinator: PairWithBrowserExtensionViewControllerDelegate {

    func pairWithBrowserExtensionViewController(_ controller: PairWithBrowserExtensionViewController,
                                                didPairWith address: String,
                                                code: String) {
        do {
            try ApplicationServiceRegistry.walletService
                .addBrowserExtensionOwner(address: address, browserExtensionCode: code)
            self.pop()
        } catch let e {
            controller.handleError(e)
        }
    }

    func pairWithBrowserExtensionViewControllerDidSkipPairing() {
        ApplicationServiceRegistry.walletService.removeBrowserExtensionOwner()
        self.pop()
    }

}

extension NewSafeFlowCoordinator: SafeCreationViewControllerDelegate {

    func deploymentDidFail(_ error: String) {
        let controller = SafeCreationFailedAlertController.create(localizedErrorDescription: error) { [unowned self] in
            self.dismissModal()
            self.popToLastCheckpoint()
        }
        presentModally(controller)
    }

    func deploymentDidSuccess() {
        exitFlow()
    }

    func deploymentDidCancel() {
        let controller = AbortSafeCreationAlertController.create(abort: { [unowned self] in
            self.dismissModal()
            self.popToLastCheckpoint()
        }, continue: { [unowned self] in
            self.dismissModal()
        })
        presentModally(controller)
    }

}
