import SwiftSyntax

struct BuildablePropertyGenerator {
    static func createInitializer(identifierPattern: IdentifierPatternSyntax, variableType: VariableType) throws -> CodeBlockItemSyntax {
        let typeIdentifier = try createTypeIdentifier(for: variableType, includeGenericClause: false)
        let args = variableType.isCollection ? "" : "name: \"\(identifierPattern.identifier.text)\""
        return "\(identifierPattern) = \(typeIdentifier)(\(raw: args))"
    }

    static func createVariableDecl(
        modifierKeywords: [Keyword] = [],
        bindingKeyword: Keyword,
        identifierPattern: IdentifierPatternSyntax,
        variableType: VariableType
    ) throws -> VariableDeclSyntax {
        let modifiers = DeclModifierListSyntax {
            for keyword in modifierKeywords {
                DeclModifierSyntax(name: .keyword(keyword))
            }
        }
        let type = try createTypeIdentifier(for: variableType, includeGenericClause: true)
        let typeAnnotation = TypeAnnotationSyntax(type: type)
        return VariableDeclSyntax(
            modifiers: modifiers,
            bindingKeyword,
            name: identifierPattern.cast(PatternSyntax.self),
            type: typeAnnotation)
    }

    private static func createTypeIdentifier(
        for type: VariableType,
        includeGenericClause: Bool
    ) throws -> IdentifierTypeSyntax {
        switch type {
        case .implicit:
            throw AutoBuilderMacroError.missingType
        case let .array(elementType):
            let genericTypes = includeGenericClause ? [elementType.trimmed] : []
            return IdentifierTypeSyntax(name: "BuildableArrayProperty", genericTypes: genericTypes)
        case let .dictionary(keyType, valueType):
            let genericTypes = includeGenericClause ? [keyType.trimmed, valueType.trimmed] : []
            return IdentifierTypeSyntax(name: "BuildableDictionaryProperty", genericTypes: genericTypes)
        case let .set(elementType):
            let genericTypes = includeGenericClause ? [elementType.trimmed] : []
            return IdentifierTypeSyntax(name: "BuildableSetProperty", genericTypes: genericTypes)
        case let .optional(wrappedType):
            let genericTypes = includeGenericClause ? [wrappedType.trimmed] : []
            return IdentifierTypeSyntax(name: "BuildableOptionalProperty", genericTypes: genericTypes)
        case let .explicit(typeNode):
            let genericTypes = includeGenericClause ? [typeNode.trimmed] : []
            return IdentifierTypeSyntax(name: "BuildableProperty", genericTypes: genericTypes)
        }
    }
}
