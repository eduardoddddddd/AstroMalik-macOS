import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
extension URLSession {
    // swift-corelibs has data(for:delegate:); default arguments are not protocol witnesses.
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await data(for: request, delegate: nil)
    }
}
#endif
