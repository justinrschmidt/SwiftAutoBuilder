import SwiftSyntax

struct SetValueFunctionsGenerator {
    static func createSetValueFunctions(identifier: String, variableType: VariableType, returnType: String) throws -> [DeclSyntaxProtocol] {
        let type = variableType.typeSyntax
        switch variableType {
        case let .array(elementType):
            return [
                try createSetValueFunction(identifier: identifier, type: type, returnType: returnType),
                try createAppendElementFunction(identifier: identifier, elementType: elementType, returnType: returnType),
                try createAppendCollectionFunction(identifier: identifier, elementType: elementType, returnType: returnType),
                try createRemoveAllFunction(identifier: identifier, returnType: returnType)
            ]
        case let .dictionary(keyType, valueType):
            return [
                try createSetValueFunction(identifier: identifier, type: type, returnType: returnType),
                try createInsertDictionaryFunction(identifier: identifier, keyType: keyType, valueType: valueType, returnType: returnType),
                try createMergeDictionaryFunction(identifier: identifier, keyType: keyType, valueType: valueType, returnType: returnType),
                try createRemoveAllFunction(identifier: identifier, returnType: returnType)
            ]
        case let .set(elementType):
            return [
                try createSetValueFunction(identifier: identifier, type: type, returnType: returnType),
                try createInsertSetFunction(identifier: identifier, elementType: elementType, returnType: returnType),
                try createFormUnionSetFunction(identifier: identifier, elementType: elementType, returnType: returnType),
                try createRemoveAllFunction(identifier: identifier, returnType: returnType)
            ]
        case .implicit, .explicit(_):
            return [
                try createSetValueFunction(identifier: identifier, type: type, returnType: returnType)
            ]
        }
    }

    private static func createSetValueFunction(identifier: String,  type: TypeSyntaxProtocol, returnType: String) throws -> FunctionDeclSyntax {
        return try FunctionDeclSyntax("@discardableResult\npublic func set(\(raw: identifier): \(type)) -> \(raw: returnType)") {
            "self.\(raw: identifier).set(value: \(raw: identifier))"
            "return self"
        }
    }

    private static func createAppendElementFunction(identifier: String, elementType: TypeSyntax, returnType: String) throws -> FunctionDeclSyntax {
        return try FunctionDeclSyntax("@discardableResult\npublic func appendTo(\(raw: identifier) element: \(elementType.trimmed)) -> \(raw: returnType)") {
            "self.\(raw: identifier).append(element: element)"
            "return self"
        }
    }

    private static func createAppendCollectionFunction(identifier: String, elementType: TypeSyntax, returnType: String) throws -> FunctionDeclSyntax {
        return try FunctionDeclSyntax("@discardableResult\npublic func appendTo<C>(\(raw: identifier) collection: C) -> \(raw: returnType) where C: Collection, C.Element == \(elementType.trimmed)") {
            "self.\(raw: identifier).append(contentsOf: collection)"
            "return self"
        }
    }

    private static func createInsertDictionaryFunction(identifier: String, keyType: TypeSyntax, valueType: TypeSyntax, returnType: String) throws -> FunctionDeclSyntax {
        return try FunctionDeclSyntax("@discardableResult\npublic func insertInto(\(raw: identifier) value: \(valueType.trimmed), forKey key: \(keyType.trimmed)) -> \(raw: returnType)") {
            "\(raw: identifier).insert(key: key, value: value)"
            "return self"
        }
    }

    private static func createMergeDictionaryFunction(identifier: String, keyType: TypeSyntax, valueType: TypeSyntax, returnType: String) throws -> FunctionDeclSyntax {
        return try FunctionDeclSyntax("@discardableResult\npublic func mergeInto\(raw: identifier.capitalized)(other: [\(keyType.trimmed): \(valueType.trimmed)], uniquingKeysWith combine: (\(valueType.trimmed), \(valueType.trimmed)) throws -> \(valueType.trimmed)) rethrows -> \(raw: returnType)") {
            "try \(raw: identifier).merge(other: other, uniquingKeysWith: combine)"
            "return self"
        }
    }

    private static func createInsertSetFunction(identifier: String, elementType: TypeSyntax, returnType: String) throws -> FunctionDeclSyntax {
        return try FunctionDeclSyntax("@discardableResult\npublic func insertInto(\(raw: identifier) element: \(elementType.trimmed)) -> \(raw: returnType)") {
            "\(raw: identifier).insert(element: element)"
            "return self"
        }
    }

    private static func createFormUnionSetFunction(identifier: String, elementType: TypeSyntax, returnType: String) throws -> FunctionDeclSyntax {
        return try FunctionDeclSyntax("@discardableResult\npublic func formUnionWith\(raw: identifier.capitalized)(other: Set<\(elementType.trimmed)>) -> \(raw: returnType)") {
            "\(raw: identifier).formUnion(other: other)"
            "return self"
        }
    }

    private static func createRemoveAllFunction(identifier: String, returnType: String) throws -> FunctionDeclSyntax {
        return try FunctionDeclSyntax("@discardableResult\npublic func removeAllFrom\(raw: identifier.capitalized)() -> \(raw: returnType)") {
            "\(raw: identifier).removeAll()"
            "return self"
        }
    }
}
