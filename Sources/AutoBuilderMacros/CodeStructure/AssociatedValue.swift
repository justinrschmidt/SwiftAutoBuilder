import SwiftSyntax

struct AssociatedValue: Equatable, CustomStringConvertible {
    let label: Label
    let variableType: VariableType
    let isInitialized: Bool
    let firstNameToken: TokenSyntax?

    var identifier: String {
        return label.identifier
    }

    var description: String {
        let initialized = isInitialized ? "initialized" : "uninitialized"
        return "(\(identifier), \(variableType), \(initialized))"
    }

    static func ==(lhs: AssociatedValue, rhs: AssociatedValue) -> Bool {
        guard lhs.label == rhs.label else { return false }
        guard lhs.variableType == rhs.variableType else { return false }
        guard lhs.isInitialized == rhs.isInitialized else { return false }
        guard lhs.firstNameToken?.text == rhs.firstNameToken?.text else { return false }
        return true
    }

    enum Label: Equatable, Hashable {
        case identifierPattern(IdentifierPatternSyntax)
        case index(Int)

        var identifier: String {
            switch self {
            case let .identifierPattern(pattern):
                return pattern.identifier.text
            case let .index(index):
                return "i\(index)"
            }
        }

        var pattern: IdentifierPatternSyntax? {
            if case let .identifierPattern(identifierPatternSyntax) = self {
                return identifierPatternSyntax
            } else {
                return nil
            }
        }

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
