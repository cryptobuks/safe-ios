//
//  Copyright © 2018 Gnosis Ltd. All rights reserved.
//

import Foundation
import UIKit
import MultisigWalletDomainModel

public class SynchronisationService: SynchronisationDomainService {

    private let retryInterval: TimeInterval
    private let merger: TokenListMerger
    private let accountService: AccountUpdateDomainService
    private let tokenSyncInterval: TimeInterval
    private let tokenSyncMaxRetries: Int
    private var tokenSyncRepeater: Repeater!

    public init(retryInterval: TimeInterval,
                tokenSyncInterval: TimeInterval = 10,
                tokenSyncMaxRetries: Int = 3,
                merger: TokenListMerger = TokenListMerger(),
                accountService: AccountUpdateDomainService = DomainRegistry.accountUpdateService) {
        self.retryInterval = retryInterval
        self.merger = merger
        self.accountService = accountService
        self.tokenSyncInterval = tokenSyncInterval
        self.tokenSyncMaxRetries = tokenSyncMaxRetries
        subscribeForLockingEvents()
    }

    private func subscribeForLockingEvents() {
        let lockNotification = UIApplication.protectedDataWillBecomeUnavailableNotification
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didLock),
                                               name: lockNotification,
                                               object: nil)
    }

    @objc func didLock() {
        stopSyncTransactions()
    }

    /// Synchronise stored data with info from services.
    /// Should be called from a background thread.
    public func sync() {
        precondition(!Thread.isMainThread)
        syncTokenList()
        syncAccounts()
    }

    private func syncTokenList() {
        try! RetryWithIncreasingDelay(maxAttempts: Int.max, startDelay: retryInterval) { [weak self] _ in
            let tokenList = try DomainRegistry.tokenListService.items()
            self?.merger.mergeStoredTokenItems(with: tokenList)
        }.start()
    }

    private func syncAccounts() {
        try! RetryWithIncreasingDelay(maxAttempts: Int.max, startDelay: retryInterval) { [weak self] _ in
            try self?.accountService.updateAccountsBalances()
        }.start()
    }

    /// Starts regular transaction status updates. To stop, use `stopSyncTransactions()`
    public func syncTransactions() {
        guard tokenSyncRepeater == nil || tokenSyncRepeater.stopped else { return }
        tokenSyncRepeater = Repeater(delay: tokenSyncInterval) { [unowned self] _ in
            try? RetryWithIncreasingDelay(maxAttempts: self.tokenSyncMaxRetries, startDelay: self.retryInterval) { _ in
                try DomainRegistry.transactionService.updatePendingTransactions()
            }.start()
            self.syncAccounts()
        }
        try? tokenSyncRepeater.start()
    }

    /// Will stop the transaction synchronization
    public func stopSyncTransactions() {
        tokenSyncRepeater?.stop()
    }

}
