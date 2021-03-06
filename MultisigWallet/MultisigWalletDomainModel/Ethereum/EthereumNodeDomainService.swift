//
//  Copyright © 2018 Gnosis Ltd. All rights reserved.
//

import Foundation
import BigInt

/// Represents RPC API of an Ethereum node.
public protocol EthereumNodeDomainService {

    /// Returns balance of an account in Wei
    ///
    /// - Parameter account: address of an account
    /// - Returns: balance in Wei
    /// - Throws: may throw NetworkServiceError
    func eth_getBalance(account: Address) throws -> BigInt

    /// Returns transaction receipt for the transaction hash, if receipt available.
    ///
    /// - Parameter transaction: transaction hash to query
    /// - Returns: transaction receipt, or nil if it doesn't exist yet
    /// - Throws: NetworkServiceError
    func eth_getTransactionReceipt(transaction: TransactionHash) throws -> TransactionReceipt?

    /// Executes call to a contract using the `data` as serialized method call.
    ///
    /// - Parameters:
    ///   - to: address of a contract to call
    ///   - data: serialized method call - signature and parameter values
    /// - Returns: contract return value
    /// - Throws: NetworkServiceError
    func eth_call(to: Address, data: Data) throws -> Data

}

/// Thrown by any network-based service
///
/// - networkError: there was a network-layer related error. Usually, when network is unavailable.
/// - serverError: Server returned error.
/// - clientError: Client error. Please check your request parameters.
public enum NetworkServiceError: Swift.Error {
    case networkError
    case serverError
    case clientError
}
