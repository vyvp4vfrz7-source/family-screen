#if APPLE_SERVICES
import Foundation
import CloudKit
import UIKit

/// Syncs one family's photos and messages through CloudKit.
///
/// The first home creates a private zone called "Family" and shares it with
/// the other home using an iCloud share link. The other home opens the link,
/// and from then on both iPads read and write the same zone. Each family's
/// data stays in their own iCloud; the app has no server and no shared keys.
@MainActor
final class CloudSync {
    struct Changes {
        var photos: [FamilyPhoto] = []
        var messages: [FamilyMessage] = []
        var deleted: [String] = []
        /// Screen settings as JSON text (decoded by the app; the Share Extension never reads them).
        var screens: [String] = []
        var assetFiles: [String: URL] = [:]
    }

    let container: CKContainer
    /// Kept in the app group, so the Share Extension writes to the same zone.
    private let defaults = AppGroup.defaults

    init() {
        let id = Bundle.main.object(forInfoDictionaryKey: "FamilyCloudContainer") as? String ?? ""
        container = CKContainer(identifier: id)
        // Older builds kept these in the app's own defaults.
        if defaults !== UserDefaults.standard, !defaults.bool(forKey: "cloud.migrated") {
            for key in ["cloud.isGuest", "cloud.zoneName", "cloud.zoneOwner", "cloud.zoneReady", "cloud.token"] {
                if let value = UserDefaults.standard.object(forKey: key) { defaults.set(value, forKey: key) }
            }
            defaults.set(true, forKey: "cloud.migrated")
        }
    }

    // MARK: - Which zone this iPad uses

    /// true when this iPad joined another home's family (zone lives in the shared database).
    private(set) var isGuest: Bool {
        get { defaults.bool(forKey: "cloud.isGuest") }
        set { defaults.set(newValue, forKey: "cloud.isGuest") }
    }

    private var zoneID: CKRecordZone.ID {
        get {
            let name = defaults.string(forKey: "cloud.zoneName") ?? "Family"
            let owner = defaults.string(forKey: "cloud.zoneOwner") ?? CKCurrentUserDefaultName
            return CKRecordZone.ID(zoneName: name, ownerName: owner)
        }
        set {
            defaults.set(newValue.zoneName, forKey: "cloud.zoneName")
            defaults.set(newValue.ownerName, forKey: "cloud.zoneOwner")
        }
    }

    private var database: CKDatabase {
        isGuest ? container.sharedCloudDatabase : container.privateCloudDatabase
    }

    private var zoneReady: Bool {
        get { defaults.bool(forKey: "cloud.zoneReady") }
        set { defaults.set(newValue, forKey: "cloud.zoneReady") }
    }

