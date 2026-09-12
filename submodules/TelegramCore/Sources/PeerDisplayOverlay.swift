import Foundation
import Postbox
import SwiftSignalKit

public enum PeerDisplayOverlay {
    private static let pipe = ValuePipe<Int>()
    private static let lock = NSLock()
    private static var revision: Int = 0
    
    public static func notifyUpdated() {
        self.lock.lock()
        self.revision += 1
        let value = self.revision
        self.lock.unlock()
        self.pipe.putNext(value)
    }
    
    public static var updated: Signal<Int, NoError> {
        return .single(0) |> then(self.pipe.signal())
    }
    
    public static func apply(peer: Peer) -> Peer {
        if let user = peer as? TelegramUser {
            var updated: Peer = ProfileSpoofingOverlay.applyVisual(to: user)
            if let overlayUser = updated as? TelegramUser {
                updated = MessageSimulationOverlay.applyVisual(to: overlayUser)
            }
            if let overlayUser = updated as? TelegramUser {
                updated = FriendSpoofingOverlay.applyVisual(to: overlayUser)
            }
            if let overlayUser = updated as? TelegramUser {
                updated = ManualProfileOverlay.applyVisual(to: overlayUser)
            }
            return updated
        }
        if let channel = peer as? TelegramChannel {
            return ChannelSpoofingOverlay.applyVisual(to: channel)
        }
        return peer
    }
    
    public static func applyEngine(_ peer: EnginePeer) -> EnginePeer {
        return EnginePeer(self.apply(peer: peer._asPeer()))
    }
    
    public static func applyEngineMap(_ peers: [EnginePeer.Id: EnginePeer]) -> [EnginePeer.Id: EnginePeer] {
        var result: [EnginePeer.Id: EnginePeer] = [:]
        result.reserveCapacity(peers.count)
        for (id, peer) in peers {
            result[id] = self.applyEngine(peer)
        }
        return result
    }
    
    public static func applyRendered(_ rendered: EngineRenderedPeer) -> EngineRenderedPeer {
        var peers: [EnginePeer.Id: EnginePeer] = [:]
        for (id, peer) in rendered.peers {
            peers[id] = self.applyEngine(peer)
        }
        return EngineRenderedPeer(peerId: rendered.peerId, peers: peers, associatedMedia: rendered.associatedMedia)
    }
    
    public static func isOverlaying(_ peerId: PeerId) -> Bool {
        return self.mediaSourcePeerId(for: peerId) != peerId
    }
    
    public static func mediaSourcePeerId(for peerId: PeerId) -> PeerId {
        if let state = MessageSimulationOverlay.current(for: peerId) {
            return state.sourcePeerId
        }
        if let state = ProfileSpoofingOverlay.current(for: peerId) {
            return state.targetPeerId
        }
        if let state = FriendSpoofingOverlay.current(for: peerId) {
            return state.sourcePeerId
        }
        if let state = ChannelSpoofingOverlay.current(for: peerId) {
            return state.sourceChannelId
        }
        return peerId
    }
    
    public static func giftsSourcePeerId(for peerId: PeerId) -> PeerId {
        return self.mediaSourcePeerId(for: peerId)
    }
    
    public static func postsSourcePeerId(for peerId: PeerId) -> PeerId {
        return self.mediaSourcePeerId(for: peerId)
    }
    
    public static func musicSourcePeerId(for peerId: PeerId) -> PeerId {
        return self.mediaSourcePeerId(for: peerId)
    }
    
    public static func collectibleItemPeerId(for peerId: PeerId) -> PeerId {
        return self.mediaSourcePeerId(for: peerId)
    }
    
    public static func overlayCachedUserData(for peerId: PeerId) -> CachedUserData? {
        if let state = MessageSimulationOverlay.current(for: peerId) {
            return state.sourceCachedData
        }
        if let state = ProfileSpoofingOverlay.current(for: peerId) {
            return state.targetCachedData
        }
        if let state = FriendSpoofingOverlay.current(for: peerId) {
            return state.sourceCachedData
        }
        return nil
    }
    
    public static func mediaPeer(for peer: Peer) -> Peer {
        if let user = peer as? TelegramUser {
            if let state = MessageSimulationOverlay.current(for: user.id) {
                return state.sourceUser
            }
            if let state = ProfileSpoofingOverlay.current(for: user.id) {
                return state.targetUser
            }
            if let state = FriendSpoofingOverlay.current(for: user.id) {
                return state.sourceUser
            }
        }
        if let channel = peer as? TelegramChannel, let state = ChannelSpoofingOverlay.current(for: channel.id) {
            return state.sourceChannel
        }
        return peer
    }
    
    public static func mediaPeerReference(for peer: EnginePeer) -> PeerReference? {
        return PeerReference(self.mediaPeer(for: peer._asPeer()))
    }
    
    public static func applyCached(peerId: PeerId, data: CachedPeerData?) -> CachedPeerData? {
        guard let data else {
            return nil
        }
        if let userData = data as? CachedUserData {
            return ManualProfileOverlay.applyCached(peerId: peerId, data: FriendSpoofingOverlay.applyCached(peerId: peerId, data: MessageSimulationOverlay.applyCached(peerId: peerId, data: ProfileSpoofingOverlay.applyCached(peerId: peerId, data: userData))))
        }
        if let channelData = data as? CachedChannelData {
            return ChannelSpoofingOverlay.applyCached(peerId: peerId, data: channelData)
        }
        return data
    }
}
