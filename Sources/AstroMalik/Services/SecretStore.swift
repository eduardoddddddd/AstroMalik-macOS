import Foundation

/// Injected by the host for one request/session; never persisted by the engine.
protocol SecretStore: Sendable {
    func secret(service: String, account: String) -> String?
}
struct RequestSecretStore: SecretStore {
    private let value: String
    init(value: String) { self.value = value }
    func secret(service: String, account: String) -> String? {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : value
    }
}
#if !canImport(Security)
typealias OSStatus = Int32
#endif
