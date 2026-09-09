import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramUIPreferences
import AccountContext

final class ProfileSpoofingManager {
    private let context: AccountContext
    private let disposable = DisposableSet()
    private let sourceHistoryDisposable = MetaDisposable()
    private let overlayContentDisposable = MetaDisposable()
    private var overlayGiftsContext: ProfileGiftsContext?
    private var overlayMusicContext: ProfileSavedMusicContext?
    private var lastOwnedChannelId: PeerId?
    
    init(context: AccountContext) {
        self.context = context
        
        let engine = context.engine
        let account = context.account
        let accountPeerId = account.peerId
        
        let settings = engine.data.subscribe(
            TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: ApplicationSpecificPreferencesKeys.profileSpoofingSettings)
        )
        |> map { entry -> ProfileSpoofingSettings in
            return ProfileSpoofingSettings.fromPreference(entry)
        }
        |> distinctUntilChanged
        
        self.disposable.add((settings
        |> mapToSignal { settings -> Signal<ProfileSpoofingOverlayState?, NoError> in
            let normalized = ProfileSpoofingManager.normalizedTarget(settings.target)
            if !settings.isEnabled || normalized.isEmpty {
                return .single(nil)
            }
            let restored = ProfileSpoofingManager.restoredProfileState(account: account, settings: settings)
            let live = (settings.targetPeerId == nil ? (Signal<Void, NoError>.single(Void()) |> delay(0.4, queue: Queue.mainQueue())) : Signal<Void, NoError>.single(Void()))
            |> mapToSignal { _ in
                return ProfileSpoofingManager.resolvePeer(context: context, target: normalized)
            }
            |> mapToSignal { peer -> Signal<ProfileSpoofingOverlayState?, NoError> in
                guard let peer, case let .user(user) = peer, user.id != accountPeerId else {
                    return .single(nil)
                }
                return account.viewTracker.peerView(user.id, updateData: true)
                |> map { view -> ProfileSpoofingOverlayState? in
                    guard let targetUser = view.peers[user.id] as? TelegramUser else {
                        return ProfileSpoofingOverlayState(targetPeerId: user.id, targetUser: user, targetCachedData: nil)
                    }
                    return ProfileSpoofingOverlayState(targetPeerId: targetUser.id, targetUser: targetUser, targetCachedData: view.cachedData as? CachedUserData)
                }
            }
            return restored
            |> mapToSignal { cached -> Signal<ProfileSpoofingOverlayState?, NoError> in
                if let cached {
                    return .single(cached) |> then(live)
                }
                return live
            }
        }
        |> distinctUntilChanged(isEqual: { lhs, rhs in
            guard let lhs, let rhs else {
                return lhs == nil && rhs == nil
            }
            if lhs === rhs {
                return true
            }
            if lhs.targetPeerId != rhs.targetPeerId {
                return false
            }
            if lhs.targetUser != rhs.targetUser {
                return false
            }
            let lhsCached = lhs.targetCachedData
            let rhsCached = rhs.targetCachedData
            if lhsCached?.about != rhsCached?.about {
                return false
            }
            if lhsCached?.starGiftsCount != rhsCached?.starGiftsCount {
                return false
            }
            if lhsCached?.verification != rhsCached?.verification {
                return false
            }
            if lhsCached?.starRating != rhsCached?.starRating {
                return false
            }
            if lhsCached?.pendingStarRating != rhsCached?.pendingStarRating {
                return false
            }
            if lhsCached?.personalChannel != rhsCached?.personalChannel {
                return false
            }
            if lhsCached?.savedMusic != rhsCached?.savedMusic {
                return false
            }
            return true
        })
        |> mapToSignal { [weak self] state -> Signal<Never, NoError> in
            let previous = ProfileSpoofingOverlay.current(for: accountPeerId)
            ProfileSpoofingOverlay.set(state, for: accountPeerId, persist: state != nil)
            self?.applyOverlayProfileContent(sourceId: state?.targetPeerId)
            if let state, previous?.targetPeerId != state.targetPeerId {
                let storedId = state.targetPeerId.toInt64()
                let _ = updateProfileSpoofingSettings(engine: engine, { current in
                    var next = current
                    if next.targetPeerId != storedId {
                        next.targetPeerId = storedId
                    }
                    return next
                }).start()
            }
            if state == nil && previous == nil {
                return .complete()
            }
            if state == nil {
                return account.viewTracker.peerView(accountPeerId, updateData: true) |> take(1) |> ignoreValues
            }
            return .complete()
        }).start())
        
