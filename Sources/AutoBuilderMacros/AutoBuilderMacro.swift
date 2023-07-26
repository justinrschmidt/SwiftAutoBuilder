import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

public struct AutoBuilderMacro: MemberMacro, ConformanceMacro {
    private enum DeclAnalysisResponse {
        case `struct`(structDecl: StructDeclSyntax, propertiesToBuild: [Property])
        case error(diagnostics: [Diagnostic])

        var isError: Bool {
            switch self {
            case .error(_):
                return true
            default:
                return false
            }
        }
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingConformancesOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext) -> [(TypeSyntax, GenericWhereClauseSyntax?)] {
            if !analyze(declaration: declaration, of: node).isError {
                return [
                    (SimpleTypeIdentifierSyntax(name: .identifier("Buildable")).cast(TypeSyntax.self), nil)
                ]
            } else {
                return []
            }
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext) throws -> [DeclSyntax] {
            switch analyze(declaration: declaration, of: node) {
            case let .struct(structDecl, propertiesToBuild):
                return try createDecls(from: propertiesToBuild, containerIdentifier: structDecl.identifier)
            case let .error(diagnostics):
                diagnostics.forEach(context.diagnose(_:))
                return []
            }
        }

    private static func analyze(declaration: some DeclGroupSyntax, of node: AttributeSyntax) -> DeclAnalysisResponse {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            return .error(diagnostics: [
                Diagnostic(node: node.cast(Syntax.self), message: AutoBuilderDiagnostic.invalidTypeForAutoBuilder)
            ])
        }
        let storedProperties = VariableHelper.getStoredProperties(from: structDecl.memberBlock.members)
        let impliedTypeVariableProperties = storedProperties.filter({ $0.bindingKeyword == .var && $0.variableType.isImplicit })
        let diagnostics = impliedTypeVariableProperties.map({ property in
            return Diagnostic(
                node: property.identifierPattern.cast(Syntax.self),
                message: AutoBuilderDiagnostic.impliedVariableType(identifier: property.identifier))
        })
        if diagnostics.isEmpty {
            let propertiesToBuild = storedProperties.filter({ $0.isIVar && !$0.isInitializedConstant })
            return .struct(structDecl: structDecl, propertiesToBuild: propertiesToBuild)
        } else {
            return .error(diagnostics: diagnostics)
        }
    }

    // MARK: - Create Syntax Tokens

    private static func createDecls(from properties: [Property], containerIdentifier: TokenSyntax) throws -> [DeclSyntax] {
        return [
            try InitializerDeclSyntax("init(with builder: Builder) throws", bodyBuilder: {
                for property in properties {
                    createPropertyInitializer(from: property)
                }
            }).cast(DeclSyntax.self),
            try createToBuilderFunction(from: properties).cast(DeclSyntax.self),
            try ClassDeclSyntax("class Builder: BuilderProtocol", membersBuilder: {
                for property in properties {
                    createVariableDecl(from: property)
                }
                try InitializerDeclSyntax("required init()", bodyBuilder: {
                    for property in properties {
                        createBuildablePropertyInitializer(from: property)
                    }
                })
                for property in properties {
                    switch property.variableType {
                    case let .array(elementType):
                        try createSetValueFunction(from: property)
                        try createAppendElementFunction(from: property, elementType: elementType)
                        try createAppendCollectionFunction(from: property, elementType: elementType)
                        try createRemoveAllFunction(from: property)
                    case let .dictionary(keyType, valueType):
                        try createSetValueFunction(from: property)
                        try createInsertDictionaryFunction(from: property, keyType: keyType, valueType: valueType)
                        try createMergeDictionaryFunction(from: property, keyType: keyType, valueType: valueType)
                        try createRemoveAllFunction(from: property)
                    case let .set(elementType):
                        try createSetValueFunction(from: property)
                        try createInsertSetFunction(from: property, elementType: elementType)
                        try createFormUnionSetFunction(from: property, elementType: elementType)
                        try createRemoveAllFunction(from: property)
                    case .implicit, .explicit(_):
                        try createSetValueFunction(from: property)
                    }
                }
                try createBuildFunction(containerIdentifier: containerIdentifier)
            }).cast(DeclSyntax.self)
        ]
    }

    private static func createPropertyInitializer(from property: Property) -> SequenceExprSyntax {
        let builderIdentifier = IdentifierExprSyntax(identifier: TokenSyntax(.identifier("builder"), presence: .present))
        let propertyMemberExpr = MemberAccessExprSyntax(base: builderIdentifier, name: TokenSyntax(.identifier(property.identifier), presence: .present))
        let buildMemberExpr = MemberAccessExprSyntax(base: propertyMemberExpr, name: "build")
        let buildFunctionCall = FunctionCallExprSyntax(calledExpression: buildMemberExpr, leftParen: .leftParenToken(), rightParen: .rightParenToken()) {}
        return SequenceExprSyntax {
            IdentifierExprSyntax(identifier: .identifier(property.identifier))
            AssignmentExprSyntax()
            if property.variableType.isCollection {
                buildFunctionCall
            } else {
                TryExprSyntax(expression: buildFunctionCall)
            }
        }
    }

    private static func createToBuilderFunction(from properties: [Property]) throws -> FunctionDeclSyntax {
        return try FunctionDeclSyntax("func toBuilder() -> Builder") {
            VariableDeclSyntax(
                .let,
                name: IdentifierPatternSyntax(identifier: .identifier("builder")).cast(PatternSyntax.self),
                initializer: InitializerClauseSyntax(
                    value: FunctionCallExprSyntax(
                        calledExpression: IdentifierExprSyntax(identifier: .identifier("Builder")),
                        leftParen: .leftParenToken(),
                        argumentList: TupleExprElementListSyntax([]),
                        rightParen: .rightParenToken())))
            for property in properties {
                FunctionCallExprSyntax(
                    calledExpression: MemberAccessExprSyntax(
                        base: IdentifierExprSyntax(identifier: .identifier("builder")),
                        name: .identifier("set")),
                    leftParen: .leftParenToken(),
                    rightParen: .rightParenToken()) {
                        TupleExprElementSyntax(
                            label: .identifier(property.identifier),
                            colon: .colonToken(),
                            expression: IdentifierExprSyntax(identifier: .identifier(property.identifier)))
                    }
            }
            ReturnStmtSyntax(expression: IdentifierExprSyntax(identifier: .identifier("builder")))
        }
    }

    private static func createVariableDecl(from property: Property) -> VariableDeclSyntax {
        let bindingKeyword = TokenSyntax(.keyword(.let), presence: .present)
        let identifierPattern = IdentifierPatternSyntax(identifier: .identifier(property.identifier))
        let typeIdentifier = switch property.variableType {
        case .implicit: ""
        case let .array(elementType): "BuildableArrayProperty<\(elementType.trimmed.description)>"
        case let .dictionary(keyType, valueType): "BuildableDictionaryProperty<\(keyType.trimmed.description), \(valueType.trimmed.description)>"
        case let .set(elementType): "BuildableSetProperty<\(elementType.trimmed.description)>"
        case let .explicit(typeNode): "BuildableProperty<\(typeNode.trimmed.description)>"
        }
        let typeAnnotation = TypeAnnotationSyntax(
            type: SimpleTypeIdentifierSyntax(
                name: TokenSyntax(.identifier(typeIdentifier), presence: .present)))
        return VariableDeclSyntax(bindingKeyword: bindingKeyword) {
            PatternBindingListSyntax {
                PatternBindingSyntax(pattern: identifierPattern, typeAnnotation: typeAnnotation)
            }
        }
    }

    private static func createBuildablePropertyInitializer(from property: Property) -> CodeBlockItemSyntax {
        let typeIdentifier = switch property.variableType {
        case .implicit: ""
        case .array(_): "BuildableArrayProperty"
        case .dictionary(_, _): "BuildableDictionaryProperty"
        case .set(_): "BuildableSetProperty"
        case .explicit(_): "BuildableProperty"
        }
        let initExpression = IdentifierExprSyntax(identifier: TokenSyntax(.identifier(typeIdentifier), presence: .present))
        return CodeBlockItemSyntax(item: CodeBlockItemSyntax.Item(SequenceExprSyntax(elementsBuilder: {
            IdentifierExprSyntax(identifier: .identifier(property.identifier))
            AssignmentExprSyntax()
            FunctionCallExprSyntax(calledExpression: initExpression, leftParen: .leftParenToken(), rightParen: .rightParenToken()) {
                if !property.variableType.isCollection {
                    TupleExprElementSyntax(label: "name", expression: StringLiteralExprSyntax(content: property.identifier))
                }
            }
        })))
    }

    private static func createSetValueFunction(from property: Property) throws -> FunctionDeclSyntax {
        let selfIdentifier = IdentifierExprSyntax(identifier: .keyword(.`self`))
        let selfExpression = MemberAccessExprSyntax(base: selfIdentifier, name: TokenSyntax(.identifier(property.identifier), presence: .present))
        let setValueExpression = MemberAccessExprSyntax(base: selfExpression, name: TokenSyntax(.identifier("set"), presence: .present))
        return try FunctionDeclSyntax("@discardableResult\nfunc set(\(raw: property.identifier): \(raw: property.type)) -> Builder") {
            FunctionCallExprSyntax(calledExpression: setValueExpression, leftParen: .leftParenToken(), rightParen: .rightParenToken()) {
                TupleExprElementSyntax(label: "value", expression: IdentifierExprSyntax(identifier: .identifier(property.identifier)))
            }
            ReturnStmtSyntax(expression: IdentifierExprSyntax(identifier: .keyword(.`self`)))
        }
    }

    private static func createAppendElementFunction(from property: Property, elementType: TypeSyntax) throws -> FunctionDeclSyntax {
        let elementTypeString = elementType.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let selfIdentifier = IdentifierExprSyntax(identifier: .keyword(.`self`))
        let selfExpression = MemberAccessExprSyntax(base: selfIdentifier, name: TokenSyntax(.identifier(property.identifier), presence: .present))
        let appendElementExpression = MemberAccessExprSyntax(base: selfExpression, name: TokenSyntax(.identifier("append"), presence: .present))
        return try FunctionDeclSyntax("@discardableResult\nfunc appendTo(\(raw: property.identifier) element: \(raw: elementTypeString)) -> Builder") {
            FunctionCallExprSyntax(calledExpression: appendElementExpression, leftParen: .leftParenToken(), rightParen: .rightParenToken()) {
                TupleExprElementSyntax(label: "element", expression: IdentifierExprSyntax(identifier: .identifier("element")))
            }
            ReturnStmtSyntax(expression: IdentifierExprSyntax(identifier: .keyword(.`self`)))
        }
    }

    private static func createAppendCollectionFunction(from property: Property, elementType: TypeSyntax) throws -> FunctionDeclSyntax {
        let elementTypeString = elementType.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let selfIdentifier = IdentifierExprSyntax(identifier: .keyword(.`self`))
        let selfExpression = MemberAccessExprSyntax(base: selfIdentifier, name: TokenSyntax(.identifier(property.identifier), presence: .present))
        let appendCollectionExpression = MemberAccessExprSyntax(base: selfExpression, name: TokenSyntax(.identifier("append"), presence: .present))
        return try FunctionDeclSyntax("@discardableResult\nfunc appendTo<C>(\(raw: property.identifier) collection: C) -> Builder where C: Collection, C.Element == \(raw: elementTypeString)") {
            FunctionCallExprSyntax(calledExpression: appendCollectionExpression, leftParen: .leftParenToken(), rightParen: .rightParenToken()) {
                TupleExprElementSyntax(label: "contentsOf", expression: IdentifierExprSyntax(identifier: .identifier("collection")))
            }
            ReturnStmtSyntax(expression: IdentifierExprSyntax(identifier: .keyword(.`self`)))
        }
    }

    private static func createInsertDictionaryFunction(from property: Property, keyType: TypeSyntax, valueType: TypeSyntax) throws -> FunctionDeclSyntax {
        let insertExpression = MemberAccessExprSyntax(
            base: IdentifierExprSyntax(identifier: .identifier(property.identifier)),
            name: TokenSyntax(.identifier("insert"), presence: .present))
        return try FunctionDeclSyntax("@discardableResult\nfunc insertInto\(raw: property.capitalizedIdentifier)(key: \(raw: keyType.trimmed.description), value: \(raw: valueType.trimmed.description)) -> Builder") {
            FunctionCallExprSyntax(calledExpression: insertExpression, leftParen: .leftParenToken(), rightParen: .rightParenToken()) {
                TupleExprElementSyntax(label: "key", expression: IdentifierExprSyntax(identifier: .identifier("key")))
                TupleExprElementSyntax(label: "value", expression: IdentifierExprSyntax(identifier: .identifier("value")))
            }
            ReturnStmtSyntax(expression: IdentifierExprSyntax(identifier: .keyword(.`self`)))
        }
    }

    private static func createMergeDictionaryFunction(from property: Property, keyType: TypeSyntax, valueType: TypeSyntax) throws -> FunctionDeclSyntax {
        let keyText = keyType.trimmed.description
        let valueText = valueType.trimmed.description
        let mergeExpression = MemberAccessExprSyntax(
            base: IdentifierExprSyntax(identifier: .identifier(property.identifier)),
            name: TokenSyntax(.identifier("merge"), presence: .present))
        return try FunctionDeclSyntax("@discardableResult\nfunc mergeInto\(raw: property.capitalizedIdentifier)(other: [\(raw: keyText): \(raw: valueText)], uniquingKeysWith combine: (\(raw: valueText), \(raw: valueText)) throws -> \(raw: valueText)) rethrows -> Builder") {
            TryExprSyntax(
                expression: FunctionCallExprSyntax(calledExpression: mergeExpression, leftParen: .leftParenToken(), rightParen: .rightParenToken()) {
                    TupleExprElementSyntax(label: "other", expression: IdentifierExprSyntax(identifier: .identifier("other")))
                    TupleExprElementSyntax(label: "uniquingKeysWith", expression: IdentifierExprSyntax(identifier: .identifier("combine")))
                })
            ReturnStmtSyntax(expression: IdentifierExprSyntax(identifier: .keyword(.`self`)))
        }
    }

    private static func createInsertSetFunction(from property: Property, elementType: TypeSyntax) throws -> FunctionDeclSyntax {
        let insertExpression = MemberAccessExprSyntax(
            base: IdentifierExprSyntax(identifier: .identifier(property.identifier)),
            name: TokenSyntax(.identifier("insert"), presence: .present))
        return try FunctionDeclSyntax("@discardableResult\nfunc insertInto(\(raw: property.identifier) element: \(elementType.trimmed)) -> Builder") {
            FunctionCallExprSyntax(calledExpression: insertExpression, leftParen: .leftParenToken(), rightParen: .rightParenToken()) {
                TupleExprElementSyntax(label: "element", expression: IdentifierExprSyntax(identifier: .identifier("element")))
            }
            ReturnStmtSyntax(expression: IdentifierExprSyntax(identifier: .keyword(.`self`)))
        }
    }

    private static func createFormUnionSetFunction(from property: Property, elementType: TypeSyntax) throws -> FunctionDeclSyntax {
        let formUnionExpression = MemberAccessExprSyntax(
            base: IdentifierExprSyntax(identifier: .identifier(property.identifier)),
            name: TokenSyntax(.identifier("formUnion"), presence: .present))
        return try FunctionDeclSyntax("@discardableResult\nfunc formUnionWith\(raw: property.capitalizedIdentifier)(other: Set<\(elementType.trimmed)>) -> Builder") {
            FunctionCallExprSyntax(calledExpression: formUnionExpression, leftParen: .leftParenToken(), rightParen: .rightParenToken()) {
                TupleExprElementSyntax(label: "other", expression: IdentifierExprSyntax(identifier: .identifier("other")))
            }
            ReturnStmtSyntax(expression: IdentifierExprSyntax(identifier: .keyword(.`self`)))
        }
    }

    private static func createRemoveAllFunction(from property: Property) throws -> FunctionDeclSyntax {
        let appendElementExpression = MemberAccessExprSyntax(
            base: IdentifierExprSyntax(identifier: .identifier(property.identifier)),
            name: TokenSyntax(.identifier("removeAll"), presence: .present))
        return try FunctionDeclSyntax("@discardableResult\nfunc removeAllFrom\(raw: property.capitalizedIdentifier)() -> Builder") {
            FunctionCallExprSyntax(calledExpression: appendElementExpression, leftParen: .leftParenToken(), rightParen: .rightParenToken()) {}
            ReturnStmtSyntax(expression: IdentifierExprSyntax(identifier: .keyword(.`self`)))
        }
    }

    private static func createBuildFunction(containerIdentifier: TokenSyntax) throws -> FunctionDeclSyntax {
        return try FunctionDeclSyntax("func build() throws -> \(raw: containerIdentifier.text)") {
            ReturnStmtSyntax(
                expression: TryExprSyntax(
                    expression: FunctionCallExprSyntax(
                        calledExpression: IdentifierExprSyntax(identifier: .identifier(containerIdentifier.text)),
                        leftParen: .leftParenToken(),
                        rightParen: .rightParenToken()) {
                            TupleExprElementSyntax(label: "with", expression: IdentifierExprSyntax(identifier: .keyword(.self)))
                        }))
        }
    }
}

@main
struct AutoBuilderPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        AutoBuilderMacro.self,
    ]
}
