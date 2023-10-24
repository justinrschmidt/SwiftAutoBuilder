import SwiftSyntax

struct SetValueFunctionsGenerator {
    static func createSetValueFunctions(identifierPattern: IdentifierPatternSyntax, variableType: VariableType, returnType: TypeSyntaxProtocol) throws -> [DeclSyntaxProtocol] {
        let type = variableType.typeSyntax
        switch variableType {
        case let .array(elementType):
            return [
                try createSetValueFunction(identifierPattern: identifierPattern, type: type, returnType: returnType),
                try createAppendElementFunction(identifierPattern: identifierPattern, elementType: elementType, returnType: returnType),
                try createAppendCollectionFunction(identifierPattern: identifierPattern, elementType: elementType, returnType: returnType),
                try createRemoveAllFunction(identifierPattern: identifierPattern, returnType: returnType)
            ]
        case let .dictionary(keyType, valueType):
            return [
                try createSetValueFunction(identifierPattern: identifierPattern, type: type, returnType: returnType),
                try createInsertDictionaryFunction(identifierPattern: identifierPattern, keyType: keyType, valueType: valueType, returnType: returnType),
                try createMergeDictionaryFunction(identifierPattern: identifierPattern, keyType: keyType, valueType: valueType, returnType: returnType),
                try createRemoveAllFunction(identifierPattern: identifierPattern, returnType: returnType)
            ]
        case let .set(elementType):
            return [
                try createSetValueFunction(identifierPattern: identifierPattern, type: type, returnType: returnType),
                try createInsertSetFunction(identifierPattern: identifierPattern, elementType: elementType, returnType: returnType),
                try createFormUnionSetFunction(identifierPattern: identifierPattern, elementType: elementType, returnType: returnType),
                try createRemoveAllFunction(identifierPattern: identifierPattern, returnType: returnType)
            ]
        case let .optional(wrappedType):
            return [
                try createSetValueFunction(identifierPattern: identifierPattern, type: OptionalTypeSyntax(wrappedType: wrappedType), returnType: returnType)
            ]
        case .implicit, .explicit(_):
            return [
                try createSetValueFunction(identifierPattern: identifierPattern, type: type, returnType: returnType)
            ]
        }
    }

    private static func createSetValueFunction(identifierPattern: IdentifierPatternSyntax,  type: TypeSyntaxProtocol, returnType: TypeSyntaxProtocol) throws -> FunctionDeclSyntax {
        return try FunctionDeclSyntax("@discardableResult\npublic func set(\(identifierPattern): \(type)) -> \(returnType)") {
            "self.\(identifierPattern).set(value: \(identifierPattern))"
            "return self"
        }
    }

    private static func createAppendElementFunction(identifierPattern: IdentifierPatternSyntax, elementType: TypeSyntax, returnType: TypeSyntaxProtocol) throws -> FunctionDeclSyntax {
        return try FunctionDeclSyntax("@discardableResult\npublic func appendTo(\(identifierPattern) element: \(elementType.trimmed)) -> \(returnType)") {
            "self.\(identifierPattern).append(element: element)"
            "return self"
        }
    }

    private static func createAppendCollectionFunction(identifierPattern: IdentifierPatternSyntax, elementType: TypeSyntax, returnType: TypeSyntaxProtocol) throws -> FunctionDeclSyntax {
        return try FunctionDeclSyntax("@discardableResult\npublic func appendTo<C>(\(identifierPattern) collection: C) -> \(returnType) where C: Collection, C.Element == \(elementType.trimmed)") {
            "self.\(identifierPattern).append(contentsOf: collection)"
            "return self"
        }
    }

    private static func createInsertDictionaryFunction(identifierPattern: IdentifierPatternSyntax, keyType: TypeSyntax, valueType: TypeSyntax, returnType: TypeSyntaxProtocol) throws -> FunctionDeclSyntax {
        return try FunctionDeclSyntax("@discardableResult\npublic func insertInto(\(identifierPattern) value: \(valueType.trimmed), forKey key: \(keyType.trimmed)) -> \(returnType)") {
            "\(identifierPattern).insert(key: key, value: value)"
            "return self"
        }
    }

    private static func createMergeDictionaryFunction(identifierPattern: IdentifierPatternSyntax, keyType: TypeSyntax, valueType: TypeSyntax, returnType: TypeSyntaxProtocol) throws -> FunctionDeclSyntax {
        return try FunctionDeclSyntax("@discardableResult\npublic func mergeInto\(raw: identifierPattern.identifier.text.capitalized)(other: [\(keyType.trimmed): \(valueType.trimmed)], uniquingKeysWith combine: (\(valueType.trimmed), \(valueType.trimmed)) throws -> \(valueType.trimmed)) rethrows -> \(returnType)") {
            "try \(identifierPattern).merge(other: other, uniquingKeysWith: combine)"
            "return self"
        }
    }

    private static func createInsertSetFunction(identifierPattern: IdentifierPatternSyntax, elementType: TypeSyntax, returnType: TypeSyntaxProtocol) throws -> FunctionDeclSyntax {
        return try FunctionDeclSyntax("@discardableResult\npublic func insertInto(\(identifierPattern) element: \(elementType.trimmed)) -> \(returnType)") {
            "\(identifierPattern).insert(element: element)"
            "return self"
        }
    }

    private static func createFormUnionSetFunction(identifierPattern: IdentifierPatternSyntax, elementType: TypeSyntax, returnType: TypeSyntaxProtocol) throws -> FunctionDeclSyntax {
        return try FunctionDeclSyntax("@discardableResult\npublic func formUnionWith\(raw: identifierPattern.identifier.text.capitalized)(other: Set<\(elementType.trimmed)>) -> \(returnType)") {
            "\(identifierPattern).formUnion(other: other)"
            "return self"
        }
    }

    private static func createRemoveAllFunction(identifierPattern: IdentifierPatternSyntax, returnType: TypeSyntaxProtocol) throws -> FunctionDeclSyntax {
        return try FunctionDeclSyntax("@discardableResult\npublic func removeAllFrom\(raw: identifierPattern.identifier.text.capitalized)() -> \(returnType)") {
            "\(identifierPattern).removeAll()"
            "return self"
        }
    }
}
