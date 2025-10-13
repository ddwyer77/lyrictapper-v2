import Foundation

enum ProjectStoreError: Error {
    case encoding
    case decoding
}

enum ProjectStore {
    static func save(project: Project, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let data = try encoder.encode(project)
        try data.write(to: url)
    }

    static func load(from url: URL) throws -> Project {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(Project.self, from: data)
    }
}


