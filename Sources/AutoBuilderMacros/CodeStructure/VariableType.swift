import SwiftSyntax

enum VariableType: Equatable, CustomStringConvertible {
    case implicit
    case array(elementType: TypeSyntax)
    case dictionary(keyType: TypeSyntax, valueType: TypeSyntax)
    case set(elementType: TypeSyntax)
    case optional(wrappedType: TypeSyntax)
    case explicit(typeNode: TypeSyntax)

    var isImplicit: Bool {
        switch self {
        case .implicit:
            return true
        default:
            return false
        }
    }

    var isCollection: Bool {
        switch self {
        case .array(_), .dictionary(_, _), .set(_):
            return true
        default:
            return false
        }
    }

    var typeSyntax: TypeSyntaxProtocol {
        switch self {
        case .implicit:
            fatalError("Unable to create a TypeSyntax from an implicit type")
        case let .array(elementType):
            return ArrayTypeSyntax(element: elementType)
        case let .dictionary(keyType, valueType):
            return DictionaryTypeSyntax(key: keyType, value: valueType)
        case let .set(elementType):
            return IdentifierTypeSyntax(name: "Set", genericTypes: [elementType])
        case let .optional(wrappedType):
            return OptionalTypeSyntax(wrappedType: wrappedType)
        case let .explicit(typeNode):
            return typeNode
        }
    }

    var description: String {
        switch self {
        case .implicit:
            return ""
        case let .array(elementType):
            return "A:[\(elementType.trimmedDescription)]"
        case let .dictionary(keyType, valueType):
            return "D:[\(keyType.trimmedDescription):\(valueType.trimmedDescription)]"
        case let .set(elementType):
            return "S:Set<\(elementType.trimmedDescription)>"
        case let .optional(wrappedType):
            return "O:\(wrappedType.trimmedDescription)?"
        case let .explicit(typeNode):
            return typeNode.trimmedDescription
        }
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
        case let (.optional(lhsWrappedType), .optional(rhsWrappedType)):
            return typesAreEqual(lhsWrappedType, rhsWrappedType)
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
