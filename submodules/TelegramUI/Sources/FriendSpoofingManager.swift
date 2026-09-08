import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramUIPreferences
import AccountContext

final class FriendSpoofingManager {
    private let context: AccountContext
    private let disposable = DisposableSet()
    private var lastTargetPeerId: PeerId?
    
    init(context: AccountContext) {
        self.context = context
        
        let engine = context.engine
        let account = context.account
        let accountPeerId = account.peerId
        
        let settings = engine.data.subscribe(
            TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: ApplicationSpecificPreferencesKeys.friendSpoofingSettings)
        )
        |> map { entry -> FriendSpoofingSettings in
            return entry?.get(FriendSpoofingSettings.self) ?? .defaultSettings
        }
        |> distinctUntilChanged
        
        self.disposable.add((settings
        |> mapToSignal { settings -> Signal<(PeerId, FriendSpoofingOverlayState?)?, NoError> in
            let target = ProfileSpoofingManager.normalizedTarget(settings.target)
            let source = ProfileSpoofingManager.normalizedTarget(settings.source)
            if !settings.isEnabled || target.isEmpty || source.isEmpty {
                if settings.targetPeerId != nil || settings.sourcePeerId != nil {
                    let _ = updateFriendSpoofingSettings(engine: engine, { current in
                        var next = current
                        next.targetPeerId = nil
                        next.sourcePeerId = nil
                        return next
                    }).start()
                }
                return .single(nil)
            }
            let restored = FriendSpoofingManager.restoredState(account: account, settings: settings)
            let live = (settings.targetPeerId == nil || settings.sourcePeerId == nil ? (Signal<Void, NoError>.single(Void()) |> delay(0.4, queue: Queue.mainQueue())) : Signal<Void, NoError>.single(Void()))
            |> mapToSignal { _ in
                return combineLatest(
                    FriendSpoofingManager.resolvePeer(context: context, target: target),
                    FriendSpoofingManager.resolvePeer(context: context, target: source)
                )
            }
            |> mapToSignal { targetPeer, sourcePeer -> Signal<(PeerId, FriendSpoofingOverlayState?)?, NoError> in
                guard let targetPeer, case let .user(targetUser) = targetPeer, targetUser.id != accountPeerId, !MessageSimulationOverlay.isSimulatedPeer(targetUser.id) else {
                    return .single(nil)
                }
                guard let sourcePeer, case let .user(sourceUser) = sourcePeer, sourceUser.id != targetUser.id, !MessageSimulationOverlay.isSimulatedPeer(sourceUser.id) else {
                    return .single(nil)
                }
                let targetId = targetUser.id
                return account.viewTracker.peerView(sourceUser.id, updateData: true)
                |> map { view -> (PeerId, FriendSpoofingOverlayState?)? in
                    let source = (view.peers[sourceUser.id] as? TelegramUser) ?? sourceUser
                    let state = FriendSpoofingOverlayState(targetPeerId: targetId, sourcePeerId: source.id, sourceUser: source, sourceCachedData: view.cachedData as? CachedUserData)
                    return (targetId, state)
                }
            }
            return restored
            |> mapToSignal { cached -> Signal<(PeerId, FriendSpoofingOverlayState?)?, NoError> in
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
                if lhsState.sourcePeerId != rhsState.sourcePeerId {
                    return false
                }
                if lhsState.sourceUser != rhsState.sourceUser {
                    return false
                }
                if lhsState.sourceCachedData?.about != rhsState.sourceCachedData?.about {
                    return false
                }
                if lhsState.sourceCachedData?.starGiftsCount != rhsState.sourceCachedData?.starGiftsCount {
                    return false
                }
                if lhsState.sourceCachedData?.verification != rhsState.sourceCachedData?.verification {
                    return false
                }
                if lhsState.sourceCachedData?.starRating != rhsState.sourceCachedData?.starRating {
                    return false
                }
                if lhsState.sourceCachedData?.personalChannel != rhsState.sourceCachedData?.personalChannel {
                    return false
                }
                return true
            default:
                return false
            }
        })
        |> mapToSignal { [weak self] value -> Signal<Never, NoError> in
            let previousTargetId = self?.lastTargetPeerId
            let targetId = value?.0
            let state = value?.1
            self?.lastTargetPeerId = targetId
            if previousTargetId != targetId, let previousTargetId {
                FriendSpoofingOverlay.set(nil, for: previousTargetId)
            }
            let restorePrevious: Signal<Never, NoError>
            if previousTargetId != targetId, let previousTargetId {
                restorePrevious = account.viewTracker.peerView(previousTargetId, updateData: true) |> take(1) |> ignoreValues
            } else {
                restorePrevious = .complete()
            }
            if let targetId, let state {
                let existing = FriendSpoofingOverlay.current(for: targetId)
                FriendSpoofingOverlay.set(state, for: targetId)
                if existing?.sourcePeerId != state.sourcePeerId {
                    let targetRaw = targetId.toInt64()
                    let sourceRaw = state.sourcePeerId.toInt64()
                    let _ = updateFriendSpoofingSettings(engine: engine, { current in
                        var next = current
                        if next.targetPeerId != targetRaw || next.sourcePeerId != sourceRaw {
                            next.targetPeerId = targetRaw
                            next.sourcePeerId = sourceRaw
                        }
                        return next
                    }).start()
                }
                return restorePrevious
            } else {
                return restorePrevious
            }
        }).start())
    }
    
    deinit {
        self.disposable.dispose()
        if let lastTargetPeerId = self.lastTargetPeerId {
            FriendSpoofingOverlay.set(nil, for: lastTargetPeerId, persist: false)
        }
    }
    
    private static func restoredState(account: Account, settings: FriendSpoofingSettings) -> Signal<(PeerId, FriendSpoofingOverlayState?)?, NoError> {
        guard let targetRaw = settings.targetPeerId, let sourceRaw = settings.sourcePeerId else {
            return .single(nil)
        }
        let targetId = PeerId(targetRaw)
        let sourceId = PeerId(sourceRaw)
        return account.postbox.transaction { transaction -> (PeerId, FriendSpoofingOverlayState?)? in
            guard let source = transaction.getPeer(sourceId) as? TelegramUser else {
                return nil
            }
            let cached = transaction.getPeerCachedData(peerId: sourceId) as? CachedUserData
            let state = FriendSpoofingOverlayState(targetPeerId: targetId, sourcePeerId: sourceId, sourceUser: source, sourceCachedData: cached)
            return (targetId, state)
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
