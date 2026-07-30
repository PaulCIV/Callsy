import Foundation
import Security
import SQLite3
import SwiftUI

struct LocalWorkspace: Identifiable, Equatable {
    let id: UUID
    var name: String
    let createdAt: Date
    var updatedAt: Date
}

struct LocalAccount: Identifiable, Equatable {
    let id: UUID
    let workspaceID: UUID
    var fullName: String
    let email: String
    let role: String
    let createdAt: Date
    var updatedAt: Date
}

struct LocalAccountSession: Equatable {
    var account: LocalAccount
    var workspace: LocalWorkspace
}

enum LocalAccountError: LocalizedError {
    case database(String)
    case credentialStore(String)
    case accountAlreadyExists
    case invalidName
    case invalidWorkspaceName
    case invalidEmail
    case weakPassword
    case passwordsDoNotMatch
    case invalidCredentials
    case currentPasswordIncorrect
    case unavailable

    var errorDescription: String? {
        switch self {
        case .database(let message):
            return "The local account database failed: \(message)"
        case .credentialStore(let message):
            return "The iPhone Keychain failed: \(message)"
        case .accountAlreadyExists:
            return "This iPhone already has a local workspace owner."
        case .invalidName:
            return "Enter your full name."
        case .invalidWorkspaceName:
            return "Enter a warehouse or business name."
        case .invalidEmail:
            return "Enter a valid email address."
        case .weakPassword:
            return "Use a password with at least 8 characters."
        case .passwordsDoNotMatch:
            return "The passwords do not match."
        case .invalidCredentials:
            return "The email or password is incorrect."
        case .currentPasswordIncorrect:
            return "The current password is incorrect."
        case .unavailable:
            return "Local accounts are unavailable on this device."
        }
    }
}

@MainActor
final class LocalAccountStore: ObservableObject {
    @Published private(set) var session: LocalAccountSession?
    @Published private(set) var hasLocalAccount = false
    @Published private(set) var startupError: String?

    private var database: LocalAccountDatabase?
    private let credentialVault = LocalCredentialVault()

    init() {
        do {
            let database = try LocalAccountDatabase()
            self.database = database
            try restoreSession(using: database)
        } catch {
            startupError = error.localizedDescription
        }
    }

    func createOwner(
        workspaceName: String,
        fullName: String,
        email: String,
        password: String,
        passwordConfirmation: String
    ) throws {
        guard let database else {
            throw LocalAccountError.unavailable
        }
        guard !hasLocalAccount else {
            throw LocalAccountError.accountAlreadyExists
        }

        let cleanWorkspaceName = try validatedWorkspaceName(workspaceName)
        let cleanName = try validatedName(fullName)
        let cleanEmail = try validatedEmail(email)
        try validateNewPassword(
            password,
            confirmation: passwordConfirmation
        )

        let workspaceID = UUID()
        let accountID = UUID()
        let now = Date()

        try credentialVault.save(
            password: password,
            accountID: accountID
        )

        do {
            try database.createOwner(
                workspace: LocalWorkspace(
                    id: workspaceID,
                    name: cleanWorkspaceName,
                    createdAt: now,
                    updatedAt: now
                ),
                account: LocalAccount(
                    id: accountID,
                    workspaceID: workspaceID,
                    fullName: cleanName,
                    email: cleanEmail,
                    role: "owner",
                    createdAt: now,
                    updatedAt: now
                )
            )
            try database.saveSession(accountID: accountID)
            try restoreSession(using: database)
        } catch {
            try? credentialVault.remove(accountID: accountID)
            throw error
        }
    }

    func signIn(email: String, password: String) throws {
        guard let database else {
            throw LocalAccountError.unavailable
        }

        let cleanEmail = try validatedEmail(email)
        guard let account = try database.account(email: cleanEmail),
              let storedPassword = try credentialVault.password(
                accountID: account.id
              ),
              storedPassword == password else {
            throw LocalAccountError.invalidCredentials
        }

        try database.saveSession(accountID: account.id)
        try restoreSession(using: database)
    }

