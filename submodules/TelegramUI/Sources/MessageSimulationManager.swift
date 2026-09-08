import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramUIPreferences
import AccountContext

final class MessageSimulationManager {
    private let context: AccountContext
    private let disposable = DisposableSet()
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
            return entry?.get(MessageSimulationSettings.self) ?? .defaultSettings
        }
        |> distinctUntilChanged
        
        self.disposable.add((settings
        |> mapToSignal { settings -> Signal<MessageSimulationOverlayState?, NoError> in
            let normalized = ProfileSpoofingManager.normalizedTarget(settings.target)
            let restored = MessageSimulationManager.restoredState(account: account, settings: settings)
            if !settings.isEnabled || normalized.isEmpty {
                return restored
            }
            let live = (settings.sourcePeerId == nil ? (Signal<Void, NoError>.single(Void()) |> delay(0.4, queue: Queue.mainQueue())) : Signal<Void, NoError>.single(Void()))
            |> mapToSignal { _ in
                return MessageSimulationManager.resolvePeer(context: context, target: normalized)
            }
            |> mapToSignal { peer -> Signal<MessageSimulationOverlayState?, NoError> in
                guard let peer, case let .user(user) = peer, user.id != account.peerId else {
                    return .single(nil)
                }
                let simulatedId = settings.simulatedPeerId.flatMap(PeerId.init) ?? MessageSimulationOverlay.syntheticPeerId(for: user.id)
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
        })
        |> mapToSignal { [weak self] state -> Signal<Never, NoError> in
            if let previous = self?.lastSimulatedPeerId, previous != state?.simulatedPeerId {
                MessageSimulationOverlay.set(nil, for: previous)
            }
            self?.lastSimulatedPeerId = state?.simulatedPeerId
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
        if let lastSimulatedPeerId = self.lastSimulatedPeerId {
            MessageSimulationOverlay.set(nil, for: lastSimulatedPeerId)
        }
    }
    
    private func handleUnsent(_ ids: Set<MessageId>) {
        let account = self.context.account
        for id in ids {
            if self.processedOutgoingIds.contains(id) || self.inFlightOutgoingIds.contains(id) {
                continue
            }
            self.inFlightOutgoingIds.insert(id)
            let peerId = id.peerId
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
            |> then(
                account.postbox.transaction { transaction -> (String, Bool) in
                    if let message = transaction.getMessage(id) {
                        let hasMedia = message.media.contains(where: { $0 is TelegramMediaImage || $0 is TelegramMediaFile })
                        return (message.text, hasMedia)
                    }
                    return ("", false)
                }
                |> delay(0.3, queue: Queue.mainQueue())
                |> mapToSignal { text, hasMedia -> Signal<Never, NoError> in
                    account.addSimulatedPeerInputActivity(chatPeerId: peerId, peerId: peerId, activity: .typingText)
                    let replyText = MessageSimulationOverlay.simulatedReplyText(to: text, hasMedia: hasMedia)
                    let typingDelay = min(2.4, 0.8 + Double(replyText.count) * 0.04)
                    return Signal<Void, NoError>.single(Void())
                    |> delay(typingDelay, queue: Queue.mainQueue())
                    |> mapToSignal { _ in
                        return MessageSimulationOverlay.insertIncomingMessage(account: account, peerId: peerId, text: replyText, media: [], notify: true)
                        |> ignoreValues
                    }
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
