import SwiftSyntax
@testable import AutoBuilderMacros

enum VariableTypeDescriptor {
    case implicit
    case array(elementType: String)
    case dictionary(keyType: String, valueType: String)
    case set(elementType: String)
    case explicit(typeNode: String)

    var variableType: Property.VariableType {
        switch self {
        case .implicit:
            return .implicit
        case let .array(elementType):
            return .array(elementType: TypeSyntax(typeString: elementType))
        case let .dictionary(keyType, valueType):
            return .dictionary(keyType: TypeSyntax(typeString: keyType), valueType: TypeSyntax(typeString: valueType))
        case let .set(elementType):
            return .set(elementType: TypeSyntax(typeString: elementType))
        case let .explicit(typeNode):
            return .explicit(typeNode: TypeSyntax(typeString: typeNode))
        }
    }
}