    func signOut() throws {
        guard let database else {
            throw LocalAccountError.unavailable
        }
        try database.clearSession()
        session = nil
        hasLocalAccount = try database.hasAccounts()
    }

    func updateProfile(
        fullName: String,
        workspaceName: String
    ) throws {
        guard let database, let session else {
            throw LocalAccountError.unavailable
        }

        let cleanName = try validatedName(fullName)
        let cleanWorkspaceName = try validatedWorkspaceName(workspaceName)
        try database.updateProfile(
            accountID: session.account.id,
            fullName: cleanName,
            workspaceID: session.workspace.id,
            workspaceName: cleanWorkspaceName
        )
        try restoreSession(using: database)
    }

    func changePassword(
        currentPassword: String,
        newPassword: String,
        confirmation: String
    ) throws {
        guard let accountID = session?.account.id else {
            throw LocalAccountError.unavailable
        }
        guard try credentialVault.password(accountID: accountID)
            == currentPassword else {
            throw LocalAccountError.currentPasswordIncorrect
        }

        try validateNewPassword(
            newPassword,
            confirmation: confirmation
        )
        try credentialVault.save(
            password: newPassword,
            accountID: accountID
        )
    }

    func synchronizeWorkspaceName(_ name: String) {
        guard let database, let session else {
            return
        }
        let cleanName = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !cleanName.isEmpty, cleanName != session.workspace.name else {
            return
        }

        do {
            try database.updateWorkspaceName(
                workspaceID: session.workspace.id,
                name: cleanName
            )
            try restoreSession(using: database)
        } catch {
            startupError = error.localizedDescription
        }
    }

    private func restoreSession(
        using database: LocalAccountDatabase
    ) throws {
        hasLocalAccount = try database.hasAccounts()

        guard let accountID = try database.activeAccountID(),
              let account = try database.account(id: accountID),
              let workspace = try database.workspace(
                id: account.workspaceID
              ) else {
            session = nil
            return
        }

        session = LocalAccountSession(
            account: account,
            workspace: workspace
        )
    }

    private func validatedName(_ value: String) throws -> String {
        let cleaned = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard cleaned.count >= 2 else {
            throw LocalAccountError.invalidName
        }
        return cleaned
    }

    private func validatedWorkspaceName(_ value: String) throws -> String {
        let cleaned = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard cleaned.count >= 2 else {
            throw LocalAccountError.invalidWorkspaceName
        }
        return cleaned
    }

    private func validatedEmail(_ value: String) throws -> String {
        let cleaned = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).lowercased()
        let pattern = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
        guard cleaned.range(
            of: pattern,
            options: .regularExpression
        ) != nil else {
            throw LocalAccountError.invalidEmail
        }
        return cleaned
    }

    private func validateNewPassword(
        _ password: String,
        confirmation: String
    ) throws {
        guard password.count >= 8 else {
            throw LocalAccountError.weakPassword
        }
        guard password == confirmation else {
            throw LocalAccountError.passwordsDoNotMatch
        }
    }
}

private final class LocalCredentialVault {
    private let service = "com.paulclarkiv.WarehouseMapperScanner.local-account"

    func save(password: String, accountID: UUID) throws {
        let key = accountID.uuidString
        let passwordData = Data(password.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let existingStatus = SecItemCopyMatching(
            query as CFDictionary,
            nil
        )
        let status: OSStatus

        if existingStatus == errSecSuccess {
            status = SecItemUpdate(
                query as CFDictionary,
                [kSecValueData as String: passwordData] as CFDictionary
            )
        } else if existingStatus == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = passwordData
            newItem[kSecAttrAccessible as String] =
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(newItem as CFDictionary, nil)
        } else {
            status = existingStatus
        }

        guard status == errSecSuccess else {
            throw keychainError(status)
        }
    }

