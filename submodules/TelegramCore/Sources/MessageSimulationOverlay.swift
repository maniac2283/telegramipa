import Foundation
import Postbox
import SwiftSignalKit

public final class MessageSimulationOverlayState {
    public let simulatedPeerId: PeerId
    public let sourcePeerId: PeerId
    public let sourceUser: TelegramUser
    public let sourceCachedData: CachedUserData?
    
    public init(simulatedPeerId: PeerId, sourcePeerId: PeerId, sourceUser: TelegramUser, sourceCachedData: CachedUserData?) {
        self.simulatedPeerId = simulatedPeerId
        self.sourcePeerId = sourcePeerId
        self.sourceUser = sourceUser
        self.sourceCachedData = sourceCachedData
    }
}

public enum MessageSimulationOverlay {
    private static let lock = NSLock()
    private static var states: [PeerId: MessageSimulationOverlayState] = [:]
    
    public static let syntheticIdBase: Int64 = 5_000_000_000_000
    
    public static func isSimulatedPeer(_ peerId: PeerId) -> Bool {
        guard peerId.namespace == Namespaces.Peer.CloudUser else {
            return false
        }
        let value = peerId.id._internalGetInt64Value()
        return value >= self.syntheticIdBase && value < self.syntheticIdBase + 1_000_000_000
    }
    
