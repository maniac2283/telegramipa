import Foundation
import SwiftSignalKit
import TelegramCore
import Postbox

public struct ManualStarGiftEntry: Equatable, Codable {
    public var slug: String
    public var title: String
    public var number: Int32
    public var pinnedToTop: Bool
    public var savedToProfile: Bool
    public var wear: Bool
    public var date: Int32
    public var uniqueGift: StarGift.UniqueGift?
    
    public init(slug: String, title: String, number: Int32, pinnedToTop: Bool, savedToProfile: Bool, wear: Bool, date: Int32, uniqueGift: StarGift.UniqueGift?) {
        self.slug = slug
        self.title = title
        self.number = number
        self.pinnedToTop = pinnedToTop
        self.savedToProfile = savedToProfile
        self.wear = wear
        self.date = date
        self.uniqueGift = uniqueGift
    }
    
    public init(from overlay: ManualOverlayGift) {
        self.slug = overlay.slug
        self.title = overlay.uniqueGift.title
        self.number = overlay.uniqueGift.number
        self.pinnedToTop = overlay.pinnedToTop
        self.savedToProfile = overlay.savedToProfile
        self.wear = overlay.wear
        self.date = overlay.date
        self.uniqueGift = overlay.uniqueGift
    }
    
    public func overlayGift() -> ManualOverlayGift? {
        guard let uniqueGift = self.uniqueGift, uniqueGift.hasRenderableArtwork else {
            return nil
        }
        return ManualOverlayGift(uniqueGift: uniqueGift, pinnedToTop: self.pinnedToTop, savedToProfile: self.savedToProfile, wear: self.wear, date: self.date)
    }
    
    public var needsGiftResolve: Bool {
        guard let uniqueGift = self.uniqueGift else {
            return true
        }
        return !uniqueGift.hasRenderableArtwork
    }
    
    public var displayTitle: String {
        let title = self.uniqueGift?.title ?? self.title
        let number = self.uniqueGift?.number ?? self.number
        return "\(title) #\(number)"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.slug = try container.decode(String.self, forKey: "slug")
        self.title = try container.decodeIfPresent(String.self, forKey: "title") ?? ""
        self.number = try container.decodeIfPresent(Int32.self, forKey: "number") ?? 0
        self.pinnedToTop = try container.decodeIfPresent(Bool.self, forKey: "pinnedToTop") ?? false
        self.savedToProfile = try container.decodeIfPresent(Bool.self, forKey: "savedToProfile") ?? true
        self.wear = try container.decodeIfPresent(Bool.self, forKey: "wear") ?? false
        self.date = try container.decodeIfPresent(Int32.self, forKey: "date") ?? 0
        if let data = try container.decodeIfPresent(Data.self, forKey: "uniqueGiftData") {
            if let gift = try? JSONDecoder().decode(StarGift.UniqueGift.self, from: data), gift.hasRenderableArtwork {
                self.uniqueGift = gift
            } else {
                self.uniqueGift = StarGift.UniqueGift.fromPostboxData(data)
            }
        } else if let gift = try container.decodeIfPresent(StarGift.UniqueGift.self, forKey: "uniqueGift"), gift.hasRenderableArtwork {
            self.uniqueGift = gift
        } else {
            self.uniqueGift = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode(self.slug, forKey: "slug")
        try container.encode(self.title, forKey: "title")
        try container.encode(self.number, forKey: "number")
        try container.encode(self.pinnedToTop, forKey: "pinnedToTop")
        try container.encode(self.savedToProfile, forKey: "savedToProfile")
        try container.encode(self.wear, forKey: "wear")
        try container.encode(self.date, forKey: "date")
        if let uniqueGift, uniqueGift.hasRenderableArtwork {
            try container.encode(uniqueGift.serializedPostboxData(), forKey: "uniqueGiftData")
        }
    }
}

public struct ManualProfileSettings: Equatable, Codable {
    public var firstName: String
    public var lastName: String
    public var anonymousNumber: String
    public var usernameDraft: String
    public var usernames: [String]
    public var holdVerification: Bool
    public var holdVerificationInfo: PeerVerification?
    public var majorVerification: Bool
    public var photoFileId: Int64?
    public var photoWidth: Int32?
    public var photoHeight: Int32?
    public var giftNameDraft: String
    public var giftNumberDraft: String
    public var gifts: [ManualStarGiftEntry]
    
