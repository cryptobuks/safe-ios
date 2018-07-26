//
//  Copyright © 2018 Gnosis Ltd. All rights reserved.
//

import XCTest
@testable import MultisigWalletImplementations
import MultisigWalletDomainModel
import Database

class DBTransactionRepositoryTests: XCTestCase {

    func test_all() throws {
        let db = SQLiteDatabase(name: String(reflecting: self),
                                fileManager: FileManager.default,
                                sqlite: CSQLite3(),
                                bundleId: String(reflecting: self))
        try? db.destroy()
        try db.create()
        defer {
            try? db.destroy()
        }

        let repo = DBTransactionRepository(db: db)
        repo.setUp()

        let walletID = WalletID()
        let accountID = AccountID(token: "ETH")
        let transaction = Transaction(id: repo.nextID(), type: .transfer, walletID: walletID, accountID: accountID)
            .change(amount: .ether(3))
            .change(fee: .ether(1))
            .change(feeEstimate: TransactionFeeEstimate(gas: 100, dataGas: 100, gasPrice: .ether(5)))
            .change(sender: Address.testAccount1)
            .change(recipient: Address.testAccount2)
            .change(data: Data(repeating: 1, count: 8))
            .change(nonce: "123")
            .change(operation: .delegateCall)
            .change(status: .signing)
            .add(signature: Signature(data: Data(repeating: 1, count: 7),
                                      address: Address.testAccount3))
            .add(signature: Signature(data: Data(repeating: 2, count: 7),
                                      address: Address.testAccount4))
            .set(hash: TransactionHash("hash"))
            .change(status: .pending)
            .change(status: .success)

        repo.save(transaction)
        let saved = repo.findByID(transaction.id)

        XCTAssertEqual(saved, transaction)
        XCTAssertEqual(saved?.type, transaction.type)
        XCTAssertEqual(saved?.walletID, transaction.walletID)
        XCTAssertEqual(saved?.amount, transaction.amount)
        XCTAssertEqual(saved?.fee, transaction.fee)
        XCTAssertEqual(saved?.feeEstimate, transaction.feeEstimate)
        XCTAssertEqual(saved?.sender, transaction.sender)
        XCTAssertEqual(saved?.recipient, transaction.recipient)
        XCTAssertEqual(saved?.data, transaction.data)
        XCTAssertEqual(saved?.operation, transaction.operation)
        XCTAssertEqual(saved?.nonce, transaction.nonce)
        XCTAssertEqual(saved?.signatures, transaction.signatures)
        XCTAssertEqual(saved?.transactionHash, transaction.transactionHash)
        XCTAssertEqual(saved?.status, transaction.status)

        repo.remove(transaction)
        XCTAssertNil(repo.findByID(transaction.id))
    }

}