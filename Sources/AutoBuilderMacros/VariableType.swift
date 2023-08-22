import SwiftSyntax

enum VariableType: Equatable, CustomStringConvertible {
    case implicit
    case array(elementType: TypeSyntax)
    case dictionary(keyType: TypeSyntax, valueType: TypeSyntax)
    case set(elementType: TypeSyntax)
    case explicit(typeNode: TypeSyntax)

    var isImplicit: Bool {
        switch self {
        case .implicit:
            return true
        default:
            return false
        }
    }

    var isExplicit: Bool {
        return !isImplicit
    }

    var isCollection: Bool {
        switch self {
        case .array(_), .dictionary(_, _), .set(_):
            return true
        default:
            return false
        }
    }

    var type: String {
        switch self {
        case .implicit:
            return ""
        case let .array(elementType):
            return "[\(elementType.trimmedDescription)]"
        case let .dictionary(keyType, valueType):
            return "[\(keyType.trimmedDescription):\(valueType.trimmedDescription)]"
        case let .set(elementType):
            return "Set<\(elementType.trimmedDescription)>"
        case let .explicit(typeNode):
            return typeNode.trimmedDescription
        }
    }

    var description: String {
        let typePrefix = switch self {
        case .implicit, .explicit(_): ""
        case .array(_): "A:"
        case .dictionary(_, _): "D:"
        case .set(_): "S:"
        }
        return "\(typePrefix)\(type)"
    }

    static func ==(lhs: VariableType, rhs: VariableType) -> Bool {
        switch (lhs, rhs) {
        case (.implicit, .implicit):
            return true
        case let (.array(lhsType), .array(rhsType)):
            return typesAreEqual(lhsType, rhsType)
        case let (.dictionary(lhsKey, lhsValue), .dictionary(rhsKey, rhsValue)):
            return typesAreEqual(lhsKey, rhsKey) && typesAreEqual(lhsValue, rhsValue)
        case let (.set(lhsType), .set(rhsType)):
            return typesAreEqual(lhsType, rhsType)
        case let (.explicit(lhsType), .explicit(rhsType)):
            return typesAreEqual(lhsType, rhsType)
        default:
            return false
        }
    }

    private static func typesAreEqual(_ lhs: TypeSyntax, _ rhs: TypeSyntax) -> Bool {
        return lhs.trimmedDescription == rhs.trimmedDescription
    }
}
