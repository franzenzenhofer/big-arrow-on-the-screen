import Foundation
import Testing

/// Loads a recorded fixture from `Tests/BigArrowCoreTests/Fixtures`.
enum Fixture {
    static func data(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        return try Data(contentsOf: url.appendingPathComponent(name))
    }

    static func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        try JSONDecoder().decode(type, from: data(name))
    }
}