        self.disposable.add((settings
        |> mapToSignal { [weak self] settings -> Signal<(PeerId, ChannelSpoofingOverlayState?)?, NoError> in
            let myChannel = ProfileSpoofingManager.normalizedTarget(settings.myChannel)
            let spoofAs = ProfileSpoofingManager.normalizedTarget(settings.spoofChannelAs)
            if !settings.channelSpoofingEnabled || myChannel.isEmpty || spoofAs.isEmpty {
                self?.sourceHistoryDisposable.set(nil)
                return .single(nil)
            }
            if let ownedRaw = settings.ownedChannelPeerId, let sourceRaw = settings.sourceChannelPeerId {
                ChannelSpoofingOverlay.persistMapping(ownedChannelId: PeerId(ownedRaw), sourceChannelId: PeerId(sourceRaw))
            }
            let restored = ProfileSpoofingManager.restoredChannelState(account: account, settings: settings)
            let live = (settings.ownedChannelPeerId == nil || settings.sourceChannelPeerId == nil ? (Signal<Void, NoError>.single(Void()) |> delay(0.4, queue: Queue.mainQueue())) : Signal<Void, NoError>.single(Void()))
            |> mapToSignal { _ in
                return combineLatest(
                    ProfileSpoofingManager.resolveChannel(context: context, target: myChannel),
                    ProfileSpoofingManager.resolveChannel(context: context, target: spoofAs)
                )
            }
            |> mapToSignal { ownedPeer, sourcePeer -> Signal<(PeerId, ChannelSpoofingOverlayState?)?, NoError> in
                guard let ownedPeer, case let .channel(ownedChannel) = ownedPeer else {
                    return .single(nil)
                }
                guard let sourcePeer, case let .channel(sourceChannel) = sourcePeer, sourceChannel.id != ownedChannel.id else {
                    return .single(nil)
                }
                let ownedId = ownedChannel.id
                return account.viewTracker.peerView(sourceChannel.id, updateData: true)
                |> map { view -> (PeerId, ChannelSpoofingOverlayState?)? in
                    let source = (view.peers[sourceChannel.id] as? TelegramChannel) ?? sourceChannel
                    let state = ChannelSpoofingOverlayState(ownedChannelId: ownedId, sourceChannelId: source.id, sourceChannel: source, sourceCachedData: view.cachedData as? CachedChannelData)
                    return (ownedId, state)
                }
            }
            return restored
            |> mapToSignal { cached -> Signal<(PeerId, ChannelSpoofingOverlayState?)?, NoError> in
                if let cached {
                    return .single(cached) |> then(live)
                }
                return live
            }
        }
        |> distinctUntilChanged(isEqual: { lhs, rhs in
            switch (lhs, rhs) {
            case (nil, nil):
                return true
            case let (lhs?, rhs?):
                if lhs.0 != rhs.0 {
                    return false
                }
                guard let lhsState = lhs.1, let rhsState = rhs.1 else {
                    return lhs.1 == nil && rhs.1 == nil
                }
                if lhsState.sourceChannelId != rhsState.sourceChannelId {
                    return false
                }
                if lhsState.sourceChannel != rhsState.sourceChannel {
                    return false
                }
                if lhsState.sourceCachedData?.about != rhsState.sourceCachedData?.about {
                    return false
                }
                if lhsState.sourceCachedData?.participantsSummary.memberCount != rhsState.sourceCachedData?.participantsSummary.memberCount {
                    return false
                }
                if lhsState.sourceCachedData?.starGiftsCount != rhsState.sourceCachedData?.starGiftsCount {
                    return false
                }
                if lhsState.sourceCachedData?.verification != rhsState.sourceCachedData?.verification {
                    return false
                }
                return true
            default:
                return false
            }
        })
        |> mapToSignal { [weak self] value -> Signal<Never, NoError> in
            let previousOwnedId = self?.lastOwnedChannelId
            let ownedId = value?.0
            let state = value?.1
            if previousOwnedId != ownedId, let previousOwnedId {
                ChannelSpoofingOverlay.set(nil, for: previousOwnedId, persist: ownedId != nil)
            }
            self?.lastOwnedChannelId = ownedId
            if let ownedId, let state {
                let existing = ChannelSpoofingOverlay.current(for: ownedId)
                ChannelSpoofingOverlay.set(state, for: ownedId)
                self?.prefetchSourceHistory(sourceId: state.sourceChannelId)
                if existing?.sourceChannelId != state.sourceChannelId {
                    let ownedRaw = ownedId.toInt64()
                    let sourceRaw = state.sourceChannelId.toInt64()
                    let _ = updateProfileSpoofingSettings(engine: engine, { current in
                        var next = current
                        if next.ownedChannelPeerId != ownedRaw || next.sourceChannelPeerId != sourceRaw {
                            next.ownedChannelPeerId = ownedRaw
                            next.sourceChannelPeerId = sourceRaw
                        }
                        return next
                    }).start()
                }
                return .complete()
            } else if let previousOwnedId {
                self?.sourceHistoryDisposable.set(nil)
                ChannelSpoofingOverlay.set(nil, for: previousOwnedId, persist: false)
                return account.viewTracker.peerView(previousOwnedId, updateData: true) |> take(1) |> ignoreValues
            } else {
                self?.sourceHistoryDisposable.set(nil)
                return .complete()
            }
        }).start())
    }
    
    deinit {
        self.disposable.dispose()
        self.sourceHistoryDisposable.dispose()
        self.overlayContentDisposable.dispose()
        ProfileSpoofingOverlay.set(nil, for: self.context.account.peerId, persist: false)
        if let lastOwnedChannelId = self.lastOwnedChannelId {
            ChannelSpoofingOverlay.set(nil, for: lastOwnedChannelId, persist: false)
        }
    }
    
    private func applyOverlayProfileContent(sourceId: PeerId?) {
        guard let sourceId else {
            self.overlayGiftsContext = nil
            self.overlayMusicContext = nil
            self.overlayContentDisposable.set(nil)
            return
        }
        self.context.account.viewTracker.forceUpdateCachedPeerData(peerId: sourceId)
        let gifts = ProfileGiftsContext(account: self.context.account, peerId: sourceId, filter: ProfileGiftsContext.Filters.All.subtracting(.hidden), limit: 8)
        let music = ProfileSavedMusicContext(account: self.context.account, peerId: sourceId)
        self.overlayGiftsContext = gifts
        self.overlayMusicContext = music
        self.overlayContentDisposable.set((combineLatest(gifts.state, music.state)
        |> deliverOnMainQueue).start(next: { [weak self] giftState, _ in
            self?.prefetchGiftArtwork(giftState.gifts)
        }))
    }
    
    private func prefetchGiftArtwork(_ gifts: [ProfileGiftsContext.State.StarGift]) {
        for gift in gifts.prefix(6) {
            var files: [TelegramMediaFile] = []
            switch gift.gift {
            case let .generic(generic):
                files.append(generic.file)
            case let .unique(unique):
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
            }
            for file in files {
                let _ = fetchedMediaResource(
                    mediaBox: self.context.account.postbox.mediaBox,
                    userLocation: .other,
                    userContentType: .sticker,
                    reference: FileMediaReference.forGiftFile(file).resourceReference(file.resource)
                ).start()
            }
        }
    }
    
    private func prefetchSourceHistory(sourceId: PeerId) {
        self.sourceHistoryDisposable.set(self.context.account.viewTracker.aroundMessageHistoryViewForLocation(.peer(peerId: sourceId, threadId: nil), index: .upperBound, anchorIndex: .upperBound, count: 120, trackHoles: true, fixedCombinedReadStates: nil).start())
    }
    
    private static func restoredProfileState(account: Account, settings: ProfileSpoofingSettings) -> Signal<ProfileSpoofingOverlayState?, NoError> {
        guard let raw = settings.targetPeerId else {
            return .single(nil)
        }
        let peerId = PeerId(raw)
        return account.postbox.transaction { transaction -> ProfileSpoofingOverlayState? in
            guard let user = transaction.getPeer(peerId) as? TelegramUser else {
                return nil
            }
            return ProfileSpoofingOverlayState(targetPeerId: peerId, targetUser: user, targetCachedData: transaction.getPeerCachedData(peerId: peerId) as? CachedUserData)
        }
    }
    
    private static func restoredChannelState(account: Account, settings: ProfileSpoofingSettings) -> Signal<(PeerId, ChannelSpoofingOverlayState?)?, NoError> {
        guard let ownedRaw = settings.ownedChannelPeerId, let sourceRaw = settings.sourceChannelPeerId else {
            return .single(nil)
        }
        let ownedId = PeerId(ownedRaw)
        let sourceId = PeerId(sourceRaw)
        return account.postbox.transaction { transaction -> (PeerId, ChannelSpoofingOverlayState?)? in
            guard let source = transaction.getPeer(sourceId) as? TelegramChannel else {
                return nil
            }
            let cached = transaction.getPeerCachedData(peerId: sourceId) as? CachedChannelData
            let state = ChannelSpoofingOverlayState(ownedChannelId: ownedId, sourceChannelId: sourceId, sourceChannel: source, sourceCachedData: cached)
            return (ownedId, state)
        }
    }
    
    static func normalizedTarget(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("@") {
            value.removeFirst()
        }
        let lowered = value.lowercased()
        if lowered.hasPrefix("https://t.me/") {
            value = String(value.dropFirst("https://t.me/".count))
        } else if lowered.hasPrefix("http://t.me/") {
            value = String(value.dropFirst("http://t.me/".count))
        } else if lowered.hasPrefix("t.me/") {
            value = String(value.dropFirst("t.me/".count))
        }
        if let slash = value.firstIndex(of: "/") {
            value = String(value[..<slash])
        }
        if let query = value.firstIndex(of: "?") {
            value = String(value[..<query])
        }
        return value
    }
    
    private static func resolvePeer(context: AccountContext, target: String) -> Signal<EnginePeer?, NoError> {
        if let userId = Int64(target), userId > 0 {
            let peerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(userId))
            return context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
            |> mapToSignal { peer -> Signal<EnginePeer?, NoError> in
                if let peer {
                    return .single(peer)
                }
                return self.resolveByName(context: context, name: target)
            }
        }
        return self.resolveByName(context: context, name: target)
    }
    
    private static func resolveChannel(context: AccountContext, target: String) -> Signal<EnginePeer?, NoError> {
        if let channelId = self.parsedChannelId(target) {
            return context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: channelId))
            |> mapToSignal { peer -> Signal<EnginePeer?, NoError> in
                if let peer, case .channel = peer {
                    return .single(peer)
                }
                return self.resolveByName(context: context, name: target)
                |> map { resolved in
                    if case .channel = resolved {
                        return resolved
                    }
                    return peer
                }
            }
        }
        return self.resolveByName(context: context, name: target)
        |> map { peer -> EnginePeer? in
            if case .channel = peer {
                return peer
            }
            return nil
        }
    }
    
    private static func parsedChannelId(_ target: String) -> EnginePeer.Id? {
        if target.hasPrefix("-100"), let remainder = Int64(String(target.dropFirst(4))), remainder > 0 {
            return EnginePeer.Id(namespace: Namespaces.Peer.CloudChannel, id: EnginePeer.Id.Id._internalFromInt64Value(remainder))
        }
        if let value = Int64(target), value > 0 {
            return EnginePeer.Id(namespace: Namespaces.Peer.CloudChannel, id: EnginePeer.Id.Id._internalFromInt64Value(value))
        }
        return nil
    }
    
    private static func resolveByName(context: AccountContext, name: String) -> Signal<EnginePeer?, NoError> {
        return context.engine.peers.resolvePeerByName(name: name, referrer: nil)
        |> filter { result in
            if case .progress = result {
                return false
            } else {
                return true
            }
        }
        |> map { result -> EnginePeer? in
            switch result {
            case let .result(peer):
                return peer
            case .progress:
                return nil
            }
        }
    }
}
