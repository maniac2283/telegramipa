import Foundation
import Postbox
import SwiftSignalKit

public final class FriendSpoofingOverlayState {
    public let targetPeerId: PeerId
    public let sourcePeerId: PeerId
    public let sourceUser: TelegramUser
    public let sourceCachedData: CachedUserData?
    
    public init(targetPeerId: PeerId, sourcePeerId: PeerId, sourceUser: TelegramUser, sourceCachedData: CachedUserData?) {
        self.targetPeerId = targetPeerId
        self.sourcePeerId = sourcePeerId
        self.sourceUser = sourceUser
        self.sourceCachedData = sourceCachedData
    }
}

public enum FriendSpoofingOverlay {
    private static let lock = NSLock()
    private static var states: [PeerId: FriendSpoofingOverlayState] = [:]
    
    public static func current(for targetPeerId: PeerId) -> FriendSpoofingOverlayState? {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.states[targetPeerId]
    }
    
    public static func sourcePeerId(for peerId: PeerId) -> PeerId? {
        return self.current(for: peerId)?.sourcePeerId
    }
    
    public static func set(_ state: FriendSpoofingOverlayState?, for targetPeerId: PeerId, persist: Bool = true) {
        self.lock.lock()
        if let state {
            self.states[targetPeerId] = state
        } else {
            self.states.removeValue(forKey: targetPeerId)
        }
        self.lock.unlock()
        PeerDisplayOverlay.notifyUpdated()
        if persist {
            let key = Self.defaultsKey(for: targetPeerId)
            if let state {
                UserDefaults.standard.set(state.sourcePeerId.toInt64(), forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
    
    public static func applyVisual(to user: TelegramUser) -> TelegramUser {
        guard let state = self.current(for: user.id) else {
            return user
        }
        return ProfileSpoofingOverlay.makeSpoofedUser(selfUser: user, target: state.sourceUser)
    }
    
    public static func applyCached(peerId: PeerId, data: CachedUserData) -> CachedUserData {
        guard let state = self.current(for: peerId), let source = state.sourceCachedData else {
            return data
        }
        return ProfileSpoofingOverlay.mergeCached(selfData: data, target: source)
    }
    
    public static func applyToPostbox(account: Account, targetPeerId: PeerId) -> Signal<Never, NoError> {
        let _ = account
        let _ = targetPeerId
        return .complete()
    }
    
    private static func defaultsKey(for targetPeerId: PeerId) -> String {
        return "telegram.friendSpoofing.source.\(targetPeerId.toInt64())"
    }
}
