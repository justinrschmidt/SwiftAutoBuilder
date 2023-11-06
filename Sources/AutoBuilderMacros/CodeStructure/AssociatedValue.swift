import SwiftSyntax

struct AssociatedValue: Equatable, CustomStringConvertible {
    let label: Label
    let variableType: VariableType
    let isInitialized: Bool
    let firstNameToken: TokenSyntax?

    var identifierPattern: IdentifierPatternSyntax {
        return label.identifierPattern
    }

    var description: String {
        let initialized = isInitialized ? "initialized" : "uninitialized"
        return "(\(identifierPattern.identifier.text), \(variableType), \(initialized))"
    }

    static func == (lhs: AssociatedValue, rhs: AssociatedValue) -> Bool {
        guard lhs.label == rhs.label else { return false }
        guard lhs.variableType == rhs.variableType else { return false }
        guard lhs.isInitialized == rhs.isInitialized else { return false }
        guard lhs.firstNameToken?.text == rhs.firstNameToken?.text else { return false }
        return true
    }

    enum Label: Equatable, Hashable {
        case identifierPattern(IdentifierPatternSyntax)
        case index(Int)

        var identifierPattern: IdentifierPatternSyntax {
            switch self {
            case let .identifierPattern(pattern):
                return pattern
            case let .index(index):
                return IdentifierPatternSyntax(identifier: "i\(raw: index)")
            }
        }

        static func == (lhs: Label, rhs: Label) -> Bool {
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
