import Foundation
import Postbox
import SwiftSignalKit

public final class ProfileSpoofingOverlayState {
    public let targetPeerId: PeerId
    public let targetUser: TelegramUser
    public let targetCachedData: CachedUserData?
    
    public init(targetPeerId: PeerId, targetUser: TelegramUser, targetCachedData: CachedUserData?) {
        self.targetPeerId = targetPeerId
        self.targetUser = targetUser
        self.targetCachedData = targetCachedData
    }
}

public enum ProfileSpoofingOverlay {
    private static let lock = NSLock()
    private static var states: [PeerId: ProfileSpoofingOverlayState] = [:]
    
    public static func current(for accountPeerId: PeerId) -> ProfileSpoofingOverlayState? {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.states[accountPeerId]
    }
    
    public static func set(_ state: ProfileSpoofingOverlayState?, for accountPeerId: PeerId, persist: Bool = true) {
        self.lock.lock()
        if let state {
            self.states[accountPeerId] = state
        } else {
            self.states.removeValue(forKey: accountPeerId)
        }
        self.lock.unlock()
        PeerDisplayOverlay.notifyUpdated()
        if persist {
            let key = "telegram.profileSpoofing.target.\(accountPeerId.toInt64())"
            if let state {
                UserDefaults.standard.set(state.targetPeerId.toInt64(), forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
            UserDefaults.standard.synchronize()
        }
    }
    
    public static func applyVisual(to user: TelegramUser) -> TelegramUser {
        guard let state = self.current(for: user.id) else {
            return user
        }
        return makeSpoofedUser(selfUser: user, target: state.targetUser)
    }
    
    public static func applyCached(peerId: PeerId, data: CachedUserData) -> CachedUserData {
        guard let state = self.current(for: peerId), let target = state.targetCachedData else {
            return data
        }
        return mergeCached(selfData: data, target: target)
    }
    
    public static func makeSpoofedUser(selfUser: TelegramUser, target: TelegramUser) -> TelegramUser {
        var flags = selfUser.flags
        flags.remove(.isVerified)
        flags.remove(.isPremium)
        flags.remove(.isScam)
        flags.remove(.isFake)
        flags.remove(.isSupport)
        if target.flags.contains(.isVerified) {
            flags.insert(.isVerified)
        }
        if target.flags.contains(.isPremium) {
            flags.insert(.isPremium)
        }
        if target.flags.contains(.isScam) {
            flags.insert(.isScam)
        }
        if target.flags.contains(.isFake) {
            flags.insert(.isFake)
        }
        if target.flags.contains(.isSupport) {
            flags.insert(.isSupport)
        }
        
        return TelegramUser(
            id: selfUser.id,
            accessHash: selfUser.accessHash,
            firstName: target.firstName,
            lastName: target.lastName,
            username: target.username,
            phone: Self.spoofedPhone(from: target),
            photo: target.photo,
            botInfo: selfUser.botInfo,
            restrictionInfo: target.restrictionInfo,
            flags: flags,
            emojiStatus: target.emojiStatus,
            usernames: target.usernames,
            storiesHidden: selfUser.storiesHidden,
            nameColor: target.nameColor,
            backgroundEmojiId: target.backgroundEmojiId,
            profileColor: target.profileColor,
            profileBackgroundEmojiId: target.profileBackgroundEmojiId,
            subscriberCount: target.subscriberCount,
            verificationIconFileId: target.verificationIconFileId,
            linkedCommunityId: target.linkedCommunityId
        )
    }
    
    public static func isAnonymousNumber(_ phone: String?) -> Bool {
        guard let phone else {
            return false
        }
        let digits = phone.filter(\.isNumber)
        return digits.hasPrefix("888")
    }
    
    public static func spoofedPhone(from target: TelegramUser, fallback: String? = nil) -> String? {
        if isAnonymousNumber(target.phone) {
            return target.phone
        }
        let _ = fallback
        return nil
    }
    
    public static func mergeCached(selfData: CachedUserData, target: CachedUserData) -> CachedUserData {
        return CachedUserData(
            about: target.about,
            botInfo: selfData.botInfo,
            editableBotInfo: selfData.editableBotInfo,
            peerStatusSettings: selfData.peerStatusSettings,
            pinnedMessageId: selfData.pinnedMessageId,
            isBlocked: selfData.isBlocked,
            commonGroupCount: selfData.commonGroupCount,
            voiceCallsAvailable: selfData.voiceCallsAvailable,
            videoCallsAvailable: selfData.videoCallsAvailable,
            callsPrivate: selfData.callsPrivate,
            canPinMessages: selfData.canPinMessages,
            hasScheduledMessages: selfData.hasScheduledMessages,
            autoremoveTimeout: selfData.autoremoveTimeout,
            chatTheme: target.chatTheme,
            photo: target.photo,
            personalPhoto: target.personalPhoto,
            fallbackPhoto: target.fallbackPhoto,
            voiceMessagesAvailable: selfData.voiceMessagesAvailable,
            wallpaper: target.wallpaper,
            flags: selfData.flags,
            businessHours: selfData.businessHours,
            businessLocation: selfData.businessLocation,
            greetingMessage: selfData.greetingMessage,
            awayMessage: selfData.awayMessage,
            connectedBot: selfData.connectedBot,
            businessIntro: selfData.businessIntro,
            birthday: target.birthday,
            personalChannel: target.personalChannel,
            botPreview: selfData.botPreview,
            starGiftsCount: target.starGiftsCount,
            starRefProgram: selfData.starRefProgram,
            verification: target.verification,
            sendPaidMessageStars: selfData.sendPaidMessageStars,
            disallowedGifts: selfData.disallowedGifts,
            botGroupAdminRights: selfData.botGroupAdminRights,
            botChannelAdminRights: selfData.botChannelAdminRights,
            starRating: target.starRating,
            pendingStarRating: target.pendingStarRating,
            mainProfileTab: target.mainProfileTab,
            savedMusic: target.savedMusic,
            note: selfData.note,
            myCopyProtectionEnableDate: selfData.myCopyProtectionEnableDate,
            botManagerId: selfData.botManagerId
        )
    }
    
    public static func applyToPostbox(account: Account) -> Signal<Never, NoError> {
        let _ = account
        return .complete()
    }
}
