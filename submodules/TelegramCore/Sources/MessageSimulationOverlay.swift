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
    
    public static func set(_ state: MessageSimulationOverlayState?, for simulatedPeerId: PeerId, persist: Bool = true) {
        self.lock.lock()
        if let state {
            self.states[simulatedPeerId] = state
        } else {
            self.states.removeValue(forKey: simulatedPeerId)
        }
        self.lock.unlock()
        PeerDisplayOverlay.notifyUpdated()
        if persist {
            let key = Self.defaultsKey(for: simulatedPeerId)
            if let state {
                UserDefaults.standard.set(state.sourcePeerId.toInt64(), forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
            UserDefaults.standard.synchronize()
        }
    }
    
    private static func defaultsKey(for simulatedPeerId: PeerId) -> String {
        return "telegram.messageSimulation.source.\(simulatedPeerId.toInt64())"
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
        return ProfileSpoofingOverlay.mergeCached(selfData: data, target: target).withUpdatedPeerStatusSettings(PeerStatusSettings(flags: [], managingBot: nil)).withUpdatedBusinessIntro(nil)
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
                let merged: CachedUserData
                if let targetCached = state.sourceCachedData {
                    merged = ProfileSpoofingOverlay.mergeCached(selfData: base, target: targetCached)
                } else {
                    merged = base
                }
                return merged
                    .withUpdatedPeerStatusSettings(PeerStatusSettings(flags: [], managingBot: nil))
                    .withUpdatedBusinessIntro(nil)
            })
            let timestamp = Int32(Date().timeIntervalSince1970)
            transaction.updatePeerPresencesInternal(presences: [simulatedPeerId: TelegramUserPresence(status: .present(until: timestamp + 300), lastActivity: timestamp)], merge: { _, updated in
                return updated
            })
            self.prepareLocalHistory(transaction: transaction, peerId: simulatedPeerId)
            transaction.updatePeerChatListInclusion(simulatedPeerId, inclusion: .ifHasMessagesOrOneOf(groupId: .root, pinningIndex: nil, minTimestamp: timestamp))
            if transaction.getCombinedPeerReadState(simulatedPeerId) == nil {
                transaction.resetIncomingReadStates([simulatedPeerId: [
                    Namespaces.Message.Local: .idBased(maxIncomingReadId: 0, maxOutgoingReadId: 0, maxKnownId: 0, count: 0, markedUnread: false)
                ]])
            }
            transaction.confirmSynchronizedIncomingReadState(simulatedPeerId)
        }
        |> ignoreValues
    }
    
    public static func insertIncomingMessage(account: Account, peerId: PeerId, text: String, media: [Media], notify: Bool) -> Signal<Message?, NoError> {
        return self.insertLocalMessage(account: account, peerId: peerId, text: text, media: media, incoming: true, notify: notify)
    }
    
    public static func insertLocalMessage(account: Account, peerId: PeerId, text: String, media: [Media], incoming: Bool, notify: Bool) -> Signal<Message?, NoError> {
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
            if randomId == 0 {
                randomId = Int64.random(in: 1 ... Int64.max)
            }
            let (tags, globalTags) = tagsForStoreMessage(incoming: incoming, attributes: [], media: media, textEntities: nil, isPinned: false)
            var flags = StoreMessageFlags()
            if incoming {
                flags.insert(.Incoming)
            }
            let authorId = incoming ? peerId : account.peerId
            var nextId: Int32 = 0
            let storeMessage = self.uniqueLocalStoreMessage(transaction: transaction, peerId: peerId, nextId: &nextId, globallyUniqueId: randomId, groupingKey: nil, threadId: nil, timestamp: timestamp, flags: flags, tags: tags, globalTags: globalTags, localTags: [], forwardInfo: nil, authorId: authorId, text: text, attributes: [], media: media)
            let ids = transaction.addMessages([storeMessage], location: .UpperHistoryBlock)
            transaction.updatePeerChatListInclusion(peerId, inclusion: .ifHasMessagesOrOneOf(groupId: .root, pinningIndex: nil, minTimestamp: timestamp))
            self.prepareLocalHistory(transaction: transaction, peerId: peerId)
            if let messageId = ids[randomId] {
                return transaction.getMessage(messageId)
            }
            return nil
        }
        |> mapToSignal { message -> Signal<Message?, NoError> in
            if let message {
                self.prefetchGiftFiles(account: account, message: message)
            }
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
    
    public static func insertIncomingGift(account: Account, peerId: PeerId, text: String?, notify: Bool) -> Signal<Message?, NoError> {
        guard self.isSimulatedPeer(peerId) else {
            return .single(nil)
        }
        let caption = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        return self.resolveSavedGift(account: account, sourcePeerId: self.current(for: peerId)?.sourcePeerId)
        |> mapToSignal { saved -> Signal<Message?, NoError> in
            guard let saved else {
                return .single(nil)
            }
            let media = self.media(
                for: saved.gift,
                text: (caption?.isEmpty == false) ? caption : saved.text,
                entities: (caption?.isEmpty == false) ? [] : saved.entities,
                nameHidden: saved.nameHidden,
                savedToProfile: saved.savedToProfile,
                convertStars: saved.convertStars,
                canUpgrade: saved.canUpgrade,
                upgradeStars: saved.upgradeStars,
                includeUpgrade: saved.upgradeStars != nil,
                isRefunded: saved.isRefunded,
                canExportDate: saved.canExportDate,
                transferStars: saved.transferStars,
                canTransferDate: saved.canTransferDate,
                canResaleDate: saved.canResaleDate,
                dropOriginalDetailsStars: saved.dropOriginalDetailsStars,
                number: saved.number,
                canCraftAt: saved.canCraftAt,
                senderId: peerId,
                toPeerId: account.peerId
            )
            return self.insertLocalMessage(account: account, peerId: peerId, text: "", media: [media], incoming: true, notify: notify)
        }
    }
    
    public static func insertGiftMessage(account: Account, peerId: PeerId, gift: StarGift, text: String?, entities: [MessageTextEntity]?, incoming: Bool, nameHidden: Bool, includeUpgrade: Bool, notify: Bool) -> Signal<Message?, NoError> {
        guard self.isSimulatedPeer(peerId) else {
            return .single(nil)
        }
        let senderId = incoming ? peerId : account.peerId
        let toPeerId = incoming ? account.peerId : peerId
        var resolvedCanUpgrade = includeUpgrade
        var resolvedUpgradeStars: Int64?
        var resolvedConvertStars: Int64?
        if case let .generic(generic) = gift {
            resolvedConvertStars = generic.convertStars
            if includeUpgrade {
                resolvedUpgradeStars = generic.upgradeStars
                resolvedCanUpgrade = generic.upgradeStars != nil
            } else {
                resolvedCanUpgrade = false
            }
        }
        let media = self.media(
            for: gift,
            text: text,
            entities: entities,
            nameHidden: nameHidden,
            savedToProfile: false,
            convertStars: resolvedConvertStars,
            canUpgrade: resolvedCanUpgrade,
            upgradeStars: resolvedUpgradeStars,
            includeUpgrade: includeUpgrade,
            isRefunded: false,
            canExportDate: nil,
            transferStars: nil,
            canTransferDate: nil,
            canResaleDate: nil,
            dropOriginalDetailsStars: nil,
            number: nil,
            canCraftAt: nil,
            senderId: senderId,
            toPeerId: toPeerId
        )
        return self.insertLocalMessage(account: account, peerId: peerId, text: "", media: [media], incoming: incoming, notify: notify)
    }
    
    private static func media(for gift: StarGift, text: String?, entities: [MessageTextEntity]?, nameHidden: Bool, savedToProfile: Bool, convertStars: Int64?, canUpgrade: Bool, upgradeStars: Int64?, includeUpgrade: Bool, isRefunded: Bool, canExportDate: Int32?, transferStars: Int64?, canTransferDate: Int32?, canResaleDate: Int32?, dropOriginalDetailsStars: Int64?, number: Int32?, canCraftAt: Int32?, senderId: PeerId, toPeerId: PeerId) -> TelegramMediaAction {
        switch gift {
        case let .generic(generic):
            let resolvedUpgradeStars = includeUpgrade ? (upgradeStars ?? generic.upgradeStars) : upgradeStars
            return TelegramMediaAction(action: .starGift(
                gift: gift,
                convertStars: convertStars ?? generic.convertStars,
                text: text,
                entities: text == nil ? nil : (entities ?? []),
                nameHidden: nameHidden,
                savedToProfile: savedToProfile,
                converted: false,
                upgraded: false,
                canUpgrade: canUpgrade,
                upgradeStars: resolvedUpgradeStars,
                isRefunded: isRefunded,
                isPrepaidUpgrade: false,
                upgradeMessageId: nil,
                peerId: nil,
                senderId: senderId,
                savedId: nil,
                prepaidUpgradeHash: nil,
                giftMessageId: nil,
                upgradeSeparate: false,
                isAuctionAcquired: false,
                toPeerId: toPeerId,
                number: number
            ))
        case .unique:
            return TelegramMediaAction(action: .starGiftUnique(
                gift: gift,
                isUpgrade: false,
                isTransferred: false,
                savedToProfile: savedToProfile,
                canExportDate: canExportDate,
                transferStars: transferStars,
                isRefunded: isRefunded,
                isPrepaidUpgrade: false,
                peerId: nil,
                senderId: senderId,
                savedId: nil,
                resaleAmount: nil,
                canTransferDate: canTransferDate,
                canResaleDate: canResaleDate,
                dropOriginalDetailsStars: dropOriginalDetailsStars,
                assigned: false,
                fromOffer: false,
                canCraftAt: canCraftAt,
                isCrafted: false
            ))
        }
    }
    
    private static func resolveSavedGift(account: Account, sourcePeerId: PeerId?) -> Signal<ProfileGiftsContext.State.StarGift?, NoError> {
        let profile: Signal<[ProfileGiftsContext.State.StarGift], NoError>
        if let sourcePeerId {
            profile = self.profileSavedGifts(account: account, peerId: sourcePeerId)
        } else {
            profile = .single([])
        }
        return profile
        |> mapToSignal { gifts -> Signal<ProfileGiftsContext.State.StarGift?, NoError> in
            if let gift = gifts.first {
                return .single(gift)
            }
            return self.catalogGifts(account: account)
            |> map { list in
                return list.first.map { self.savedGift(from: $0) }
            }
        }
    }
    
    private static func catalogGifts(account: Account) -> Signal<[StarGift], NoError> {
        let engine = TelegramEngine(account: account)
        return Signal { subscriber in
            let keepDisposable = engine.payments.keepStarGiftsUpdated().start()
            let disposable = (engine.payments.cachedStarGifts()
            |> map { list -> [StarGift] in
                return list ?? []
            }
            |> filter { !$0.isEmpty }
            |> take(1)
            |> timeout(8.0, queue: Queue.mainQueue(), alternate: engine.payments.cachedStarGifts() |> take(1) |> map { $0 ?? [] })).start(next: { gifts in
                subscriber.putNext(gifts)
                subscriber.putCompletion()
            })
            return ActionDisposable {
                keepDisposable.dispose()
                disposable.dispose()
            }
        }
    }
    
    private static func savedGift(from gift: StarGift) -> ProfileGiftsContext.State.StarGift {
        var convertStars: Int64?
        var canUpgrade = false
        var upgradeStars: Int64?
        if case let .generic(generic) = gift {
            convertStars = generic.convertStars
            canUpgrade = generic.upgradeStars != nil
            upgradeStars = generic.upgradeStars
        }
        return ProfileGiftsContext.State.StarGift(
            gift: gift,
            reference: nil,
            fromPeer: nil,
            date: Int32(Date().timeIntervalSince1970),
            text: nil,
            entities: nil,
            nameHidden: false,
            savedToProfile: true,
            pinnedToTop: false,
            convertStars: convertStars,
            canUpgrade: canUpgrade,
            canExportDate: nil,
            upgradeStars: upgradeStars,
            transferStars: nil,
            canTransferDate: nil,
            canResaleDate: nil,
            collectionIds: nil,
            prepaidUpgradeHash: nil,
            upgradeSeparate: false,
            dropOriginalDetailsStars: nil,
            number: nil,
            isRefunded: false,
            canCraftAt: nil
        )
    }
    
    private static func profileSavedGifts(account: Account, peerId: PeerId) -> Signal<[ProfileGiftsContext.State.StarGift], NoError> {
        return Signal { subscriber in
            let context = ProfileGiftsContext(account: account, peerId: peerId, filter: ProfileGiftsContext.Filters.All.subtracting(.hidden), limit: 8)
            let disposable = (context.state
            |> filter { state in
                if case .loading = state.dataState, state.gifts.isEmpty {
                    return false
                }
                return true
            }
            |> take(1)
            |> map { state in
                return state.gifts
            }
            |> timeout(8.0, queue: Queue.mainQueue(), alternate: .single([]))).start(next: { gifts in
                subscriber.putNext(gifts)
                subscriber.putCompletion()
            })
            return ActionDisposable {
                disposable.dispose()
                let _ = context
            }
        }
    }
    
    private static func prefetchGiftFiles(account: Account, message: Message) {
        var files: [TelegramMediaFile] = []
        for media in message.media {
            guard let action = media as? TelegramMediaAction else {
                continue
            }
            switch action.action {
            case let .starGift(gift, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _):
                files.append(contentsOf: self.animationFiles(for: gift))
            case let .starGiftUnique(gift, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _):
                files.append(contentsOf: self.animationFiles(for: gift))
            default:
                break
            }
        }
        for file in files {
            let _ = fetchedMediaResource(
                mediaBox: account.postbox.mediaBox,
                userLocation: .other,
                userContentType: .sticker,
                reference: FileMediaReference.forGiftFile(file, message: message).resourceReference(file.resource)
            ).start()
        }
    }
    
    private static func animationFiles(for gift: StarGift) -> [TelegramMediaFile] {
        switch gift {
        case let .generic(generic):
            return [generic.file]
        case let .unique(unique):
            var files: [TelegramMediaFile] = []
            for attribute in unique.attributes {
                switch attribute {
                case let .model(_, file, _, _):
                    files.append(file)
                case let .pattern(_, file, _):
                    files.append(file)
                default:
                    break
                }
            }
            return files
        }
    }
    
    public static func prepareLocalHistory(transaction: Transaction, peerId: PeerId) {
        for namespace in [Namespaces.Message.Cloud, Namespaces.Message.Local] {
            transaction.removeHole(peerId: peerId, threadId: nil, namespace: namespace, space: .everywhere, range: 1 ... (Int32.max - 1))
        }
    }
    
    public static func highestStoredMessageId(transaction: Transaction, peerId: PeerId) -> Int32 {
        var maxId: Int32 = 0
        transaction.withAllMessages(peerId: peerId, namespace: Namespaces.Message.Local) { message in
            maxId = max(maxId, message.id.id)
            return true
        }
        transaction.withAllMessages(peerId: peerId, namespace: Namespaces.Message.Cloud) { message in
            maxId = max(maxId, message.id.id)
            return true
        }
        return maxId
    }
    
    public static func uniqueLocalStoreMessage(transaction: Transaction, peerId: PeerId, nextId: inout Int32, globallyUniqueId: Int64?, groupingKey: Int64?, threadId: Int64?, timestamp: Int32, flags: StoreMessageFlags, tags: MessageTags, globalTags: GlobalMessageTags, localTags: LocalMessageTags, forwardInfo: StoreMessageForwardInfo?, authorId: PeerId?, text: String, attributes: [MessageAttribute], media: [Media]) -> StoreMessage {
        if nextId <= 0 {
            nextId = self.highestStoredMessageId(transaction: transaction, peerId: peerId) + 1
        }
        var resolvedTimestamp = timestamp
        if let top = transaction.getTopPeerMessageIndex(peerId: peerId) {
            resolvedTimestamp = max(resolvedTimestamp, top.timestamp)
        }
        let messageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Local, id: nextId)
        nextId += 1
        return StoreMessage(id: messageId, customStableId: nil, globallyUniqueId: globallyUniqueId, groupingKey: groupingKey, threadId: threadId, timestamp: resolvedTimestamp, flags: flags, tags: tags, globalTags: globalTags, localTags: localTags, forwardInfo: forwardInfo, authorId: authorId, text: text, attributes: attributes, media: media)
    }
}
