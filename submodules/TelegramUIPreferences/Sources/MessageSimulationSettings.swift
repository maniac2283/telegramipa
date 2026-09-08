import Foundation
import SwiftSignalKit
import TelegramCore

public struct MessageSimulationSettings: Equatable, Codable {
    public var isEnabled: Bool
    public var target: String
    public var composeText: String
    public var sourcePeerId: Int64?
    public var simulatedPeerId: Int64?
    
    public static var defaultSettings: MessageSimulationSettings {
        return MessageSimulationSettings(isEnabled: false, target: "", composeText: "", sourcePeerId: nil, simulatedPeerId: nil)
    }
    
    public init(isEnabled: Bool, target: String, composeText: String = "", sourcePeerId: Int64? = nil, simulatedPeerId: Int64? = nil) {
        self.isEnabled = isEnabled
        self.target = target
        self.composeText = composeText
        self.sourcePeerId = sourcePeerId
        self.simulatedPeerId = simulatedPeerId
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: "isEnabled") ?? false
        self.target = try container.decodeIfPresent(String.self, forKey: "target") ?? ""
        self.composeText = try container.decodeIfPresent(String.self, forKey: "composeText") ?? ""
        self.sourcePeerId = try container.decodeIfPresent(Int64.self, forKey: "sourcePeerId")
        self.simulatedPeerId = try container.decodeIfPresent(Int64.self, forKey: "simulatedPeerId")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode(self.isEnabled, forKey: "isEnabled")
        try container.encode(self.target, forKey: "target")
        try container.encode(self.composeText, forKey: "composeText")
        try container.encodeIfPresent(self.sourcePeerId, forKey: "sourcePeerId")
        try container.encodeIfPresent(self.simulatedPeerId, forKey: "simulatedPeerId")
    }
}

public func updateMessageSimulationSettings(engine: TelegramEngine, _ f: @escaping (MessageSimulationSettings) -> MessageSimulationSettings) -> Signal<Never, NoError> {
    return engine.preferences.update(id: ApplicationSpecificPreferencesKeys.messageSimulationSettings, { entry in
        let currentSettings: MessageSimulationSettings
        if let entry = entry?.get(MessageSimulationSettings.self) {
            currentSettings = entry
        } else {
            currentSettings = .defaultSettings
        }
        return SharedPreferencesEntry(f(currentSettings))
    })
}
