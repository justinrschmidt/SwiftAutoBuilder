import SwiftSyntax

struct Property: Equatable, CustomStringConvertible {
    let identifier: String
    let type: String

    var identifierToken: TokenSyntax {
        return .identifier(identifier)
    }

    var description: String {
        return "(\(identifier), \(type))"
    }

    init(_ identifier: String, _ type: String) {
        self.identifier = identifier
        self.type = type
    }
}
