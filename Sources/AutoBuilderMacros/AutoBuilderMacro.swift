import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

public struct AutoBuilderMacro: MemberMacro, ConformanceMacro {
    private enum DeclAnalysisResponse {
        case `struct`(structDecl: StructDeclSyntax, propertiesToBuild: [Property])
        case `enum`(enumDecl: EnumDeclSyntax, cases: [EnumUnionCase])
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
            if !analyze(declaration: declaration, of: node).response.isError {
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
            let (response, nonFatalDiagnostics) = analyze(declaration: declaration, of: node)
            nonFatalDiagnostics.forEach(context.diagnose(_:))
            switch response {
            case let .struct(structDecl, propertiesToBuild):
                let isPublic = hasPublic(modifiers: structDecl.modifiers)
                return try createStructDecls(from: propertiesToBuild, containerIdentifier: structDecl.identifier, isPublic: isPublic)
            case let .enum(enumDecl, cases):
                let isPublic = hasPublic(modifiers: enumDecl.modifiers)
                return try createEnumDecls(from: cases, containerIdentifier: enumDecl.identifier, isPublic: isPublic)
            case let .error(diagnostics):
                diagnostics.forEach(context.diagnose(_:))
                return []
            }
        }

    private static func analyze(declaration: some DeclGroupSyntax, of node: AttributeSyntax) -> (response: DeclAnalysisResponse, nonErrorDiagnostics: [Diagnostic]) {
        if let structDecl = declaration.as(StructDeclSyntax.self) {
            let storedProperties = VariableHelper.getProperties(from: structDecl.memberBlock.members)
            let impliedTypeVariableProperties = storedProperties.filter({ $0.bindingKeyword == .var && $0.variableType.isImplicit })
            let diagnostics = impliedTypeVariableProperties.map({ property in
                return Diagnostic(
                    node: property.identifierPattern.cast(Syntax.self),
                    message: AutoBuilderDiagnostic.impliedVariableType(identifier: property.identifier))
            })
            if diagnostics.isEmpty {
                let propertiesToBuild = storedProperties.filter({ $0.isStoredProperty && $0.isIVar && !$0.isInitializedConstant })
                return (.struct(structDecl: structDecl, propertiesToBuild: propertiesToBuild), [])
            } else {
                return (.error(diagnostics: diagnostics), [])
            }
        } else if let enumDecl = declaration.as(EnumDeclSyntax.self) {
            let cases = EnumHelper.getCases(from: enumDecl.memberBlock.members)
            var diagnostics: [Diagnostic] = []
            let hasAssociatedValues = cases.contains(where: { !$0.associatedValues.isEmpty })
            if !hasAssociatedValues {
                diagnostics.append(Diagnostic(
                    node: enumDecl.cast(Syntax.self),
                    message: AutoBuilderDiagnostic.noAssociatedValues(enumName: enumDecl.identifier.trimmedDescription)))
            }
            return (.enum(enumDecl: enumDecl, cases: cases), diagnostics)
        } else {
            return (.error(diagnostics: [
                Diagnostic(node: node.cast(Syntax.self), message: AutoBuilderDiagnostic.invalidTypeForAutoBuilder)
            ]), [])
        }
    }

    private static func hasPublic(modifiers: ModifierListSyntax?) -> Bool {
        return modifiers?.contains(where: { modifier in
            modifier.name.tokenKind == .keyword(.public) || modifier.name.tokenKind == .keyword(.open)
        }) ?? false
    }

    // MARK: - Create Struct Syntax Tokens

    private static func createStructDecls(from properties: [Property], containerIdentifier: TokenSyntax, isPublic: Bool) throws -> [DeclSyntax] {
        let accessModifier = isPublic ? "public " : ""
        return [
            try InitializerDeclSyntax("\(raw: accessModifier)init(with builder: Builder) throws", bodyBuilder: {
                for property in properties {
                    createPropertyInitializer(from: property)
                }
            }).cast(DeclSyntax.self),
            try createToBuilderFunction(from: properties, isPublic: isPublic).cast(DeclSyntax.self),
            try createBuilderClass(from: properties, containerIdentifier: containerIdentifier).cast(DeclSyntax.self)
        ]
    }