    func password(accountID: UUID) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountID.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(
            query as CFDictionary,
            &result
        )

        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess,
              let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            throw keychainError(status)
        }
        return password
    }

    func remove(accountID: UUID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountID.uuidString
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw keychainError(status)
        }
    }

    private func keychainError(_ status: OSStatus) -> LocalAccountError {
        let message = SecCopyErrorMessageString(status, nil) as String?
            ?? "OSStatus \(status)"
        return .credentialStore(message)
    }
}

private let sqliteTransient = unsafeBitCast(
    -1,
    to: sqlite3_destructor_type.self
)

private final class LocalAccountDatabase {
    private var database: OpaquePointer?

    init() throws {
        let url = try Self.databaseURL()
        let flags = SQLITE_OPEN_CREATE
            | SQLITE_OPEN_READWRITE
            | SQLITE_OPEN_FULLMUTEX
        let result = sqlite3_open_v2(
            url.path,
            &database,
            flags,
            nil
        )
        guard result == SQLITE_OK else {
            let message = currentErrorMessage
            sqlite3_close(database)
            database = nil
            throw LocalAccountError.database(message)
        }

        try execute("PRAGMA foreign_keys = ON;")
        try execute("PRAGMA journal_mode = WAL;")
        try migrate()
    }

    deinit {
        sqlite3_close(database)
    }