    public static var defaultSettings: ManualProfileSettings {
        return ManualProfileSettings(
            firstName: "",
            lastName: "",
            anonymousNumber: "",
            usernameDraft: "",
            usernames: [],
            holdVerification: false,
            holdVerificationInfo: nil,
            majorVerification: false,
            photoFileId: nil,
            photoWidth: nil,
            photoHeight: nil,
            giftNameDraft: "",
            giftNumberDraft: "",
            gifts: []
        )
    }
    
    public init(
        firstName: String,
        lastName: String,
        anonymousNumber: String,
        usernameDraft: String,
        usernames: [String],
        holdVerification: Bool,
        holdVerificationInfo: PeerVerification? = nil,
        majorVerification: Bool,
        photoFileId: Int64?,
        photoWidth: Int32?,
        photoHeight: Int32?,
        giftNameDraft: String,
        giftNumberDraft: String,
        gifts: [ManualStarGiftEntry]
    ) {
        self.firstName = firstName
        self.lastName = lastName
        self.anonymousNumber = anonymousNumber
        self.usernameDraft = usernameDraft
        self.usernames = usernames
        self.holdVerification = holdVerification
        self.holdVerificationInfo = holdVerificationInfo
        self.majorVerification = majorVerification
        self.photoFileId = photoFileId
        self.photoWidth = photoWidth
        self.photoHeight = photoHeight
        self.giftNameDraft = giftNameDraft
        self.giftNumberDraft = giftNumberDraft
        self.gifts = gifts
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.firstName = try container.decodeIfPresent(String.self, forKey: "firstName") ?? ""
        self.lastName = try container.decodeIfPresent(String.self, forKey: "lastName") ?? ""
        self.anonymousNumber = try container.decodeIfPresent(String.self, forKey: "anonymousNumber") ?? ""
        self.usernameDraft = try container.decodeIfPresent(String.self, forKey: "usernameDraft") ?? ""
        self.usernames = try container.decodeIfPresent([String].self, forKey: "usernames") ?? []
        self.holdVerification = try container.decodeIfPresent(Bool.self, forKey: "holdVerification") ?? false
        self.holdVerificationInfo = try container.decodeIfPresent(PeerVerification.self, forKey: "holdVerificationInfo")
        if self.holdVerificationInfo?.isPlaceholderOrganizationVerification == true {
            self.holdVerificationInfo = nil
        }
        self.majorVerification = try container.decodeIfPresent(Bool.self, forKey: "majorVerification") ?? false
        self.photoFileId = try container.decodeIfPresent(Int64.self, forKey: "photoFileId")
        self.photoWidth = try container.decodeIfPresent(Int32.self, forKey: "photoWidth")
        self.photoHeight = try container.decodeIfPresent(Int32.self, forKey: "photoHeight")
        self.giftNameDraft = try container.decodeIfPresent(String.self, forKey: "giftNameDraft") ?? ""
        self.giftNumberDraft = try container.decodeIfPresent(String.self, forKey: "giftNumberDraft") ?? ""
        self.gifts = try container.decodeIfPresent([ManualStarGiftEntry].self, forKey: "gifts") ?? []
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode(self.firstName, forKey: "firstName")
        try container.encode(self.lastName, forKey: "lastName")
        try container.encode(self.anonymousNumber, forKey: "anonymousNumber")
        try container.encode(self.usernameDraft, forKey: "usernameDraft")
        try container.encode(self.usernames, forKey: "usernames")
        try container.encode(self.holdVerification, forKey: "holdVerification")
        try container.encodeIfPresent(self.holdVerificationInfo, forKey: "holdVerificationInfo")
        try container.encode(self.majorVerification, forKey: "majorVerification")
        try container.encodeIfPresent(self.photoFileId, forKey: "photoFileId")
        try container.encodeIfPresent(self.photoWidth, forKey: "photoWidth")
        try container.encodeIfPresent(self.photoHeight, forKey: "photoHeight")
        try container.encode(self.giftNameDraft, forKey: "giftNameDraft")
        try container.encode(self.giftNumberDraft, forKey: "giftNumberDraft")
        try container.encode(self.gifts, forKey: "gifts")
    }
    