    private var changeToken: CKServerChangeToken? {
        get {
            guard let data = defaults.data(forKey: "cloud.token") else { return nil }
            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
        }
        set {
            if let token = newValue,
               let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) {
                defaults.set(data, forKey: "cloud.token")
            } else {
                defaults.removeObject(forKey: "cloud.token")
            }
        }
    }

    private func ensureZone() async throws {
        guard !isGuest, !zoneReady else { return }
        _ = try await container.privateCloudDatabase.save(CKRecordZone(zoneID: zoneID))
        zoneReady = true
    }

    func accountStatusText() async -> String {
        guard let status = try? await container.accountStatus() else { return "iCloud ?" }
        switch status {
        case .available: return isGuest ? "iCloud ✓ (joined)" : "iCloud ✓"
        case .noAccount: return "Sign in to iCloud in the iPad's Settings"
        case .restricted: return "iCloud is restricted on this iPad"
        default: return "iCloud is not available right now"
        }
    }

    // MARK: - Writing

    func save(photo: FamilyPhoto, imageURL: URL) async throws {
        try await ensureZone()
        let record = CKRecord(recordType: "Photo", recordID: CKRecord.ID(recordName: photo.id, zoneID: zoneID))
        record["note"] = photo.note
        record["author"] = photo.author
        record["date"] = photo.date
        record["pinned"] = photo.pinned ? 1 : 0
        record["image"] = CKAsset(fileURL: imageURL)
        try await saveRecords([record])
    }

    /// Only the pinned field is sent.
    func savePinned(photoID: String, pinned: Bool) async throws {
        let record = CKRecord(recordType: "Photo", recordID: CKRecord.ID(recordName: photoID, zoneID: zoneID))
        record["pinned"] = pinned ? 1 : 0
        try await saveRecords([record])
    }

    func save(message: FamilyMessage) async throws {
        try await ensureZone()
        let record = CKRecord(recordType: "Message", recordID: CKRecord.ID(recordName: message.id, zoneID: zoneID))
        record["text"] = message.text
        record["author"] = message.author
        record["date"] = message.date
        record["hearts"] = message.hearts
        try await saveRecords([record])
    }

    /// A screen's settings, stored as one JSON text field.
    func saveScreen(recordName: String, json: String) async throws {
        try await ensureZone()
        let record = CKRecord(recordType: "Screen", recordID: CKRecord.ID(recordName: recordName, zoneID: zoneID))
        record["config"] = json
        try await saveRecords([record])
    }

    /// Only the hearts field is sent, so it never clashes with other edits.
    func saveHearts(messageID: String, hearts: [String]) async throws {
        let record = CKRecord(recordType: "Message", recordID: CKRecord.ID(recordName: messageID, zoneID: zoneID))
        record["hearts"] = hearts
        try await saveRecords([record])
    }

    func delete(_ id: String) async throws {
        _ = try await database.modifyRecords(saving: [], deleting: [CKRecord.ID(recordName: id, zoneID: zoneID)])
    }

    /// Removes expired photos. Another iPad may already have removed some, so errors are ignored.
    func deleteQuietly(_ ids: [String]) async {
        guard !ids.isEmpty else { return }
        let recordIDs = ids.map { CKRecord.ID(recordName: $0, zoneID: zoneID) }
        _ = try? await database.modifyRecords(saving: [], deleting: recordIDs, savePolicy: .changedKeys, atomically: false)
    }

    private func saveRecords(_ records: [CKRecord]) async throws {
        let result = try await database.modifyRecords(saving: records, deleting: [], savePolicy: .changedKeys)
        for (_, r) in result.saveResults { _ = try r.get() }
    }

    // MARK: - Reading

    func fetchChanges() async throws -> Changes {
        try await ensureZone()
        var changes = Changes()
        var more = true
        while more {
            let result: (modificationResultsByID: [CKRecord.ID: Result<CKDatabase.RecordZoneChange.Modification, Error>],
                         deletions: [CKDatabase.RecordZoneChange.Deletion],
                         changeToken: CKServerChangeToken,
                         moreComing: Bool)
            do {
                result = try await database.recordZoneChanges(inZoneWith: zoneID, since: changeToken)
            } catch let error as CKError where error.code == .changeTokenExpired {
                changeToken = nil
                continue
            }
            for (_, item) in result.modificationResultsByID {
                guard let record = try? item.get().record else { continue }
                read(record, into: &changes)
            }
            changes.deleted += result.deletions.map { $0.recordID.recordName }
            changeToken = result.changeToken
            more = result.moreComing
        }
        defaults.set(true, forKey: AppGroup.cloudReadyKey)   // the Share Extension may now upload
        return changes
    }

    private func read(_ record: CKRecord, into changes: inout Changes) {
        let id = record.recordID.recordName
        let author = record["author"] as? String ?? ""
        let date = record["date"] as? Date ?? record.creationDate ?? Date()
        switch record.recordType {
        case "Photo":
            changes.photos.append(FamilyPhoto(id: id, note: record["note"] as? String ?? "", author: author, date: date,
                                              pinned: (record["pinned"] as? Int ?? 0) == 1))
            if let asset = record["image"] as? CKAsset, let url = asset.fileURL { changes.assetFiles[id] = url }
        case "Message":
            changes.messages.append(FamilyMessage(id: id, text: record["text"] as? String ?? "", author: author,
                                                  date: date, hearts: record["hearts"] as? [String] ?? []))
        case "Screen":
            if let text = record["config"] as? String { changes.screens.append(text) }
        default:
            break
        }
    }

    // MARK: - Sharing between homes

    struct Member: Identifiable {
        var id: String
        var name: String
        var isOwner: Bool
        var participant: CKShare.Participant
    }

    var isOwner: Bool { !isGuest }

    private var shareID: CKRecord.ID { CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID) }

    private func existingShare() async -> CKShare? {
        try? await database.record(for: shareID) as? CKShare
    }

    /// The family's invite link. Anyone who taps it joins this family, so it is
    /// only ever sent by the family itself (Messages, WhatsApp, email…). The
    /// link is long and random and can be switched off once everyone has joined.
    func inviteLink() async throws -> URL {
        try await ensureZone()
        if let share = await existingShare(), let url = share.url { return url }
        let share = CKShare(recordZoneID: zoneID)
        share[CKShare.SystemFieldKey.title] = "Family Screen" as CKRecordValue
        share.publicPermission = .readWrite
        let result = try await database.modifyRecords(saving: [share], deleting: [])
        guard let saved = try result.saveResults[share.recordID]?.get() as? CKShare, let url = saved.url else {
            throw CKError(.internalError)
        }
        return url
    }

    /// Turns the invite link off (or back on). Homes that already joined stay in.
    func setLinkActive(_ on: Bool) async throws {
        guard isOwner, let share = await existingShare() else { return }
        share.publicPermission = on ? .readWrite : .none
        _ = try await database.modifyRecords(saving: [share], deleting: [], savePolicy: .changedKeys)
    }

    func linkIsActive() async -> Bool {
        (await existingShare())?.publicPermission == .readWrite
    }

    func members() async -> [Member] {
        guard let share = await existingShare() else { return [] }
        return share.participants.compactMap { p in
            guard p.acceptanceStatus == .accepted || p.role == .owner else { return nil }
            let comps = p.userIdentity.nameComponents
            let name = comps.map { PersonNameComponentsFormatter().string(from: $0) } ?? ""
            return Member(id: p.userIdentity.userRecordID?.recordName ?? UUID().uuidString,
                          name: name.isEmpty ? (p.userIdentity.lookupInfo?.emailAddress ?? "iCloud user") : name,
                          isOwner: p.role == .owner, participant: p)
        }
    }

    /// Owner only: removes a home from the family. Their iPad loses access at once.
    func remove(_ member: Member) async throws {
        guard isOwner, let share = await existingShare() else { return }
        share.removeParticipant(member.participant)
        _ = try await database.modifyRecords(saving: [share], deleting: [], savePolicy: .changedKeys)
    }

    /// Guest: leave the family. Owner: delete the family and all its photos
    /// and messages from iCloud for everyone.
    func leaveOrDelete() async throws {
        if isGuest {
            _ = try? await database.modifyRecords(saving: [], deleting: [shareID])
        } else {
            _ = try await container.privateCloudDatabase.deleteRecordZone(withID: zoneID)
        }
        isGuest = false
        zoneReady = false
        changeToken = nil
        defaults.removeObject(forKey: AppGroup.cloudReadyKey)
        defaults.removeObject(forKey: "cloud.zoneName")
        defaults.removeObject(forKey: "cloud.zoneOwner")
    }

    /// Called when the other home taps the invite link.
    func accept(_ metadata: CKShare.Metadata) async throws {
        _ = try await container.accept(metadata)
        isGuest = true
        zoneID = metadata.share.recordID.zoneID
        changeToken = nil
    }
}
#endif