    func createOwner(
        workspace: LocalWorkspace,
        account: LocalAccount
    ) throws {
        try execute("BEGIN IMMEDIATE TRANSACTION;")
        do {
            let workspaceStatement = try prepare(
                """
                INSERT INTO workspaces (
                    id, name, created_at, updated_at
                ) VALUES (?, ?, ?, ?);
                """
            )
            defer { sqlite3_finalize(workspaceStatement) }
            bind(workspace.id.uuidString, at: 1, in: workspaceStatement)
            bind(workspace.name, at: 2, in: workspaceStatement)
            sqlite3_bind_double(
                workspaceStatement,
                3,
                workspace.createdAt.timeIntervalSince1970
            )
            sqlite3_bind_double(
                workspaceStatement,
                4,
                workspace.updatedAt.timeIntervalSince1970
            )
            try stepDone(workspaceStatement)

            let accountStatement = try prepare(
                """
                INSERT INTO accounts (
                    id, workspace_id, full_name, email, role,
                    created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?);
                """
            )
            defer { sqlite3_finalize(accountStatement) }
            bind(account.id.uuidString, at: 1, in: accountStatement)
            bind(
                account.workspaceID.uuidString,
                at: 2,
                in: accountStatement
            )
            bind(account.fullName, at: 3, in: accountStatement)
            bind(account.email, at: 4, in: accountStatement)
            bind(account.role, at: 5, in: accountStatement)
            sqlite3_bind_double(
                accountStatement,
                6,
                account.createdAt.timeIntervalSince1970
            )
            sqlite3_bind_double(
                accountStatement,
                7,
                account.updatedAt.timeIntervalSince1970
            )
            try stepDone(accountStatement)
            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    func hasAccounts() throws -> Bool {
        let statement = try prepare(
            "SELECT EXISTS(SELECT 1 FROM accounts LIMIT 1);"
        )
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw LocalAccountError.database(currentErrorMessage)
        }
        return sqlite3_column_int(statement, 0) == 1
    }

    func account(email: String) throws -> LocalAccount? {
        let statement = try prepare(
            """
            SELECT id, workspace_id, full_name, email, role,
                   created_at, updated_at
            FROM accounts
            WHERE email = ? COLLATE NOCASE
            LIMIT 1;
            """
        )
        defer { sqlite3_finalize(statement) }
        bind(email, at: 1, in: statement)
        return try readAccount(from: statement)
    }

    func account(id: UUID) throws -> LocalAccount? {
        let statement = try prepare(
            """
            SELECT id, workspace_id, full_name, email, role,
                   created_at, updated_at
            FROM accounts
            WHERE id = ?
            LIMIT 1;
            """
        )
        defer { sqlite3_finalize(statement) }
        bind(id.uuidString, at: 1, in: statement)
        return try readAccount(from: statement)
    }

    func workspace(id: UUID) throws -> LocalWorkspace? {
        let statement = try prepare(
            """
            SELECT id, name, created_at, updated_at
            FROM workspaces
            WHERE id = ?
            LIMIT 1;
            """
        )
        defer { sqlite3_finalize(statement) }
        bind(id.uuidString, at: 1, in: statement)

        let result = sqlite3_step(statement)
        if result == SQLITE_DONE {
            return nil
        }
        guard result == SQLITE_ROW,
              let id = UUID(uuidString: text(statement, column: 0)) else {
            throw LocalAccountError.database(currentErrorMessage)
        }
        return LocalWorkspace(
            id: id,
            name: text(statement, column: 1),
            createdAt: Date(
                timeIntervalSince1970: sqlite3_column_double(
                    statement,
                    2
                )
            ),
            updatedAt: Date(
                timeIntervalSince1970: sqlite3_column_double(
                    statement,
                    3
                )
            )
        )
    }

    func saveSession(accountID: UUID) throws {
        let statement = try prepare(
            """
            INSERT INTO local_session (
                singleton, account_id, signed_in_at
            ) VALUES (1, ?, ?)
            ON CONFLICT(singleton) DO UPDATE SET
                account_id = excluded.account_id,
                signed_in_at = excluded.signed_in_at;
            """
        )
        defer { sqlite3_finalize(statement) }
        bind(accountID.uuidString, at: 1, in: statement)
        sqlite3_bind_double(
            statement,
            2,
            Date().timeIntervalSince1970
        )
        try stepDone(statement)
    }

    func activeAccountID() throws -> UUID? {
        let statement = try prepare(
            """
            SELECT account_id
            FROM local_session
            WHERE singleton = 1
            LIMIT 1;
            """
        )
        defer { sqlite3_finalize(statement) }
        let result = sqlite3_step(statement)
        if result == SQLITE_DONE {
            return nil
        }
        guard result == SQLITE_ROW else {
            throw LocalAccountError.database(currentErrorMessage)
        }
        return UUID(uuidString: text(statement, column: 0))
    }

    func clearSession() throws {
        try execute("DELETE FROM local_session WHERE singleton = 1;")
    }

    func updateProfile(
        accountID: UUID,
        fullName: String,
        workspaceID: UUID,
        workspaceName: String
    ) throws {
        try execute("BEGIN IMMEDIATE TRANSACTION;")
        do {
            let accountStatement = try prepare(
                """
                UPDATE accounts
                SET full_name = ?, updated_at = ?
                WHERE id = ?;
                """
            )
            defer { sqlite3_finalize(accountStatement) }
            bind(fullName, at: 1, in: accountStatement)
            sqlite3_bind_double(
                accountStatement,
                2,
                Date().timeIntervalSince1970
            )
            bind(accountID.uuidString, at: 3, in: accountStatement)
            try stepDone(accountStatement)

            try updateWorkspaceName(
                workspaceID: workspaceID,
                name: workspaceName
            )
            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    func updateWorkspaceName(
        workspaceID: UUID,
        name: String
    ) throws {
        let statement = try prepare(
            """
            UPDATE workspaces
            SET name = ?, updated_at = ?
            WHERE id = ?;
            """
        )
        defer { sqlite3_finalize(statement) }
        bind(name, at: 1, in: statement)
        sqlite3_bind_double(
            statement,
            2,
            Date().timeIntervalSince1970
        )
        bind(workspaceID.uuidString, at: 3, in: statement)
        try stepDone(statement)
    }

    private func migrate() throws {
        try execute(
            """
            CREATE TABLE IF NOT EXISTS workspaces (
                id TEXT PRIMARY KEY NOT NULL,
                name TEXT NOT NULL,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            );
            """
        )
        try execute(
            """
            CREATE TABLE IF NOT EXISTS accounts (
                id TEXT PRIMARY KEY NOT NULL,
                workspace_id TEXT NOT NULL,
                full_name TEXT NOT NULL,
                email TEXT NOT NULL COLLATE NOCASE UNIQUE,
                role TEXT NOT NULL DEFAULT 'owner',
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL,
                FOREIGN KEY(workspace_id)
                    REFERENCES workspaces(id)
                    ON DELETE CASCADE
            );
            """
        )
        try execute(
            """
            CREATE TABLE IF NOT EXISTS local_session (
                singleton INTEGER PRIMARY KEY CHECK(singleton = 1),
                account_id TEXT NOT NULL,
                signed_in_at REAL NOT NULL,
                FOREIGN KEY(account_id)
                    REFERENCES accounts(id)
                    ON DELETE CASCADE
            );
            """
        )
        try execute(
            """
            CREATE INDEX IF NOT EXISTS accounts_workspace_index
            ON accounts(workspace_id);
            """
        )
    }

    private func readAccount(
        from statement: OpaquePointer?
    ) throws -> LocalAccount? {
        let result = sqlite3_step(statement)
        if result == SQLITE_DONE {
            return nil
        }
        guard result == SQLITE_ROW,
              let accountID = UUID(
                uuidString: text(statement, column: 0)
              ),
              let workspaceID = UUID(
                uuidString: text(statement, column: 1)
              ) else {
            throw LocalAccountError.database(currentErrorMessage)
        }

        return LocalAccount(
            id: accountID,
            workspaceID: workspaceID,
            fullName: text(statement, column: 2),
            email: text(statement, column: 3),
            role: text(statement, column: 4),
            createdAt: Date(
                timeIntervalSince1970: sqlite3_column_double(
                    statement,
                    5
                )
            ),
            updatedAt: Date(
                timeIntervalSince1970: sqlite3_column_double(
                    statement,
                    6
                )
            )
        )
    }

    private func execute(_ sql: String) throws {
        var errorPointer: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(
            database,
            sql,
            nil,
            nil,
            &errorPointer
        )
        guard result == SQLITE_OK else {
            let message = errorPointer.map {
                String(cString: $0)
            } ?? currentErrorMessage
            sqlite3_free(errorPointer)
            throw LocalAccountError.database(message)
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        let result = sqlite3_prepare_v2(
            database,
            sql,
            -1,
            &statement,
            nil
        )
        guard result == SQLITE_OK else {
            throw LocalAccountError.database(currentErrorMessage)
        }
        return statement
    }

    private func bind(
        _ value: String,
        at index: Int32,
        in statement: OpaquePointer?
    ) {
        sqlite3_bind_text(
            statement,
            index,
            value,
            -1,
            sqliteTransient
        )
    }

    private func stepDone(_ statement: OpaquePointer?) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw LocalAccountError.database(currentErrorMessage)
        }
    }

    private func text(
        _ statement: OpaquePointer?,
        column: Int32
    ) -> String {
        guard let value = sqlite3_column_text(statement, column) else {
            return ""
        }
        return String(cString: value)
    }

    private var currentErrorMessage: String {
        guard let database,
              let message = sqlite3_errmsg(database) else {
            return "Unknown SQLite error"
        }
        return String(cString: message)
    }

    private static func databaseURL() throws -> URL {
        guard let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            throw CocoaError(.fileNoSuchFile)
        }

        let directory = documents.appendingPathComponent(
            "WarehouseMapper",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory.appendingPathComponent(
            "LocalAccounts.sqlite3"
        )
    }
}
