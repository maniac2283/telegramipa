import Foundation
import SwiftSignalKit
import TelegramCore
import Postbox

public struct FriendSpoofingMapping: Equatable, Codable {
    public var target: String
    public var source: String
    public var targetPeerId: Int64?
    public var sourcePeerId: Int64?
    
    public init(target: String, source: String, targetPeerId: Int64? = nil, sourcePeerId: Int64? = nil) {
        self.target = target
        self.source = source
        self.targetPeerId = targetPeerId
        self.sourcePeerId = sourcePeerId
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.target = try container.decodeIfPresent(String.self, forKey: "target") ?? ""
        self.source = try container.decodeIfPresent(String.self, forKey: "source") ?? ""
        self.targetPeerId = try container.decodeIfPresent(Int64.self, forKey: "targetPeerId")
        self.sourcePeerId = try container.decodeIfPresent(Int64.self, forKey: "sourcePeerId")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode(self.target, forKey: "target")
        try container.encode(self.source, forKey: "source")
        try container.encodeIfPresent(self.targetPeerId, forKey: "targetPeerId")
        try container.encodeIfPresent(self.sourcePeerId, forKey: "sourcePeerId")
    }
}

public struct FriendSpoofingSettings: Equatable, Codable {
    public var isEnabled: Bool
    public var target: String
    public var source: String
    public var mappings: [FriendSpoofingMapping]
    
    public static var defaultSettings: FriendSpoofingSettings {
        return FriendSpoofingSettings(isEnabled: false, target: "", source: "", mappings: [])
    }
    
    public init(isEnabled: Bool, target: String, source: String, mappings: [FriendSpoofingMapping]) {
        self.isEnabled = isEnabled
        self.target = target
        self.source = source
        self.mappings = mappings
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: "isEnabled") ?? false
        self.target = try container.decodeIfPresent(String.self, forKey: "target") ?? ""
        self.source = try container.decodeIfPresent(String.self, forKey: "source") ?? ""
        var mappings = try container.decodeIfPresent([FriendSpoofingMapping].self, forKey: "mappings") ?? []
        if mappings.isEmpty {
            let legacyTargetPeerId = try container.decodeIfPresent(Int64.self, forKey: "targetPeerId")
            let legacySourcePeerId = try container.decodeIfPresent(Int64.self, forKey: "sourcePeerId")
            if !self.target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !self.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                mappings = [FriendSpoofingMapping(target: self.target, source: self.source, targetPeerId: legacyTargetPeerId, sourcePeerId: legacySourcePeerId)]
            }
        }
        self.mappings = mappings
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode(self.isEnabled, forKey: "isEnabled")
        try container.encode(self.target, forKey: "target")
        try container.encode(self.source, forKey: "source")
        try container.encode(self.mappings, forKey: "mappings")
    }
    
    public static func normalizedIdentifier(_ raw: String) -> String {
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
    
    public mutating func upsertDraftMapping() {
        let normalizedTarget = Self.normalizedIdentifier(self.target)
        let normalizedSource = Self.normalizedIdentifier(self.source)
        guard !normalizedTarget.isEmpty, !normalizedSource.isEmpty else {
            return
        }
        if let index = self.mappings.firstIndex(where: { Self.normalizedIdentifier($0.target) == normalizedTarget }) {
            self.mappings[index].target = self.target
            self.mappings[index].source = self.source
            if Self.normalizedIdentifier(self.mappings[index].source) != normalizedSource {
                self.mappings[index].sourcePeerId = nil
            }
        } else {
            self.mappings.append(FriendSpoofingMapping(target: self.target, source: self.source, targetPeerId: nil, sourcePeerId: nil))
        }
    }
    
    public mutating func removeMapping(at index: Int) {
        guard self.mappings.indices.contains(index) else {
            return
        }
        self.mappings.remove(at: index)
    }
    
    public var activeMappings: [FriendSpoofingMapping] {
        var result = self.mappings
        let normalizedTarget = Self.normalizedIdentifier(self.target)
        let normalizedSource = Self.normalizedIdentifier(self.source)
        if !normalizedTarget.isEmpty && !normalizedSource.isEmpty {
            if !result.contains(where: {
                if FriendSpoofingSettings.normalizedIdentifier($0.target) == normalizedTarget {
                    return true
                }
                if let targetPeerId = $0.targetPeerId, String(targetPeerId) == normalizedTarget {
                    return true
                }
                return false
            }) {
                result.append(FriendSpoofingMapping(target: self.target, source: self.source, targetPeerId: nil, sourcePeerId: nil))
            }
        }
        return result
    }
    
    public mutating func upsertResolved(targetQuery: String, sourceQuery: String, targetPeerId: Int64, sourcePeerId: Int64) {
        let normalizedTarget = Self.normalizedIdentifier(targetQuery)
        if let index = self.mappings.firstIndex(where: { $0.targetPeerId == targetPeerId || Self.normalizedIdentifier($0.target) == normalizedTarget }) {
            self.mappings[index].targetPeerId = targetPeerId
            self.mappings[index].sourcePeerId = sourcePeerId
            if Self.normalizedIdentifier(self.mappings[index].source) != Self.normalizedIdentifier(sourceQuery) && !sourceQuery.isEmpty {
                self.mappings[index].source = sourceQuery
            }
        } else {
            self.mappings.append(FriendSpoofingMapping(target: targetQuery, source: sourceQuery, targetPeerId: targetPeerId, sourcePeerId: sourcePeerId))
        }
    }
    
    public static func fromPreference(_ entry: PreferencesEntry?) -> FriendSpoofingSettings {
        return DeveloperFeaturePersistence.fromPreference(FriendSpoofingSettings.self, entry: entry, key: DeveloperFeaturePersistence.friendKey, empty: .defaultSettings)
    }
}

public func updateFriendSpoofingSettings(engine: TelegramEngine, _ f: @escaping (FriendSpoofingSettings) -> FriendSpoofingSettings) -> Signal<Never, NoError> {
    return engine.preferences.update(id: ApplicationSpecificPreferencesKeys.friendSpoofingSettings, { entry in
        let currentSettings = FriendSpoofingSettings.fromPreference(entry)
        let next = f(currentSettings)
        DeveloperFeaturePersistence.save(next, key: DeveloperFeaturePersistence.friendKey)
        return SharedPreferencesEntry(next)
    })
}
