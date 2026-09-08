import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramUIPreferences
import AccountContext

final class FriendSpoofingManager {
    private let context: AccountContext
    private let disposable = DisposableSet()
    private var lastTargetPeerIds: Set<PeerId> = []
    
    private struct ResolvedMapping {
        let targetQuery: String
        let sourceQuery: String
        let state: FriendSpoofingOverlayState
    }
    
    init(context: AccountContext) {
        self.context = context
        
        let engine = context.engine
        let account = context.account
        let accountPeerId = account.peerId
        
        let settings = engine.data.subscribe(
            TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: ApplicationSpecificPreferencesKeys.friendSpoofingSettings)
        )
        |> map { entry -> FriendSpoofingSettings in
            return FriendSpoofingSettings.fromPreference(entry)
        }
        |> distinctUntilChanged
        
        self.disposable.add((settings
        |> mapToSignal { settings -> Signal<(Bool, [ResolvedMapping]), NoError> in
            let mappings = settings.activeMappings.filter { mapping in
                !FriendSpoofingSettings.normalizedIdentifier(mapping.target).isEmpty && !FriendSpoofingSettings.normalizedIdentifier(mapping.source).isEmpty
            }
            if !settings.isEnabled || mappings.isEmpty {
                return .single((false, []))
            }
            let restored = FriendSpoofingManager.restoredMappings(account: account, mappings: mappings)
            let needsResolve = mappings.contains(where: { $0.targetPeerId == nil || $0.sourcePeerId == nil })
            let live = (needsResolve ? (Signal<Void, NoError>.single(Void()) |> delay(0.4, queue: Queue.mainQueue())) : Signal<Void, NoError>.single(Void()))
            |> mapToSignal { _ in
                return combineLatest(mappings.map { mapping in
                    return FriendSpoofingManager.liveState(context: context, account: account, accountPeerId: accountPeerId, mapping: mapping)
                })
            }
            |> map { items -> (Bool, [ResolvedMapping]) in
                return (true, items.compactMap { $0 })
            }
            return restored
            |> mapToSignal { cached -> Signal<(Bool, [ResolvedMapping]), NoError> in
                if cached.isEmpty {
                    return live
                }
                return .single((true, cached)) |> then(live)
            }
        }
        |> distinctUntilChanged(isEqual: { lhs, rhs in
            if lhs.0 != rhs.0 || lhs.1.count != rhs.1.count {
                return false
            }
            for (lhsItem, rhsItem) in zip(lhs.1, rhs.1) {
                if lhsItem.targetQuery != rhsItem.targetQuery || lhsItem.sourceQuery != rhsItem.sourceQuery {
                    return false
                }
                if !FriendSpoofingManager.statesEqual(lhsItem.state, rhsItem.state) {
                    return false
                }
            }
            return true
        })
        |> mapToSignal { [weak self] enabled, resolved -> Signal<Never, NoError> in
            var next: [PeerId: FriendSpoofingOverlayState] = [:]
            for item in resolved {
                next[item.state.targetPeerId] = item.state
            }
            let previousIds = self?.lastTargetPeerIds ?? []
            let nextIds = Set(next.keys)
            self?.lastTargetPeerIds = nextIds
            FriendSpoofingOverlay.replaceAll(next, persist: enabled && !next.isEmpty)
            for state in next.values {
                account.viewTracker.forceUpdateCachedPeerData(peerId: state.sourcePeerId)
            }
            if enabled && !resolved.isEmpty {
                let _ = updateFriendSpoofingSettings(engine: engine, { current in
                    var nextSettings = current
                    for item in resolved {
                        nextSettings.upsertResolved(targetQuery: item.targetQuery, sourceQuery: item.sourceQuery, targetPeerId: item.state.targetPeerId.toInt64(), sourcePeerId: item.state.sourcePeerId.toInt64())
                    }
                    return nextSettings
                }).start()
            }
            var restoreSignals: [Signal<Never, NoError>] = []
            for peerId in previousIds.subtracting(nextIds) {
                restoreSignals.append(account.viewTracker.peerView(peerId, updateData: true) |> take(1) |> ignoreValues)
            }
            if restoreSignals.isEmpty {
                return .complete()
            }
            return combineLatest(restoreSignals) |> ignoreValues
        }).start())
    }
    
    deinit {
        self.disposable.dispose()
        FriendSpoofingOverlay.replaceAll([:], persist: false)
    }
    
    private static func statesEqual(_ lhs: FriendSpoofingOverlayState, _ rhs: FriendSpoofingOverlayState) -> Bool {
        if lhs.targetPeerId != rhs.targetPeerId {
            return false
        }
        if lhs.sourcePeerId != rhs.sourcePeerId {
            return false
        }
        if lhs.sourceUser != rhs.sourceUser {
            return false
        }
        if lhs.sourceCachedData?.about != rhs.sourceCachedData?.about {
            return false
        }
        if lhs.sourceCachedData?.starGiftsCount != rhs.sourceCachedData?.starGiftsCount {
            return false
        }
        if lhs.sourceCachedData?.verification != rhs.sourceCachedData?.verification {
            return false
        }
        if lhs.sourceCachedData?.starRating != rhs.sourceCachedData?.starRating {
            return false
        }
        if lhs.sourceCachedData?.personalChannel != rhs.sourceCachedData?.personalChannel {
            return false
        }
        return true
    }
    
    private static func restoredMappings(account: Account, mappings: [FriendSpoofingMapping]) -> Signal<[ResolvedMapping], NoError> {
        return account.postbox.transaction { transaction -> [ResolvedMapping] in
            var next: [ResolvedMapping] = []
            for mapping in mappings {
                guard let targetRaw = mapping.targetPeerId, let sourceRaw = mapping.sourcePeerId else {
                    continue
                }
                let targetId = PeerId(targetRaw)
                let sourceId = PeerId(sourceRaw)
                guard let source = transaction.getPeer(sourceId) as? TelegramUser else {
                    continue
                }
                let cached = transaction.getPeerCachedData(peerId: sourceId) as? CachedUserData
                let state = FriendSpoofingOverlayState(targetPeerId: targetId, sourcePeerId: sourceId, sourceUser: source, sourceCachedData: cached)
                next.append(ResolvedMapping(targetQuery: mapping.target, sourceQuery: mapping.source, state: state))
            }
            return next
        }
    }
    
    private static func liveState(context: AccountContext, account: Account, accountPeerId: PeerId, mapping: FriendSpoofingMapping) -> Signal<ResolvedMapping?, NoError> {
        let target = FriendSpoofingSettings.normalizedIdentifier(mapping.target)
        let source = FriendSpoofingSettings.normalizedIdentifier(mapping.source)
        return combineLatest(
            FriendSpoofingManager.resolvePeer(context: context, target: target),
            FriendSpoofingManager.resolvePeer(context: context, target: source)
        )
        |> mapToSignal { targetPeer, sourcePeer -> Signal<ResolvedMapping?, NoError> in
            guard let targetPeer, case let .user(targetUser) = targetPeer, targetUser.id != accountPeerId, !MessageSimulationOverlay.isSimulatedPeer(targetUser.id) else {
                return .single(nil)
            }
            guard let sourcePeer, case let .user(sourceUser) = sourcePeer, sourceUser.id != targetUser.id, !MessageSimulationOverlay.isSimulatedPeer(sourceUser.id) else {
                return .single(nil)
            }
            let targetId = targetUser.id
            return account.viewTracker.peerView(sourceUser.id, updateData: true)
            |> map { view -> ResolvedMapping? in
                let sourceUser = (view.peers[sourceUser.id] as? TelegramUser) ?? sourceUser
                let state = FriendSpoofingOverlayState(targetPeerId: targetId, sourcePeerId: sourceUser.id, sourceUser: sourceUser, sourceCachedData: view.cachedData as? CachedUserData)
                return ResolvedMapping(targetQuery: mapping.target, sourceQuery: mapping.source, state: state)
            }
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
