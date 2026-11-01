import Foundation

#if canImport(Security)
    import Security
#endif

/// Persists an ``OAuthCredential`` between launches.
public protocol CredentialStore: Sendable {
    func load() async throws -> OAuthCredential?
    func save(_ credential: OAuthCredential) async throws
    func delete() async throws
}

/// Keeps the credential in memory only. Useful for tests and previews.
public actor InMemoryCredentialStore: CredentialStore {
    private var credential: OAuthCredential?

    public init(_ credential: OAuthCredential? = nil) {
        self.credential = credential
    }

    public func load() -> OAuthCredential? { credential }
    public func save(_ credential: OAuthCredential) { self.credential = credential }
    public func delete() { credential = nil }
}

#if canImport(Security)
    /// Stores the credential in the Keychain as a generic password item.
    public struct KeychainCredentialStore: CredentialStore {
        public var service: String
        public var account: String
        /// Share the item between apps in the same access group.
        public var accessGroup: String?
        /// Sync through iCloud Keychain.
        public var synchronizable: Bool

        public init(service: String, account: String = "github", accessGroup: String? = nil, synchronizable: Bool = false) {
            self.service = service
            self.account = account
            self.accessGroup = accessGroup
            self.synchronizable = synchronizable
        }

        public func load() throws -> OAuthCredential? {
            var query = baseQuery()
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            if status == errSecItemNotFound { return nil }
            guard status == errSecSuccess, let data = result as? Data else { throw KeychainError(status: status) }
            return try GitHubJSON.decoder().decode(OAuthCredential.self, from: data)
        }

        public func save(_ credential: OAuthCredential) throws {
            let data = try GitHubJSON.encoder().encode(credential)
            let attributes: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            ]
            let status = SecItemUpdate(baseQuery() as CFDictionary, attributes as CFDictionary)
            if status == errSecItemNotFound {
                let addStatus = SecItemAdd(baseQuery().merging(attributes) { $1 } as CFDictionary, nil)
                guard addStatus == errSecSuccess else { throw KeychainError(status: addStatus) }
            } else if status != errSecSuccess {
                throw KeychainError(status: status)
            }
        }

        public func delete() throws {
            let status = SecItemDelete(baseQuery() as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
        }

        private func baseQuery() -> [String: Any] {
            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecUseDataProtectionKeychain as String: true,
            ]
            if let accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }
            if synchronizable { query[kSecAttrSynchronizable as String] = true }
            return query
        }
    }

    /// A Keychain call failed.
    public struct KeychainError: Error, Sendable, Hashable, CustomStringConvertible {
        public let status: OSStatus
        public var description: String {
            (SecCopyErrorMessageString(status, nil) as String?) ?? "Keychain error \(status)"
        }
    }
#endif