    private static func createPropertyInitializer(from property: Property) -> SequenceExprSyntax {
        let builderIdentifier = IdentifierExprSyntax(identifier: TokenSyntax(.identifier("builder"), presence: .present))
        let propertyMemberExpr = MemberAccessExprSyntax(base: builderIdentifier, name: TokenSyntax(.identifier(property.identifier), presence: .present))
        let buildMemberExpr = MemberAccessExprSyntax(base: propertyMemberExpr, name: "build")
        let buildFunctionCall = functionCallExpr(buildMemberExpr)
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

    private static func createToBuilderFunction(from properties: [Property], isPublic: Bool) throws -> FunctionDeclSyntax {
        let accessModifier = isPublic ? "public " : ""
        return try FunctionDeclSyntax("\(raw: accessModifier)func toBuilder() -> Builder") {
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

    // MARK: - Create Enum Syntax Tokens

    private static func createEnumDecls(from cases: [EnumUnionCase], containerIdentifier: TokenSyntax, isPublic: Bool) throws -> [DeclSyntax] {
        let accessModifier = isPublic ? "public " : ""
        return [
            try InitializerDeclSyntax("\(raw: accessModifier)init(with builder: Builder) throws", bodyBuilder: {
                CodeBlockItemSyntax(item: CodeBlockItemSyntax.Item(SequenceExprSyntax(elementsBuilder: {
                    IdentifierExprSyntax(identifier: .keyword(.`self`))
                    AssignmentExprSyntax()
                    functionCallExpr(MemberAccessExprSyntax(
                        base: IdentifierExprSyntax(identifier: .identifier("builder")),
                        name: .identifier("build")))
                })))
            }).cast(DeclSyntax.self),
            try createEnumToBuilderFunction(from: cases, isPublic: isPublic).cast(DeclSyntax.self)
        ]
    }

    private static func createEnumToBuilderFunction(from cases: [EnumUnionCase], isPublic: Bool) throws -> FunctionDeclSyntax {
        let accessModifier = isPublic ? "public " : ""
        return try FunctionDeclSyntax("\(raw: accessModifier)func toBuilder() -> Builder") {
            VariableDeclSyntax(
                .let,
                name: IdentifierPatternSyntax(identifier: .identifier("builder")).cast(PatternSyntax.self),
                initializer: InitializerClauseSyntax(
                    value: functionCallExpr(IdentifierExprSyntax(identifier: .identifier("Builder")))))
            try SwitchExprSyntax("switch self") {
                for enumCase in cases {
                    createEnumToBuilderCase(for: enumCase)
                }
            }
            ReturnStmtSyntax(expression: IdentifierExprSyntax(identifier: .identifier("builder")))
        }
    }

    private static func createEnumToBuilderCase(for enumCase: EnumUnionCase) -> SwitchCaseSyntax {
        let valueIdentifiers = enumCase.associatedValues.enumerated().map({ (index, property) in
            if property.identifier.isEmpty {
                return "i\(index)"
            } else {
                return property.identifier
            }
        })
        let caseBuilderIdentifier = TokenSyntax.identifier("\(enumCase.caseIdentifier)Builder")
        return SwitchCaseSyntax("case let .\(raw: enumCase.caseIdentifier)(\(raw: valueIdentifiers.joined(separator: ", "))):") {
            VariableDeclSyntax(
                .let,
                name: IdentifierPatternSyntax(identifier: caseBuilderIdentifier).cast(PatternSyntax.self),
                initializer: InitializerClauseSyntax(
                    value: MemberAccessExprSyntax(
                        base: IdentifierExprSyntax(identifier: .identifier("builder")),
                        name: .identifier("\(enumCase.caseIdentifier)"))))
            for property in enumCase.associatedValues {
                functionCallExpr(MemberAccessExprSyntax(
                    base: IdentifierExprSyntax(identifier: caseBuilderIdentifier),
                    name: .identifier("set")), [
                        (property.identifier, property.identifier)
                    ])
            }
        }
    }

    // MARK: - Create Builder Class Syntax Tokens

    private static func createBuilderClass(from properties: [Property], named builderClassName: String = "Builder", containerIdentifier: TokenSyntax) throws -> ClassDeclSyntax {
        return try ClassDeclSyntax("public class \(raw: builderClassName): BuilderProtocol", membersBuilder: {
            for property in properties {
                createVariableDecl(from: property)
            }
            try InitializerDeclSyntax("public required init()", bodyBuilder: {
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
        })
    }

    private static func createVariableDecl(from property: Property) -> VariableDeclSyntax {
        let modifiers = ModifierListSyntax {
            DeclModifierSyntax(name: .keyword(.public))
        }
        let bindingKeyword = TokenSyntax(.keyword(.let), presence: .present)
        let identifierPattern = IdentifierPatternSyntax(identifier: .identifier(property.identifier))
        let typeIdentifier = switch property.variableType {
        case .implicit: ""
        case let .array(elementType): "BuildableArrayProperty<\(elementType.trimmedDescription)>"
        case let .dictionary(keyType, valueType): "BuildableDictionaryProperty<\(keyType.trimmedDescription), \(valueType.trimmedDescription)>"
        case let .set(elementType): "BuildableSetProperty<\(elementType.trimmedDescription)>"
        case let .explicit(typeNode): "BuildableProperty<\(typeNode.trimmedDescription)>"
        }
        let typeAnnotation = TypeAnnotationSyntax(
            type: SimpleTypeIdentifierSyntax(
                name: TokenSyntax(.identifier(typeIdentifier), presence: .present)))
        return VariableDeclSyntax(modifiers: modifiers, bindingKeyword: bindingKeyword) {
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
        return try FunctionDeclSyntax("@discardableResult\npublic func set(\(raw: property.identifier): \(raw: property.type)) -> Builder") {
            functionCallExpr(setValueExpression, [("value", property.identifier)])
            returnSelfStmt()
        }
    }

    private static func createAppendElementFunction(from property: Property, elementType: TypeSyntax) throws -> FunctionDeclSyntax {
        let selfIdentifier = IdentifierExprSyntax(identifier: .keyword(.`self`))
        let selfExpression = MemberAccessExprSyntax(base: selfIdentifier, name: TokenSyntax(.identifier(property.identifier), presence: .present))
        let appendElementExpression = MemberAccessExprSyntax(base: selfExpression, name: TokenSyntax(.identifier("append"), presence: .present))
        return try FunctionDeclSyntax("@discardableResult\npublic func appendTo(\(raw: property.identifier) element: \(elementType.trimmed)) -> Builder") {
            functionCallExpr(appendElementExpression, [("element", "element")])
            returnSelfStmt()
        }
    }

    private static func createAppendCollectionFunction(from property: Property, elementType: TypeSyntax) throws -> FunctionDeclSyntax {
        let selfIdentifier = IdentifierExprSyntax(identifier: .keyword(.`self`))
        let selfExpression = MemberAccessExprSyntax(base: selfIdentifier, name: TokenSyntax(.identifier(property.identifier), presence: .present))
        let appendCollectionExpression = MemberAccessExprSyntax(base: selfExpression, name: TokenSyntax(.identifier("append"), presence: .present))
        return try FunctionDeclSyntax("@discardableResult\npublic func appendTo<C>(\(raw: property.identifier) collection: C) -> Builder where C: Collection, C.Element == \(elementType.trimmed)") {
            functionCallExpr(appendCollectionExpression, [("contentsOf", "collection")])
            returnSelfStmt()
        }
    }

    private static func createInsertDictionaryFunction(from property: Property, keyType: TypeSyntax, valueType: TypeSyntax) throws -> FunctionDeclSyntax {
        let insertExpression = MemberAccessExprSyntax(
            base: IdentifierExprSyntax(identifier: .identifier(property.identifier)),
            name: TokenSyntax(.identifier("insert"), presence: .present))
        return try FunctionDeclSyntax("@discardableResult\npublic func insertInto(\(raw: property.identifier) value: \(valueType.trimmed), forKey key: \(keyType.trimmed)) -> Builder") {
            functionCallExpr(insertExpression, [("key", "key"), ("value", "value")])
            returnSelfStmt()
        }
    }

    private static func createMergeDictionaryFunction(from property: Property, keyType: TypeSyntax, valueType: TypeSyntax) throws -> FunctionDeclSyntax {
        let mergeExpression = MemberAccessExprSyntax(
            base: IdentifierExprSyntax(identifier: .identifier(property.identifier)),
            name: TokenSyntax(.identifier("merge"), presence: .present))
        return try FunctionDeclSyntax("@discardableResult\npublic func mergeInto\(raw: property.capitalizedIdentifier)(other: [\(keyType.trimmed): \(valueType.trimmed)], uniquingKeysWith combine: (\(valueType.trimmed), \(valueType.trimmed)) throws -> \(valueType.trimmed)) rethrows -> Builder") {
            TryExprSyntax(expression: functionCallExpr(mergeExpression, [("other", "other"), ("uniquingKeysWith", "combine")]))
            returnSelfStmt()
        }
    }

    private static func createInsertSetFunction(from property: Property, elementType: TypeSyntax) throws -> FunctionDeclSyntax {
        let insertExpression = MemberAccessExprSyntax(
            base: IdentifierExprSyntax(identifier: .identifier(property.identifier)),
            name: TokenSyntax(.identifier("insert"), presence: .present))
        return try FunctionDeclSyntax("@discardableResult\npublic func insertInto(\(raw: property.identifier) element: \(elementType.trimmed)) -> Builder") {
            functionCallExpr(insertExpression, [("element", "element")])
            returnSelfStmt()
        }
    }

    private static func createFormUnionSetFunction(from property: Property, elementType: TypeSyntax) throws -> FunctionDeclSyntax {
        let formUnionExpression = MemberAccessExprSyntax(
            base: IdentifierExprSyntax(identifier: .identifier(property.identifier)),
            name: TokenSyntax(.identifier("formUnion"), presence: .present))
        return try FunctionDeclSyntax("@discardableResult\npublic func formUnionWith\(raw: property.capitalizedIdentifier)(other: Set<\(elementType.trimmed)>) -> Builder") {
            functionCallExpr(formUnionExpression, [("other", "other")])
            returnSelfStmt()
        }
    }

    private static func createRemoveAllFunction(from property: Property) throws -> FunctionDeclSyntax {
        let appendElementExpression = MemberAccessExprSyntax(
            base: IdentifierExprSyntax(identifier: .identifier(property.identifier)),
            name: TokenSyntax(.identifier("removeAll"), presence: .present))
        return try FunctionDeclSyntax("@discardableResult\npublic func removeAllFrom\(raw: property.capitalizedIdentifier)() -> Builder") {
            functionCallExpr(appendElementExpression)
            returnSelfStmt()
        }
    }

    private static func createBuildFunction(containerIdentifier: TokenSyntax) throws -> FunctionDeclSyntax {
        return try FunctionDeclSyntax("public func build() throws -> \(raw: containerIdentifier.text)") {
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

    // MARK: - Util

    private static func functionCallExpr(_ calledExpression: ExprSyntaxProtocol, _ arguments: [(label: String?, identifier: String)] = []) -> FunctionCallExprSyntax {
        FunctionCallExprSyntax(calledExpression: calledExpression, leftParen: .leftParenToken(), rightParen: .rightParenToken()) {
            for arg in arguments {
                TupleExprElementSyntax(label: arg.label, expression: IdentifierExprSyntax(identifier: .identifier(arg.identifier)))
            }
        }
    }

    private static func returnSelfStmt() -> ReturnStmtSyntax {
        return ReturnStmtSyntax(expression: IdentifierExprSyntax(identifier: .keyword(.`self`)))
    }
}

@main
struct AutoBuilderPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        AutoBuilderMacro.self,
    ]
}
