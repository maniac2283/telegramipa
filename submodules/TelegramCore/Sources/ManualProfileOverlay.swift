import Foundation
import Postbox
import SwiftSignalKit

public struct ManualOverlayGift: Equatable, Codable {
    public var uniqueGift: StarGift.UniqueGift
    public var pinnedToTop: Bool
    public var savedToProfile: Bool
    public var wear: Bool
    public var date: Int32
    
    public init(uniqueGift: StarGift.UniqueGift, pinnedToTop: Bool, savedToProfile: Bool, wear: Bool, date: Int32) {
        self.uniqueGift = uniqueGift
        self.pinnedToTop = pinnedToTop
        self.savedToProfile = savedToProfile
        self.wear = wear
        self.date = date
    }
    
    public var slug: String {
        return self.uniqueGift.slug
    }
}

public final class ManualProfileOverlayState: Equatable {
    public let accountPeerId: PeerId
    public let firstName: String?
    public let lastName: String?
    public let phone: String?
    public let usernames: [TelegramPeerUsername]
    public let holdVerification: PeerVerification?
    public let majorVerification: Bool
    public let photo: [TelegramMediaImageRepresentation]
    public let gifts: [ManualOverlayGift]
    
    public init(
        accountPeerId: PeerId,
        firstName: String?,
        lastName: String?,
        phone: String?,
        usernames: [TelegramPeerUsername],
        holdVerification: PeerVerification?,
        majorVerification: Bool,
        photo: [TelegramMediaImageRepresentation],
        gifts: [ManualOverlayGift]
    ) {
        self.accountPeerId = accountPeerId
        self.firstName = firstName
        self.lastName = lastName
        self.phone = phone
        self.usernames = usernames
        self.holdVerification = holdVerification
        self.majorVerification = majorVerification
        self.photo = photo
        self.gifts = gifts
    }
    
    public var hasAnyOverride: Bool {
        if self.firstName != nil || self.lastName != nil {
            return true
        }
        if self.phone != nil {
            return true
        }
        if !self.usernames.isEmpty {
            return true
        }
        if self.holdVerification != nil || self.majorVerification {
            return true
        }
        if !self.photo.isEmpty {
            return true
        }
        if !self.gifts.isEmpty {
            return true
        }
        return false
    }
    
    public var wornGift: ManualOverlayGift? {
        return self.gifts.first(where: { $0.wear })
    }
    
    public static func ==(lhs: ManualProfileOverlayState, rhs: ManualProfileOverlayState) -> Bool {
        if lhs.accountPeerId != rhs.accountPeerId {
            return false
        }
        if lhs.firstName != rhs.firstName || lhs.lastName != rhs.lastName {
            return false
        }
        if lhs.phone != rhs.phone {
            return false
        }
        if lhs.usernames != rhs.usernames {
            return false
        }
        if lhs.holdVerification != rhs.holdVerification || lhs.majorVerification != rhs.majorVerification {
            return false
        }
        if lhs.photo != rhs.photo {
            return false
        }
        if lhs.gifts != rhs.gifts {
            return false
        }
        return true
    }
}

public enum ManualProfileOverlay {
    public static let holdIconFileId: Int64 = 5417910750124361856
    public static let holdVerifierUsername = "hold_wallet_bot"
    public static let holdVerificationDescription = "This user was verified by the organization \"Hold\"."
    
