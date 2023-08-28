import SwiftSyntax

struct AssociatedValue: Equatable, CustomStringConvertible {
    let label: Label
    let variableType: VariableType
    let isInitialized: Bool

    var identifier: String {
        return label.identifier
    }

    var description: String {
        let initialized = isInitialized ? "initialized" : "uninitialized"
        return "(\(identifier), \(variableType), \(initialized))"
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

        var isIndex: Bool {
            switch self {
            case .index(_):
                return true
            default:
                return false
            }
        }

        func hash(into hasher: inout Hasher) {
            switch self {
            case let .identifierPattern(pattern):
                hasher.combine(pattern.identifier.text)
            case let .index(index):
                hasher.combine(index)
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
