import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramUIPreferences
import AccountContext

final class MessageSimulationManager {
    private let context: AccountContext
    private let disposable = DisposableSet()
    private let overlayContentDisposable = MetaDisposable()
    private let giftArtworkDisposable = MetaDisposable()
    private var overlayGiftsContext: ProfileGiftsContext?
    private var overlayMusicContext: ProfileSavedMusicContext?
    private var lastSimulatedPeerId: PeerId?
    private var processedOutgoingIds = Set<MessageId>()
    private var inFlightOutgoingIds = Set<MessageId>()
    
    init(context: AccountContext) {
        self.context = context
        
        let engine = context.engine
        let account = context.account
        
        let settings = engine.data.subscribe(
            TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: ApplicationSpecificPreferencesKeys.messageSimulationSettings)
        )
        |> map { entry -> MessageSimulationSettings in
            return MessageSimulationSettings.fromPreference(entry)
        }
        |> distinctUntilChanged
        
        self.disposable.add((settings
        |> mapToSignal { settings -> Signal<MessageSimulationOverlayState?, NoError> in
            let normalized = ProfileSpoofingManager.normalizedTarget(settings.target)
            if !settings.isEnabled || normalized.isEmpty {
                return .single(nil)
            }
            let restored = MessageSimulationManager.restoredState(account: account, settings: settings)
            let live = (settings.sourcePeerId == nil ? (Signal<Void, NoError>.single(Void()) |> delay(0.4, queue: Queue.mainQueue())) : Signal<Void, NoError>.single(Void()))
            |> mapToSignal { _ in
                return MessageSimulationManager.resolvePeer(context: context, target: normalized)
            }
            |> mapToSignal { peer -> Signal<MessageSimulationOverlayState?, NoError> in
                guard let peer, case let .user(user) = peer, user.id != account.peerId else {
                    return .single(nil)
                }
                let simulatedId = MessageSimulationOverlay.syntheticPeerId(for: user.id)
                return account.viewTracker.peerView(user.id, updateData: true)
                |> map { view -> MessageSimulationOverlayState? in
                    let source = (view.peers[user.id] as? TelegramUser) ?? user
                    return MessageSimulationOverlayState(simulatedPeerId: simulatedId, sourcePeerId: source.id, sourceUser: source, sourceCachedData: view.cachedData as? CachedUserData)
                }
            }
            return restored
            |> mapToSignal { cached -> Signal<MessageSimulationOverlayState?, NoError> in
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
            if lhs.simulatedPeerId != rhs.simulatedPeerId || lhs.sourcePeerId != rhs.sourcePeerId {
                return false
            }
            if lhs.sourceUser != rhs.sourceUser {
                return false
            }
            return lhs.sourceCachedData?.about == rhs.sourceCachedData?.about
                && lhs.sourceCachedData?.starGiftsCount == rhs.sourceCachedData?.starGiftsCount
                && lhs.sourceCachedData?.verification == rhs.sourceCachedData?.verification
                && lhs.sourceCachedData?.starRating == rhs.sourceCachedData?.starRating
                && lhs.sourceCachedData?.pendingStarRating == rhs.sourceCachedData?.pendingStarRating
                && lhs.sourceCachedData?.personalChannel == rhs.sourceCachedData?.personalChannel
                && lhs.sourceCachedData?.savedMusic == rhs.sourceCachedData?.savedMusic
        })
        |> mapToSignal { [weak self] state -> Signal<Never, NoError> in
            if let previous = self?.lastSimulatedPeerId, previous != state?.simulatedPeerId {
                MessageSimulationOverlay.set(nil, for: previous, persist: state != nil)
            }
            self?.lastSimulatedPeerId = state?.simulatedPeerId
            self?.applyOverlayProfileContent(sourceId: state?.sourcePeerId)
            if let state {
                MessageSimulationOverlay.set(state, for: state.simulatedPeerId)
                let simulatedRaw = state.simulatedPeerId.toInt64()
                let sourceRaw = state.sourcePeerId.toInt64()
                let _ = updateMessageSimulationSettings(engine: engine, { current in
                    var next = current
                    if next.simulatedPeerId != simulatedRaw || next.sourcePeerId != sourceRaw {
                        next.simulatedPeerId = simulatedRaw
                        next.sourcePeerId = sourceRaw
                    }
                    return next
                }).start()
                return MessageSimulationOverlay.applyToPostbox(account: account, simulatedPeerId: state.simulatedPeerId)
            } else {
                return .complete()
            }
        }).start())
        
        self.disposable.add((account.postbox.unsentMessageIdsView()
        |> map { view in
            return view.ids.filter { MessageSimulationOverlay.isSimulatedPeer($0.peerId) }
        }
        |> distinctUntilChanged
        |> deliverOnMainQueue).start(next: { [weak self] ids in
            self?.handleUnsent(ids)
        }))
    }
    
    deinit {
        self.disposable.dispose()
        self.overlayContentDisposable.dispose()
        self.giftArtworkDisposable.dispose()
        if let lastSimulatedPeerId = self.lastSimulatedPeerId {
            MessageSimulationOverlay.set(nil, for: lastSimulatedPeerId, persist: false)
        }
    }
    
    private func applyOverlayProfileContent(sourceId: PeerId?) {
        guard let sourceId else {
            self.overlayGiftsContext = nil
            self.overlayMusicContext = nil
            self.overlayContentDisposable.set(nil)
            self.giftArtworkDisposable.set(nil)
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
        self.giftArtworkDisposable.set(prepareStarGiftArtwork(account: self.context.account, gifts: gifts.prefix(8).map(\.gift)))
    }
    
    private func handleUnsent(_ ids: Set<MessageId>) {
        let account = self.context.account
        for id in ids {
            if self.processedOutgoingIds.contains(id) || self.inFlightOutgoingIds.contains(id) {
                continue
            }
            self.inFlightOutgoingIds.insert(id)
            let pipeline = Signal<Void, NoError>.single(Void())
            |> delay(0.35, queue: Queue.mainQueue())
            |> mapToSignal { _ in
                return MessageSimulationOverlay.markOutgoingDelivered(account: account, messageId: id)
            }
            |> then(
                Signal<Void, NoError>.single(Void())
                |> delay(0.5, queue: Queue.mainQueue())
                |> mapToSignal { _ in
                    return MessageSimulationOverlay.markOutgoingRead(account: account, messageId: id)
                }
            )
            self.disposable.add(pipeline.start(completed: { [weak self] in
                self?.processedOutgoingIds.insert(id)
                self?.inFlightOutgoingIds.remove(id)
            }))
        }
    }
    
    private static func restoredState(account: Account, settings: MessageSimulationSettings) -> Signal<MessageSimulationOverlayState?, NoError> {
        guard let sourceRaw = settings.sourcePeerId, let simulatedRaw = settings.simulatedPeerId else {
            return .single(nil)
        }
        let sourceId = PeerId(sourceRaw)
        let simulatedId = PeerId(simulatedRaw)
        return account.postbox.transaction { transaction -> MessageSimulationOverlayState? in
            guard let user = transaction.getPeer(sourceId) as? TelegramUser else {
                return nil
            }
            return MessageSimulationOverlayState(simulatedPeerId: simulatedId, sourcePeerId: sourceId, sourceUser: user, sourceCachedData: transaction.getPeerCachedData(peerId: sourceId) as? CachedUserData)
        }
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
