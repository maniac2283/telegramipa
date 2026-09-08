import Foundation
import SwiftSignalKit
import TelegramCore

public struct FriendSpoofingSettings: Equatable, Codable {
    public var isEnabled: Bool
    public var target: String
    public var source: String
    public var targetPeerId: Int64?
    public var sourcePeerId: Int64?
    
    public static var defaultSettings: FriendSpoofingSettings {
        return FriendSpoofingSettings(isEnabled: false, target: "", source: "", targetPeerId: nil, sourcePeerId: nil)
    }
    
    public init(isEnabled: Bool, target: String, source: String, targetPeerId: Int64? = nil, sourcePeerId: Int64? = nil) {
        self.isEnabled = isEnabled
        self.target = target
        self.source = source
        self.targetPeerId = targetPeerId
        self.sourcePeerId = sourcePeerId
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: "isEnabled") ?? false
        self.target = try container.decodeIfPresent(String.self, forKey: "target") ?? ""
        self.source = try container.decodeIfPresent(String.self, forKey: "source") ?? ""
        self.targetPeerId = try container.decodeIfPresent(Int64.self, forKey: "targetPeerId")
        self.sourcePeerId = try container.decodeIfPresent(Int64.self, forKey: "sourcePeerId")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode(self.isEnabled, forKey: "isEnabled")
        try container.encode(self.target, forKey: "target")
        try container.encode(self.source, forKey: "source")
        try container.encodeIfPresent(self.targetPeerId, forKey: "targetPeerId")
        try container.encodeIfPresent(self.sourcePeerId, forKey: "sourcePeerId")
    }
}

public func updateFriendSpoofingSettings(engine: TelegramEngine, _ f: @escaping (FriendSpoofingSettings) -> FriendSpoofingSettings) -> Signal<Never, NoError> {
    return engine.preferences.update(id: ApplicationSpecificPreferencesKeys.friendSpoofingSettings, { entry in
        let currentSettings: FriendSpoofingSettings
        if let entry = entry?.get(FriendSpoofingSettings.self) {
            currentSettings = entry
        } else {
            currentSettings = .defaultSettings
        }
        return SharedPreferencesEntry(f(currentSettings))
    })
}
