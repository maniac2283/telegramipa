import Foundation
import Postbox
import SwiftSignalKit

public final class ChannelSpoofingOverlayState {
    public let ownedChannelId: PeerId
    public let sourceChannelId: PeerId
    public let sourceChannel: TelegramChannel
    public let sourceCachedData: CachedChannelData?
    
    public init(ownedChannelId: PeerId, sourceChannelId: PeerId, sourceChannel: TelegramChannel, sourceCachedData: CachedChannelData?) {
        self.ownedChannelId = ownedChannelId
        self.sourceChannelId = sourceChannelId
        self.sourceChannel = sourceChannel
        self.sourceCachedData = sourceCachedData
    }
}

public enum ChannelSpoofingOverlay {
    private static let lock = NSLock()
    private static var states: [PeerId: ChannelSpoofingOverlayState] = [:]
    
    public static func current(for channelId: PeerId) -> ChannelSpoofingOverlayState? {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.states[channelId]
    }
    
    public static func set(_ state: ChannelSpoofingOverlayState?, for channelId: PeerId, persist: Bool = true) {
        self.lock.lock()
        if let state {
            self.states[channelId] = state
        } else {
            self.states.removeValue(forKey: channelId)
        }
        self.lock.unlock()
        PeerDisplayOverlay.notifyUpdated()
        if persist {
            let key = Self.defaultsKey(for: channelId)
            if let state {
                UserDefaults.standard.set(state.sourceChannelId.toInt64(), forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
    
    public static func historyPeerId(for channelId: PeerId) -> PeerId? {
        if let state = self.current(for: channelId) {
            return state.sourceChannelId
        }
        if let raw = UserDefaults.standard.object(forKey: Self.defaultsKey(for: channelId)) as? Int64 {
            return PeerId(raw)
        }
        return nil
    }
    
    public static func persistMapping(ownedChannelId: PeerId, sourceChannelId: PeerId) {
        UserDefaults.standard.set(sourceChannelId.toInt64(), forKey: Self.defaultsKey(for: ownedChannelId))
    }
    
    private static func defaultsKey(for channelId: PeerId) -> String {
        return "telegram.channelSpoofing.source.\(channelId.toInt64())"
    }
    
    public static func applyVisual(to channel: TelegramChannel) -> TelegramChannel {
        guard let state = self.current(for: channel.id) else {
            return channel
        }
        return makeSpoofedChannel(owned: channel, source: state.sourceChannel)
    }
    
    public static func applyCached(peerId: PeerId, data: CachedChannelData) -> CachedChannelData {
        guard let state = self.current(for: peerId), let target = state.sourceCachedData else {
            return data
        }
        return mergeCached(owned: data, source: target)
    }
    
    public static func makeSpoofedChannel(owned: TelegramChannel, source: TelegramChannel) -> TelegramChannel {
        var flags = owned.flags
        flags.remove(.isVerified)
        flags.remove(.isScam)
        flags.remove(.isFake)
        if source.flags.contains(.isVerified) {
            flags.insert(.isVerified)
        }
        if source.flags.contains(.isScam) {
            flags.insert(.isScam)
        }
        if source.flags.contains(.isFake) {
            flags.insert(.isFake)
        }
        flags.insert(.isCreator)
        
        let nameColor: PeerNameColor?
        if source.photo.isEmpty {
            if let sourceColor = source.nameColor {
                nameColor = sourceColor
            } else {
                nameColor = PeerNameColor(rawValue: Int32(abs(source.id.id._internalGetInt64Value()) % 7))
            }
        } else {
            nameColor = source.nameColor
        }
        
        return TelegramChannel(
            id: owned.id,
            accessHash: owned.accessHash,
            title: source.title,
            username: source.username,
            photo: source.photo,
            creationDate: owned.creationDate,
            version: owned.version,
            participationStatus: owned.participationStatus,
            info: owned.info,
            flags: flags,
            restrictionInfo: source.restrictionInfo,
            adminRights: owned.adminRights,
            bannedRights: owned.bannedRights,
            defaultBannedRights: owned.defaultBannedRights,
            usernames: source.usernames,
            storiesHidden: owned.storiesHidden,
            nameColor: nameColor,
            backgroundEmojiId: source.backgroundEmojiId,
            profileColor: source.photo.isEmpty ? (source.profileColor ?? nameColor) : source.profileColor,
            profileBackgroundEmojiId: source.profileBackgroundEmojiId,
            emojiStatus: source.emojiStatus,
            approximateBoostLevel: source.approximateBoostLevel,
            subscriptionUntilDate: owned.subscriptionUntilDate,
            verificationIconFileId: source.verificationIconFileId,
            sendPaidMessageStars: owned.sendPaidMessageStars,
            linkedMonoforumId: owned.linkedMonoforumId,
            linkedCommunityId: owned.linkedCommunityId
        )
    }
    
    public static func mergeCached(owned: CachedChannelData, source: CachedChannelData) -> CachedChannelData {
        let summary = CachedChannelParticipantsSummary(
            memberCount: source.participantsSummary.memberCount,
            adminCount: owned.participantsSummary.adminCount,
            bannedCount: owned.participantsSummary.bannedCount,
            kickedCount: owned.participantsSummary.kickedCount
        )
        return owned
            .withUpdatedAbout(source.about)
            .withUpdatedParticipantsSummary(summary)
            .withUpdatedPhoto(source.photo)
            .withUpdatedChatTheme(source.chatTheme)
            .withUpdatedWallpaper(source.wallpaper)
            .withUpdatedVerification(source.verification)
            .withUpdatedStarGiftsCount(source.starGiftsCount)
            .withUpdatedMainProfileTab(source.mainProfileTab)
            .withUpdatedEmojiPack(source.emojiPack)
            .withUpdatedReactionSettings(source.reactionSettings)
    }
    
    public static func applyToPostbox(account: Account, channelId: PeerId) -> Signal<Never, NoError> {
        let _ = account
        let _ = channelId
        return .complete()
    }
}