    public static func fallbackHoldVerification(botId: PeerId? = nil) -> PeerVerification {
        return PeerVerification(
            botId: botId ?? PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1)),
            iconFileId: Self.holdIconFileId,
            description: Self.holdVerificationDescription
        )
    }
    
    public static func organizationVerification(botId: PeerId, settings: BotVerifierSettings, fallbackDescription: String) -> PeerVerification {
        let custom = settings.customDescription?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return PeerVerification(
            botId: botId,
            iconFileId: settings.iconFileId != 0 ? settings.iconFileId : Self.holdIconFileId,
            description: custom.isEmpty ? fallbackDescription : custom
        )
    }
    
    private static let lock = NSLock()
    private static var state: ManualProfileOverlayState?
    private static let giftsPersistPipe = ValuePipe<[ManualOverlayGift]>()
    
    public static var giftsUpdated: Signal<[ManualOverlayGift], NoError> {
        return self.giftsPersistPipe.signal()
    }
    
    public static func current(for peerId: PeerId) -> ManualProfileOverlayState? {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        guard let state, state.accountPeerId == peerId, state.hasAnyOverride else {
            return nil
        }
        return state
    }
    
    public static func gifts(for peerId: PeerId) -> [ManualOverlayGift] {
        return self.current(for: peerId)?.gifts ?? []
    }
    
    public static func containsGift(slug: String, peerId: PeerId) -> Bool {
        return self.gifts(for: peerId).contains(where: { $0.slug == slug })
    }
    
    public static func isOverlayReference(_ reference: StarGiftReference, peerId: PeerId) -> Bool {
        guard case let .slug(slug) = reference else {
            return false
        }
        return self.containsGift(slug: slug, peerId: peerId)
    }
    
    public static func set(_ next: ManualProfileOverlayState?) {
        self.lock.lock()
        self.state = next
        self.lock.unlock()
        PeerDisplayOverlay.notifyUpdated()
    }
    
    public static func replaceGifts(_ gifts: [ManualOverlayGift], persist: Bool) {
        self.lock.lock()
        guard let current = self.state else {
            self.lock.unlock()
            return
        }
        let next = ManualProfileOverlayState(
            accountPeerId: current.accountPeerId,
            firstName: current.firstName,
            lastName: current.lastName,
            phone: current.phone,
            usernames: current.usernames,
            holdVerification: current.holdVerification,
            majorVerification: current.majorVerification,
            photo: current.photo,
            gifts: gifts
        )
        self.state = next.hasAnyOverride ? next : nil
        self.lock.unlock()
        PeerDisplayOverlay.notifyUpdated()
        if persist {
            self.giftsPersistPipe.putNext(gifts)
        }
    }
    
    public static func setGiftPinned(slug: String, pinnedToTop: Bool, peerId: PeerId) -> Bool {
        let gifts = self.gifts(for: peerId)
        guard gifts.contains(where: { $0.slug == slug }) else {
            return false
        }
        let next = gifts.map { gift -> ManualOverlayGift in
            var gift = gift
            if gift.slug == slug {
                gift.pinnedToTop = pinnedToTop
                if pinnedToTop {
                    gift.savedToProfile = true
                }
            }
            return gift
        }
        self.replaceGifts(next, persist: true)
        return true
    }
    
    public static func setGiftSaved(slug: String, savedToProfile: Bool, peerId: PeerId) -> Bool {
        let gifts = self.gifts(for: peerId)
        guard gifts.contains(where: { $0.slug == slug }) else {
            return false
        }
        let next = gifts.map { gift -> ManualOverlayGift in
            var gift = gift
            if gift.slug == slug {
                gift.savedToProfile = savedToProfile
                if !savedToProfile {
                    gift.pinnedToTop = false
                }
            }
            return gift
        }
        self.replaceGifts(next, persist: true)
        return true
    }
    
    public static func setPinnedSlugs(_ slugs: [String], peerId: PeerId) {
        let pinned = Set(slugs)
        let next = self.gifts(for: peerId).map { gift -> ManualOverlayGift in
            var gift = gift
            gift.pinnedToTop = pinned.contains(gift.slug)
            if gift.pinnedToTop {
                gift.savedToProfile = true
            }
            return gift
        }
        self.replaceGifts(next, persist: true)
    }
    
    public static func wearGift(slug: String, peerId: PeerId) -> Bool {
        let gifts = self.gifts(for: peerId)
        guard gifts.contains(where: { $0.slug == slug }) else {
            return false
        }
        let next = gifts.map { gift -> ManualOverlayGift in
            var gift = gift
            gift.wear = gift.slug == slug
            if gift.wear {
                gift.savedToProfile = true
            }
            return gift
        }
        self.replaceGifts(next, persist: true)
        return true
    }
    
    public static func clearWear(peerId: PeerId) -> Bool {
        let gifts = self.gifts(for: peerId)
        guard gifts.contains(where: { $0.wear }) else {
            return false
        }
        let next = gifts.map { gift -> ManualOverlayGift in
            var gift = gift
            gift.wear = false
            return gift
        }
        self.replaceGifts(next, persist: true)
        return true
    }
    
    public static func applyVisual(to user: TelegramUser) -> TelegramUser {
        guard let state = self.current(for: user.id) else {
            return user
        }
        
        var flags = user.flags
        if state.majorVerification {
            flags.insert(.isVerified)
        }
        
        var firstName = user.firstName
        var lastName = user.lastName
        if state.firstName != nil || state.lastName != nil {
            firstName = state.firstName
            lastName = state.lastName
        }
        
        var phone = user.phone
        if let overlayPhone = state.phone {
            phone = overlayPhone
        }
        
        var username = user.username
        var usernames = user.usernames
        if !state.usernames.isEmpty {
            usernames = state.usernames
            username = state.usernames.first?.username
        }
        
        var photo = user.photo
        if !state.photo.isEmpty {
            photo = state.photo
        }
        
        var verificationIconFileId = user.verificationIconFileId
        if let holdVerification = state.holdVerification {
            verificationIconFileId = holdVerification.iconFileId
        }
        
        var emojiStatus = user.emojiStatus
        if let worn = state.wornGift, let status = Self.emojiStatus(for: worn.uniqueGift) {
            emojiStatus = status
        }
        
        return TelegramUser(
            id: user.id,
            accessHash: user.accessHash,
            firstName: firstName,
            lastName: lastName,
            username: username,
            phone: phone,
            photo: photo,
            botInfo: user.botInfo,
            restrictionInfo: user.restrictionInfo,
            flags: flags,
            emojiStatus: emojiStatus,
            usernames: usernames,
            storiesHidden: user.storiesHidden,
            nameColor: user.nameColor,
            backgroundEmojiId: user.backgroundEmojiId,
            profileColor: user.profileColor,
            profileBackgroundEmojiId: user.profileBackgroundEmojiId,
            subscriberCount: user.subscriberCount,
            verificationIconFileId: verificationIconFileId,
            linkedCommunityId: user.linkedCommunityId
        )
    }
    
    public static func applyCached(peerId: PeerId, data: CachedUserData) -> CachedUserData {
        guard let state = self.current(for: peerId) else {
            return data
        }
        var next = data
        if let holdVerification = state.holdVerification {
            next = next.withUpdatedVerification(holdVerification)
        }
        let overlayCount = Int32(state.gifts.filter(\.savedToProfile).count)
        if overlayCount > 0 {
            next = next.withUpdatedStarGiftsCount((data.starGiftsCount ?? 0) + overlayCount)
        }
        return next
    }
    
    public static func profileStarGifts(for peerId: PeerId) -> [ProfileGiftsContext.State.StarGift] {
        guard let state = self.current(for: peerId) else {
            return []
        }
        return state.gifts.map { entry in
            let owned = entry.uniqueGift.withOwner(.peerId(peerId))
            return ProfileGiftsContext.State.StarGift(
                gift: .unique(owned),
                reference: .slug(slug: owned.slug),
                fromPeer: nil,
                date: entry.date,
                text: nil,
                entities: nil,
                nameHidden: false,
                savedToProfile: entry.savedToProfile,
                pinnedToTop: entry.pinnedToTop,
                convertStars: nil,
                canUpgrade: false,
                canExportDate: nil,
                upgradeStars: nil,
                transferStars: nil,
                canTransferDate: nil,
                canResaleDate: nil,
                collectionIds: nil,
                prepaidUpgradeHash: nil,
                upgradeSeparate: false,
                dropOriginalDetailsStars: nil,
                number: owned.number,
                isRefunded: false,
                canCraftAt: nil
            )
        }
    }
    
    public static func mergeProfileGifts(_ gifts: [ProfileGiftsContext.State.StarGift], peerId: PeerId, accountPeerId: PeerId) -> [ProfileGiftsContext.State.StarGift] {
        guard peerId == accountPeerId else {
            return gifts
        }
        let overlayGifts = self.profileStarGifts(for: peerId)
        guard !overlayGifts.isEmpty else {
            return gifts
        }
        var existingSlugs = Set<String>()
        for gift in gifts {
            if case let .unique(unique) = gift.gift {
                existingSlugs.insert(unique.slug)
            }
            if case let .slug(slug) = gift.reference {
                existingSlugs.insert(slug)
            }
        }
        let extra = overlayGifts.filter { gift in
            if case let .unique(unique) = gift.gift {
                return !existingSlugs.contains(unique.slug)
            }
            return true
        }
        guard !extra.isEmpty else {
            return gifts
        }
        let pinned = extra.filter(\.pinnedToTop) + gifts.filter(\.pinnedToTop)
        let rest = extra.filter { !$0.pinnedToTop } + gifts.filter { !$0.pinnedToTop }
        return pinned + rest
    }
    
    public static func emojiStatus(for gift: StarGift.UniqueGift) -> PeerEmojiStatus? {
        var fileId: Int64?
        var patternFileId: Int64?
        var innerColor: Int32?
        var outerColor: Int32?
        var patternColor: Int32?
        var textColor: Int32?
        for attribute in gift.attributes {
            switch attribute {
            case let .model(_, file, _, _):
                fileId = file.fileId.id
            case let .pattern(_, file, _):
                patternFileId = file.fileId.id
            case let .backdrop(_, _, inner, outer, pattern, text, _):
                innerColor = inner
                outerColor = outer
                patternColor = pattern
                textColor = text
            default:
                break
            }
        }
        guard let fileId, let patternFileId, let innerColor, let outerColor, let patternColor, let textColor else {
            return nil
        }
        return PeerEmojiStatus(content: .starGift(id: gift.id, fileId: fileId, title: gift.title, slug: gift.slug, patternFileId: patternFileId, innerColor: innerColor, outerColor: outerColor, patternColor: patternColor, textColor: textColor), expirationDate: nil)
    }
    
    public static func makePeerUsernames(_ names: [String]) -> [TelegramPeerUsername] {
        return names.enumerated().map { index, name in
            var flags: TelegramPeerUsername.Flags = [.isActive]
            if index == 0 {
                flags.insert(.isEditable)
            }
            return TelegramPeerUsername(flags: flags, username: name)
        }
    }
    
    public static func makeLocalPhoto(fileId: Int64, width: Int32, height: Int32, size: Int64?) -> [TelegramMediaImageRepresentation] {
        let resource = LocalFileMediaResource(fileId: fileId, size: size)
        return [
            TelegramMediaImageRepresentation(
                dimensions: PixelDimensions(width: width, height: height),
                resource: resource,
                progressiveSizes: [],
                immediateThumbnailData: nil,
                hasVideo: false,
                isPersonal: false
            )
        ]
    }
    
    public static func slug(fromName name: String, number: String) -> String? {
        var value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("@") {
            value = String(value.dropFirst())
        }
        let lowered = value.lowercased()
        for prefix in ["https://t.me/nft/", "http://t.me/nft/", "t.me/nft/"] {
            if lowered.hasPrefix(prefix) {
                value = String(value.dropFirst(prefix.count))
                break
            }
        }
        if let slash = value.firstIndex(of: "/") {
            value = String(value[value.index(after: slash)...])
        }
        if let query = value.firstIndex(of: "?") {
            value = String(value[..<query])
        }
        value = value.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let digits = number.filter(\.isNumber)
        if value.contains("-"), digits.isEmpty {
            return value.isEmpty ? nil : value
        }
        let compact = value.filter { !$0.isWhitespace && $0 != "#" }
        if compact.isEmpty || digits.isEmpty {
            return nil
        }
        return "\(compact)-\(digits)"
    }
}

extension PeerVerification {
    public var isPlaceholderOrganizationVerification: Bool {
        let trimmed = self.description.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return true
        }
        return trimmed.compare("Hold Verification", options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }
}