    public var trimmedFirstName: String {
        return self.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public var trimmedLastName: String {
        return self.lastName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public var needsHoldResolve: Bool {
        guard self.holdVerification else {
            return false
        }
        guard let info = self.holdVerificationInfo else {
            return true
        }
        return info.isPlaceholderOrganizationVerification || info.iconFileId == 0
    }
    
    public var hasDisplayNameOverride: Bool {
        return !self.trimmedFirstName.isEmpty || !self.trimmedLastName.isEmpty
    }
    
    public var hasPhotoOverride: Bool {
        return self.photoFileId != nil
    }
    
    public var normalizedAnonymousNumber: String? {
        let digits = self.anonymousNumber.filter(\.isNumber)
        if digits.isEmpty {
            return nil
        }
        if digits.hasPrefix("888") {
            return digits
        }
        return "888" + digits
    }
    
    public var normalizedUsernames: [String] {
        var result: [String] = []
        var seen = Set<String>()
        for raw in self.usernames {
            let value = ManualProfileSettings.normalizedUsername(raw)
            if value.isEmpty || seen.contains(value) {
                continue
            }
            seen.insert(value)
            result.append(value)
        }
        return result
    }
    
    public static func normalizedUsername(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("@") {
            value = String(value.dropFirst())
        }
        return value
    }
    
    public mutating func addUsernameFromDraft() {
        let value = ManualProfileSettings.normalizedUsername(self.usernameDraft)
        self.usernameDraft = ""
        guard !value.isEmpty else {
            return
        }
        if !self.normalizedUsernames.contains(value) {
            self.usernames.append(value)
        }
    }
    
    public mutating func removeUsername(at index: Int) {
        let names = self.normalizedUsernames
        guard index >= 0, index < names.count else {
            return
        }
        self.usernames = names
        self.usernames.remove(at: index)
    }
    
    public mutating func upsertGift(_ entry: ManualStarGiftEntry) {
        if let index = self.gifts.firstIndex(where: { $0.slug == entry.slug }) {
            self.gifts[index] = entry
        } else {
            self.gifts.append(entry)
        }
        self.giftNameDraft = ""
        self.giftNumberDraft = ""
    }
    
    public mutating func removeGift(at index: Int) {
        guard index >= 0, index < self.gifts.count else {
            return
        }
        self.gifts.remove(at: index)
    }
    
    public mutating func setGiftPinned(at index: Int, pinned: Bool) {
        guard index >= 0, index < self.gifts.count else {
            return
        }
        self.gifts[index].pinnedToTop = pinned
        if pinned {
            self.gifts[index].savedToProfile = true
        }
    }
    
    public mutating func setGiftWear(at index: Int, wear: Bool) {
        guard index >= 0, index < self.gifts.count else {
            return
        }
        for i in 0 ..< self.gifts.count {
            self.gifts[i].wear = wear && i == index
        }
        if wear {
            self.gifts[index].savedToProfile = true
        }
    }
    
    public mutating func clearPhoto() {
        self.photoFileId = nil
        self.photoWidth = nil
        self.photoHeight = nil
        DeveloperFeaturePersistence.clearPhoto()
    }
    
    public static func persistPhotoData(_ data: Data) {
        DeveloperFeaturePersistence.savePhoto(data)
    }
    
    public static func storedPhotoData() -> Data? {
        return DeveloperFeaturePersistence.loadPhoto()
    }
    
    public static func fromPreference(_ entry: PreferencesEntry?) -> ManualProfileSettings {
        return DeveloperFeaturePersistence.fromPreference(ManualProfileSettings.self, entry: entry, key: DeveloperFeaturePersistence.manualKey, empty: .defaultSettings)
    }
}

public func updateManualProfileSettings(engine: TelegramEngine, _ f: @escaping (ManualProfileSettings) -> ManualProfileSettings) -> Signal<Never, NoError> {
    return engine.preferences.update(id: ApplicationSpecificPreferencesKeys.manualProfileSettings, { entry in
        let currentSettings = ManualProfileSettings.fromPreference(entry)
        let next = f(currentSettings)
        DeveloperFeaturePersistence.save(next, key: DeveloperFeaturePersistence.manualKey)
        return SharedPreferencesEntry(next)
    })
}