    public static func syntheticPeerId(for sourcePeerId: PeerId) -> PeerId {
        let raw = abs(sourcePeerId.toInt64())
        let idValue = self.syntheticIdBase + (raw % 1_000_000_000)
        return PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(idValue))
    }
    
    public static func current(for simulatedPeerId: PeerId) -> MessageSimulationOverlayState? {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.states[simulatedPeerId]
    }
    
    public static func sourcePeerId(for peerId: PeerId) -> PeerId? {
        return self.current(for: peerId)?.sourcePeerId
    }
    
    public static func set(_ state: MessageSimulationOverlayState?, for simulatedPeerId: PeerId) {
        self.lock.lock()
        if let state {
            self.states[simulatedPeerId] = state
        } else {
            self.states.removeValue(forKey: simulatedPeerId)
        }
        self.lock.unlock()
    }
    
    public static func applyVisual(to user: TelegramUser) -> TelegramUser {
        guard let state = self.current(for: user.id) else {
            return user
        }
        return makeSimulatedUser(simulatedId: user.id, target: state.sourceUser)
    }
    
    public static func applyCached(peerId: PeerId, data: CachedUserData) -> CachedUserData {
        guard let state = self.current(for: peerId), let target = state.sourceCachedData else {
            return data
        }
        return ProfileSpoofingOverlay.mergeCached(selfData: data, target: target).withUpdatedPeerStatusSettings(PeerStatusSettings(flags: [], managingBot: nil))
    }
    
    public static func makeSimulatedUser(simulatedId: PeerId, target: TelegramUser) -> TelegramUser {
        var flags = target.flags
        flags.remove(.requireStars)
        flags.remove(.requirePremium)
        return TelegramUser(
            id: simulatedId,
            accessHash: .personal(1),
            firstName: target.firstName,
            lastName: target.lastName,
            username: target.username,
            phone: nil,
            photo: target.photo,
            botInfo: target.botInfo,
            restrictionInfo: target.restrictionInfo,
            flags: flags,
            emojiStatus: target.emojiStatus,
            usernames: target.usernames,
            storiesHidden: target.storiesHidden,
            nameColor: target.nameColor,
            backgroundEmojiId: target.backgroundEmojiId,
            profileColor: target.profileColor,
            profileBackgroundEmojiId: target.profileBackgroundEmojiId,
            subscriberCount: target.subscriberCount,
            verificationIconFileId: target.verificationIconFileId,
            linkedCommunityId: target.linkedCommunityId
        )
    }
    
    public static func applyToPostbox(account: Account, simulatedPeerId: PeerId) -> Signal<Never, NoError> {
        return account.postbox.transaction { transaction -> Void in
            guard let state = self.current(for: simulatedPeerId) else {
                return
            }
            let simulated = makeSimulatedUser(simulatedId: simulatedPeerId, target: state.sourceUser)
            transaction.updatePeersInternal([simulated], update: { _, updated in
                return updated
            })
            transaction.updatePeerCachedData(peerIds: [simulatedPeerId], update: { _, current in
                let base = (current as? CachedUserData) ?? CachedUserData()
                if let targetCached = state.sourceCachedData {
                    return ProfileSpoofingOverlay.mergeCached(selfData: base, target: targetCached).withUpdatedPeerStatusSettings(PeerStatusSettings(flags: [], managingBot: nil))
                }
                return base.withUpdatedPeerStatusSettings(PeerStatusSettings(flags: [], managingBot: nil))
            })
            let timestamp = Int32(Date().timeIntervalSince1970)
            transaction.updatePeerPresencesInternal(presences: [simulatedPeerId: TelegramUserPresence(status: .present(until: timestamp + 300), lastActivity: timestamp)], merge: { _, updated in
                return updated
            })
            transaction.removeHole(peerId: simulatedPeerId, threadId: nil, namespace: Namespaces.Message.Cloud, space: .everywhere, range: 1 ... (Int32.max - 1))
            if transaction.getCombinedPeerReadState(simulatedPeerId) == nil {
                transaction.resetIncomingReadStates([simulatedPeerId: [
                    Namespaces.Message.Local: .idBased(maxIncomingReadId: 0, maxOutgoingReadId: 0, maxKnownId: 0, count: 0, markedUnread: false)
                ]])
            }
        }
        |> ignoreValues
    }
    
    public static func insertIncomingMessage(account: Account, peerId: PeerId, text: String, media: [Media], notify: Bool) -> Signal<Message?, NoError> {
        guard self.isSimulatedPeer(peerId) else {
            return .single(nil)
        }
        return account.postbox.transaction { transaction -> Message? in
            guard let _ = transaction.getPeer(peerId) as? TelegramUser else {
                return nil
            }
            let timestamp = Int32(Date().timeIntervalSince1970)
            var randomId: Int64 = 0
            arc4random_buf(&randomId, 8)
            let (tags, globalTags) = tagsForStoreMessage(incoming: true, attributes: [], media: media, textEntities: nil, isPinned: false)
            let storeMessage = StoreMessage(peerId: peerId, namespace: Namespaces.Message.Local, customStableId: nil, globallyUniqueId: randomId, groupingKey: nil, threadId: nil, timestamp: timestamp, flags: [.Incoming], tags: tags, globalTags: globalTags, localTags: [], forwardInfo: nil, authorId: peerId, text: text, attributes: [], media: media)
            let ids = transaction.addMessages([storeMessage], location: .UpperHistoryBlock)
            transaction.updatePeerChatListInclusion(peerId, inclusion: .ifHasMessagesOrOneOf(groupId: .root, pinningIndex: nil, minTimestamp: timestamp))
            transaction.removeHole(peerId: peerId, threadId: nil, namespace: Namespaces.Message.Cloud, space: .everywhere, range: 1 ... (Int32.max - 1))
            if let messageId = ids[randomId] {
                return transaction.getMessage(messageId)
            }
            return nil
        }
        |> mapToSignal { message -> Signal<Message?, NoError> in
            if notify, let message {
                account.stateManager.notifyIncomingMessages([message], notify: true)
            }
            return .single(message)
        }
    }
    
    public static func markOutgoingDelivered(account: Account, messageId: MessageId) -> Signal<Never, NoError> {
        return account.postbox.transaction { transaction -> Void in
            transaction.updateMessage(messageId, update: { currentMessage in
                var flags = StoreMessageFlags(currentMessage.flags)
                flags.remove(.Unsent)
                flags.remove(.Sending)
                flags.remove(.Failed)
                var localTags = currentMessage.localTags
                localTags.insert(.OutgoingDeliveredToServer)
                return .update(StoreMessage(id: currentMessage.id, customStableId: nil, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: flags, tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: localTags, forwardInfo: currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init), authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: currentMessage.media))
            })
        }
        |> ignoreValues
    }
    
    public static func markOutgoingRead(account: Account, messageId: MessageId) -> Signal<Never, NoError> {
        return account.postbox.transaction { transaction -> Void in
            if let message = transaction.getMessage(messageId) {
                let _ = transaction.applyOutgoingReadMaxIndex(message.index)
            }
        }
        |> ignoreValues
    }
    
    public static func simulatedReplyText(to text: String, hasMedia: Bool) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if hasMedia && trimmed.isEmpty {
            return ["Looks good 👍", "Nice shot", "Got the picture"].randomElement() ?? "Looks good 👍"
        }
        if trimmed.contains("?") {
            return ["Yeah, that works", "I think so", "Sure 👍"].randomElement() ?? "Yeah"
        }
        if trimmed.count <= 2 {
            return ["👍", "Okay", "Yep"].randomElement() ?? "Okay"
        }
        let replies = [
            "Okay, sounds good",
            "Got it",
            "Makes sense",
            "Alright 👍",
            "I'll take a look",
            "Thanks for the update"
        ]
        return replies.randomElement() ?? "Got it"
    }
}
