import SwiftSyntax

struct AssociatedValue: Equatable, CustomStringConvertible {
    let label: Label
    let variableType: VariableType
    let isInitialized: Bool

    var identifier: String {
        switch label {
        case let .identifierPattern(pattern):
            return pattern.identifier.text
        case let .index(index):
            return "i\(index)"
        }
    }

    var description: String {
        let initialized = isInitialized ? "initialized" : "uninitialized"
        return "(\(identifier), \(variableType), \(initialized))"
    }

    enum Label: Equatable {
        case identifierPattern(IdentifierPatternSyntax)
        case index(Int)

        static func ==(lhs: Label, rhs: Label) -> Bool {
            switch (lhs, rhs) {
            case let (.identifierPattern(left), .identifierPattern(right)):
                return left.identifier.text == right.identifier.text
            case let (.index(left), .index(right)):
                return left == right
            default:
                return false
            }
        }
    }
}
