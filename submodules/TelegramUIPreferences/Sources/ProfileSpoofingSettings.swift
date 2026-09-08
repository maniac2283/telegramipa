import Foundation
import SwiftSignalKit
import TelegramCore

public struct ProfileSpoofingSettings: Equatable, Codable {
    public var isEnabled: Bool
    public var target: String
    public var channelSpoofingEnabled: Bool
    public var myChannel: String
    public var spoofChannelAs: String
    public var targetPeerId: Int64?
    public var ownedChannelPeerId: Int64?
    public var sourceChannelPeerId: Int64?
    
    public static var defaultSettings: ProfileSpoofingSettings {
        return ProfileSpoofingSettings(isEnabled: false, target: "", channelSpoofingEnabled: false, myChannel: "", spoofChannelAs: "", targetPeerId: nil, ownedChannelPeerId: nil, sourceChannelPeerId: nil)
    }
    
    public init(isEnabled: Bool, target: String, channelSpoofingEnabled: Bool = false, myChannel: String = "", spoofChannelAs: String = "", targetPeerId: Int64? = nil, ownedChannelPeerId: Int64? = nil, sourceChannelPeerId: Int64? = nil) {
        self.isEnabled = isEnabled
        self.target = target
        self.channelSpoofingEnabled = channelSpoofingEnabled
        self.myChannel = myChannel
        self.spoofChannelAs = spoofChannelAs
        self.targetPeerId = targetPeerId
        self.ownedChannelPeerId = ownedChannelPeerId
        self.sourceChannelPeerId = sourceChannelPeerId
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: "isEnabled") ?? false
        self.target = try container.decodeIfPresent(String.self, forKey: "target") ?? ""
        self.channelSpoofingEnabled = try container.decodeIfPresent(Bool.self, forKey: "channelSpoofingEnabled") ?? false
        self.myChannel = try container.decodeIfPresent(String.self, forKey: "myChannel") ?? ""
        self.spoofChannelAs = try container.decodeIfPresent(String.self, forKey: "spoofChannelAs") ?? ""
        self.targetPeerId = try container.decodeIfPresent(Int64.self, forKey: "targetPeerId")
        self.ownedChannelPeerId = try container.decodeIfPresent(Int64.self, forKey: "ownedChannelPeerId")
        self.sourceChannelPeerId = try container.decodeIfPresent(Int64.self, forKey: "sourceChannelPeerId")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode(self.isEnabled, forKey: "isEnabled")
        try container.encode(self.target, forKey: "target")
        try container.encode(self.channelSpoofingEnabled, forKey: "channelSpoofingEnabled")
        try container.encode(self.myChannel, forKey: "myChannel")
        try container.encode(self.spoofChannelAs, forKey: "spoofChannelAs")
        try container.encodeIfPresent(self.targetPeerId, forKey: "targetPeerId")
        try container.encodeIfPresent(self.ownedChannelPeerId, forKey: "ownedChannelPeerId")
        try container.encodeIfPresent(self.sourceChannelPeerId, forKey: "sourceChannelPeerId")
    }
}

public func updateProfileSpoofingSettings(engine: TelegramEngine, _ f: @escaping (ProfileSpoofingSettings) -> ProfileSpoofingSettings) -> Signal<Never, NoError> {
    return engine.preferences.update(id: ApplicationSpecificPreferencesKeys.profileSpoofingSettings, { entry in
        let currentSettings: ProfileSpoofingSettings
        if let entry = entry?.get(ProfileSpoofingSettings.self) {
            currentSettings = entry
        } else {
            currentSettings = .defaultSettings
        }
        return SharedPreferencesEntry(f(currentSettings))
    })
}
