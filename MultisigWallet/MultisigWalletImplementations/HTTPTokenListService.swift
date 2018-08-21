//
//  Copyright © 2018 Gnosis Ltd. All rights reserved.
//

import Foundation
import MultisigWalletDomainModel
import Common

public final class HTTPTokenListService: TokenListDomainService {

    private let httpClient: JSONHTTPClient

    private struct TokensRequest: JSONRequest {
        typealias ResponseType = [TokenListItem]

        var httpMethod: String { return "GET" }
        var urlPath: String { return "/" }
    }

    public init(url: URL, logger: Logger) {
        httpClient = JSONHTTPClient(url: url, logger: logger)
    }

    public func items() throws -> [TokenListItem] {
        return try httpClient.execute(request: TokensRequest())
    }

}
