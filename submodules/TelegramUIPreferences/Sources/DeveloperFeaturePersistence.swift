import Foundation
import Postbox

enum DeveloperFeaturePersistence {
    static let profileKey = "telegram.developer.profileSpoofingSettings.v1"
    static let friendKey = "telegram.developer.friendSpoofingSettings.v1"
    static let simulationKey = "telegram.developer.messageSimulationSettings.v1"
    
    static func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else {
            return
        }
        UserDefaults.standard.set(data, forKey: key)
        UserDefaults.standard.synchronize()
    }
    
    static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    
    static func fromPreference<T: Codable>(_ type: T.Type, entry: PreferencesEntry?, key: String, empty: T) -> T {
        if let value = entry?.get(T.self) {
            save(value, key: key)
            return value
        }
        return load(T.self, key: key) ?? empty
    }
}
