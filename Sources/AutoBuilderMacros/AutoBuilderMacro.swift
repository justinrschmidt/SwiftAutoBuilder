import SwiftCompilerPlugin
import Foundation
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
                return try createEnumDecls(
                    from: cases,
                    clientIdentifier: enumDecl.identifier.trimmed,
                    isPublic: isPublic,
                    in: context)
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
            var errorDiagnostics: [Diagnostic] = []
            if cases.isEmpty {
                errorDiagnostics.append(Diagnostic(
                    node: enumDecl.cast(Syntax.self),
                    message: AutoBuilderDiagnostic.enumWithNoCases(enumName: enumDecl.identifier.trimmedDescription)))
            }
            let overloadedCases = getOverloadedCases(cases)
            if !overloadedCases.isEmpty {
                errorDiagnostics.append(Diagnostic(
                    node: enumDecl.cast(Syntax.self),
                    message: AutoBuilderDiagnostic.enumWithOverloadedCases(overloadedCases: overloadedCases)))
            }
            errorDiagnostics += getInvalidAssociatedValueLabelsDiagnostics(cases)
            if !errorDiagnostics.isEmpty {
                return (.error(diagnostics: errorDiagnostics), [])
            }
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

    private static func getOverloadedCases(_ cases: [EnumUnionCase]) -> [String] {
        var caseIdentifiers: Set<String> = []
        var overloadedCases: Set<String> = []
        var overloadedCasesList: [String] = []
        for enumCase in cases {
            if caseIdentifiers.contains(enumCase.caseIdentifier) {
                if !overloadedCases.contains(enumCase.caseIdentifier) {
                    overloadedCases.insert(enumCase.caseIdentifier)
                    overloadedCasesList.append(enumCase.caseIdentifier)
                }
            } else {
                caseIdentifiers.insert(enumCase.caseIdentifier)
            }
        }
        return Array(overloadedCases)
    }

    private static func getInvalidAssociatedValueLabelsDiagnostics(_ cases: [EnumUnionCase]) -> [Diagnostic] {
        let regex = try! NSRegularExpression(pattern: "^index_[0-9]+$", options: [.caseInsensitive])
        var diagnostics: [Diagnostic] = []
        for enumCase in cases {
            for value in enumCase.associatedValues {
                if case let .identifierPattern(pattern) = value.label {
                    let label = pattern.identifier.text
                    let range = NSRange(label.startIndex..., in: label)
                    if regex.numberOfMatches(in: pattern.identifier.text, options: [], range: range) > 0 {
                        diagnostics.append(Diagnostic(
                            node: value.firstNameToken!.cast(Syntax.self),
                            message: AutoBuilderDiagnostic.invalidEnumAssociatedValueLabel))
                    }
                }
            }
        }
        return diagnostics
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
            try createBuilderClass(
                from: properties,
                containerIdentifier: containerIdentifier,
                buildFunction: createStructBuildFunction(containerIdentifier: containerIdentifier)
            ).cast(DeclSyntax.self)
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

    private static func createStructBuildFunction(containerIdentifier: TokenSyntax) throws -> FunctionDeclSyntax {
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

    // MARK: - Create Enum Syntax Tokens

    private static func createEnumDecls(
        from cases: [EnumUnionCase],
        clientIdentifier: TokenSyntax,
        isPublic: Bool,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let accessModifier = isPublic ? "public " : ""
        return [
            try InitializerDeclSyntax("\(raw: accessModifier)init(with builder: Builder) throws", bodyBuilder: {
                CodeBlockItemSyntax(stringLiteral: "self = try builder.build()")
            }).cast(DeclSyntax.self),
            try createEnumToBuilderFunction(from: cases, isPublic: isPublic).cast(DeclSyntax.self),
            try createEnumBuilderClass(from: cases, clientIdentifier: clientIdentifier, in: context).cast(DeclSyntax.self)
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
        let caseBuilderIdentifier = TokenSyntax.identifier("\(enumCase.caseIdentifier)Builder")
        let caseDeclaration: String
        if enumCase.associatedValues.isEmpty {
            caseDeclaration = "case .\(enumCase.caseIdentifier):"
        } else {
            caseDeclaration = "case let .\(enumCase.caseIdentifier)(\(enumCase.valueIdentifiers.joined(separator: ", "))):"
        }
        return SwitchCaseSyntax("\(raw: caseDeclaration)") {
            if enumCase.associatedValues.isEmpty {
                CodeBlockItemSyntax(stringLiteral: "_ = builder.\(enumCase.caseIdentifier)")
            } else {
                CodeBlockItemSyntax(stringLiteral: "let \(caseBuilderIdentifier) = builder.\(enumCase.caseIdentifier)")
                for value in enumCase.associatedValues {
                    switch value.label {
                    case let .identifierPattern(pattern):
                        CodeBlockItemSyntax(stringLiteral: "\(caseBuilderIdentifier).set(\(pattern.identifier.text): \(pattern.identifier.text))")
                    case let .index(index):
                        CodeBlockItemSyntax(stringLiteral: "\(caseBuilderIdentifier).set(index_\(index): i\(index))")
                    }
                }
            }
        }
    }

    private static func createEnumBuilderClass(
        from cases: [EnumUnionCase],
        clientIdentifier: TokenSyntax,
        in context: some MacroExpansionContext
    ) throws -> ClassDeclSyntax {
        return try ClassDeclSyntax("public class Builder: BuilderProtocol") {
            VariableDeclSyntax(
                modifiers: ModifierListSyntax(arrayLiteral: DeclModifierSyntax(name: .keyword(.private))),
                .var,
                name: IdentifierPatternSyntax(identifier: .identifier("currentCase")).cast(PatternSyntax.self),
                type: TypeAnnotationSyntax(type: OptionalTypeSyntax(wrappedType: SimpleTypeIdentifierSyntax(name: .identifier("BuilderCases")))))
            try InitializerDeclSyntax("public required init()") {
                CodeBlockItemSyntax(stringLiteral: "currentCase = nil")
            }
            for enumCase in cases {
                let caseIdentifier = enumCase.caseIdentifier
                try createCaseBuilderComputedProperty(named: caseIdentifier, builderCase: caseIdentifier, builderClassName: caseIdentifier.capitalized)
            }
            try createEnumSetValueFunction(from: cases, clientIdentifier: clientIdentifier)
            try createEnumBuildFunction(from: cases, clientIdentifier: clientIdentifier)
            for enumCase in cases {
                try createEnumCaseBuilderClass(from: enumCase, clientIdentifier: clientIdentifier, in: context)
            }
            try createBuilderCasesEnum(from: cases.map({ $0.caseIdentifier }))
        }
    }

    private static func createCaseBuilderComputedProperty(named propertyName: String, builderCase: String, builderClassName: String) throws -> VariableDeclSyntax {
        return VariableDeclSyntax(
            modifiers: ModifierListSyntax(arrayLiteral: DeclModifierSyntax(name: .keyword(.public))),
            bindingKeyword: .keyword(.var),
            bindings: try PatternBindingListSyntax(itemsBuilder: {
                PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(identifier: .identifier(propertyName)),
                    typeAnnotation: TypeAnnotationSyntax(type: SimpleTypeIdentifierSyntax(name: .identifier(builderClassName))),
                    accessor: try .accessors(AccessorBlockSyntax(accessors: AccessorListSyntax(itemsBuilder: {
                        try createCaseBuilderGetter(builderCase: builderCase, builderClassName: builderClassName)
                        AccessorDeclSyntax(accessorKind: .keyword(.set)) {
                            CodeBlockItemSyntax(item: CodeBlockItemSyntax.Item(SequenceExprSyntax(elementsBuilder: {
                                IdentifierExprSyntax(identifier: .identifier("currentCase"))
                                AssignmentExprSyntax()
                                functionCallExpr(
                                    MemberAccessExprSyntax(name: .identifier(builderCase)),
                                    [(nil, "newValue")])
                            })))
                        }
                    }))))
            }))
    }

    private static func createCaseBuilderGetter(builderCase: String, builderClassName: String) throws -> AccessorDeclSyntax {
        return try AccessorDeclSyntax(accessorKind: .keyword(.get)) {
            try SwitchExprSyntax("switch currentCase") {
                SwitchCaseSyntax("case let .some(.\(raw: builderCase)(builder)):") {
                    CodeBlockItemSyntax(stringLiteral: "return builder")
                }
                SwitchCaseSyntax("default:") {
                    CodeBlockItemSyntax(stringLiteral: "let builder = \(builderClassName)()")
                    CodeBlockItemSyntax(stringLiteral: "currentCase = .\(builderCase)(builder)")
                    CodeBlockItemSyntax(stringLiteral: "return builder")
                }
            }
        }
    }

    private static func createEnumSetValueFunction(from cases: [EnumUnionCase], clientIdentifier: TokenSyntax) throws -> FunctionDeclSyntax {
        return try FunctionDeclSyntax("public func set(value: \(clientIdentifier.trimmed))") {
            try SwitchExprSyntax("switch value") {
                for enumCase in cases {
                    let caseDeclaration = if enumCase.associatedValues.isEmpty {
                        "case .\(enumCase.caseIdentifier):"
                    } else {
                        "case let .\(enumCase.caseIdentifier)(\(enumCase.valueIdentifiers.joined(separator: ", "))):"
                    }
                    SwitchCaseSyntax("\(raw: caseDeclaration)") {
                        CodeBlockItemSyntax(stringLiteral: "let builder = \(enumCase.capitalizedCaseIdentifier)()")
                        for value in enumCase.associatedValues {
                            switch value.label {
                            case let .identifierPattern(pattern):
                                let identifier = pattern.identifier.text
                                CodeBlockItemSyntax(stringLiteral: "builder.set(\(identifier): \(identifier))")
                            case let .index(index):
                                CodeBlockItemSyntax(stringLiteral: "builder.set(index_\(index): i\(index))")
                            }
                        }
                        CodeBlockItemSyntax(stringLiteral: "currentCase = .\(enumCase.caseIdentifier)(builder)")
                    }
                }
            }
        }
    }

    private static func createEnumBuildFunction(from cases: [EnumUnionCase], clientIdentifier: TokenSyntax) throws -> FunctionDeclSyntax {
        return try FunctionDeclSyntax("public func build() throws -> \(clientIdentifier.trimmed)") {
            try SwitchExprSyntax("switch currentCase") {
                for enumCase in cases {
                    SwitchCaseSyntax("case let .some(.\(raw: enumCase.caseIdentifier)(builder)):") {
                        CodeBlockItemSyntax(stringLiteral: "return try builder.build()")
                    }
                }
                SwitchCaseSyntax("case .none:") {
                    CodeBlockItemSyntax(stringLiteral: "throw BuilderError.noEnumCaseSet")
                }
            }
        }
    }

    private static func createEnumCaseBuilderClass(
        from enumCase: EnumUnionCase,
        clientIdentifier: TokenSyntax,
        in context: some MacroExpansionContext
    ) throws -> ClassDeclSyntax {
        let builderClassName = enumCase.caseIdentifier.capitalized
        return try ClassDeclSyntax("public class \(raw: builderClassName): BuilderProtocol", membersBuilder: {
            for value in enumCase.associatedValues {
                switch value.label {
                case let .identifierPattern(pattern):
                    buildablePropertyVariableDecl(
                        modifierKeywords: [.public],
                        bindingKeyword: .let,
                        identifier: pattern.trimmedDescription,
                        type: value.variableType)
                case let .index(index):
                    buildablePropertyVariableDecl(
                        modifierKeywords: [.public],
                        bindingKeyword: .let,
                        identifier: "index_\(index)",
                        type: value.variableType)
                }
            }
            try InitializerDeclSyntax("public required init()", bodyBuilder: {
                for value in enumCase.associatedValues {
                    switch value.label {
                    case let .identifierPattern(pattern):
                        createBuildablePropertyInitializer(identifier: pattern.identifier.text, variableType: value.variableType)
                    case let .index(index):
                        createBuildablePropertyInitializer(identifier: "index_\(index)", variableType: value.variableType)
                    }
                }
            })
            for value in enumCase.associatedValues {
                switch value.label {
                case let .identifierPattern(pattern):
                    for item in try createSetValueFunctions(
                        identifier: pattern.identifier.text,
                        variableType: value.variableType,
                        returnType: builderClassName
                    ) {
                        item
                    }
                case let .index(index):
                    for item in try createSetValueFunctions(
                        identifier: "index_\(index)",
                        variableType: value.variableType,
                        returnType: builderClassName
                    ) {
                        item
                    }
                }
            }
            try FunctionDeclSyntax("public func build() throws -> \(clientIdentifier)") {
                if enumCase.associatedValues.isEmpty {
                    CodeBlockItemSyntax(stringLiteral: "return .\(enumCase.caseIdentifier)")
                } else {
                    let args = enumCase.associatedValues.map({ value in
                        switch value.label {
                        case let .identifierPattern(pattern):
                            let text = pattern.identifier.text
                            return "\(text): \(text).build()"
                        case let .index(index):
                            return "index_\(index).build()"
                        }
                    }).joined(separator: ", ")
                    let hasFailableBuilders = enumCase.associatedValues.reduce(false, { $0 || variableTypeBuilderCanFail($1.variableType) })
                    if hasFailableBuilders {
                        "return try .\(raw: enumCase.caseIdentifier)(\(raw: args))"
                    } else {
                        "return .\(raw: enumCase.caseIdentifier)(\(raw: args))"
                    }
                }
            }
        })
    }

    private static func createBuilderCasesEnum(from caseIdentifiers: [String]) throws -> EnumDeclSyntax {
        return try EnumDeclSyntax("private enum BuilderCases") {
            for caseIdentifier in caseIdentifiers {
                EnumCaseDeclSyntax {
                    EnumCaseElementSyntax(
                        identifier: .identifier(caseIdentifier),
                        associatedValue: EnumCaseParameterClauseSyntax(parameterList: EnumCaseParameterListSyntax(itemsBuilder: {
                            EnumCaseParameterSyntax(type: SimpleTypeIdentifierSyntax(name: .identifier(caseIdentifier.capitalized)))
                        })))
                }
            }
        }
    }

    // MARK: - Create Builder Class Syntax Tokens

    private static func createBuilderClass(
        from properties: [Property],
        named builderClassName: String = "Builder",
        containerIdentifier: TokenSyntax,
        buildFunction: FunctionDeclSyntax
    ) throws -> ClassDeclSyntax {
        return try ClassDeclSyntax("public class \(raw: builderClassName): BuilderProtocol", membersBuilder: {
            for property in properties {
                createVariableDecl(from: property)
            }
            try InitializerDeclSyntax("public required init()", bodyBuilder: {
                for property in properties {
                    createBuildablePropertyInitializer(identifier: property.identifier, variableType: property.variableType)
                }
            })
            for property in properties {
                for item in try createSetValueFunctions(
                    identifier: property.identifier,
                    variableType: property.variableType,
                    returnType: builderClassName
                ) {
                    item
                }
            }
            buildFunction
        })
    }

    private static func createVariableDecl(from property: Property) -> VariableDeclSyntax {
        return buildablePropertyVariableDecl(
            modifierKeywords: [.public],
            bindingKeyword: .let,
            identifier: property.identifier,
            type: property.variableType)
    }

    private static func createBuildablePropertyInitializer(identifier: String, variableType: VariableType, name: String? = nil) -> CodeBlockItemSyntax {
        let typeIdentifier = buildablePropertyTypeIdentifier(for: variableType, includeGenericClause: false)
        let initExpression = IdentifierExprSyntax(identifier: TokenSyntax(.identifier(typeIdentifier), presence: .present))
        return CodeBlockItemSyntax(item: CodeBlockItemSyntax.Item(SequenceExprSyntax(elementsBuilder: {
            IdentifierExprSyntax(identifier: .identifier(identifier))
            AssignmentExprSyntax()
            FunctionCallExprSyntax(calledExpression: initExpression, leftParen: .leftParenToken(), rightParen: .rightParenToken()) {
                if !variableType.isCollection {
                    TupleExprElementSyntax(label: "name", expression: StringLiteralExprSyntax(content: name ?? identifier))
                }
            }
        })))
    }

    // MARK: - Set Value Functions

    private static func createSetValueFunctions(identifier: String, variableType: VariableType, returnType: String) throws -> [DeclSyntaxProtocol] {
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

    private static func buildablePropertyVariableDecl(
        modifierKeywords: [Keyword] = [],
        bindingKeyword: Keyword,
        identifier: String,
        type: VariableType
    ) -> VariableDeclSyntax {
        let modifiers: ModifierListSyntax?
        if modifierKeywords.isEmpty {
            modifiers = nil
        } else {
            modifiers = ModifierListSyntax {
                for keyword in modifierKeywords {
                    DeclModifierSyntax(name: .keyword(keyword))
                }
            }
        }
        let binding = TokenSyntax(.keyword(bindingKeyword), presence: .present)
        let identifierPattern = IdentifierPatternSyntax(identifier: .identifier(identifier))
        let typeIdentifier = buildablePropertyTypeIdentifier(for: type, includeGenericClause: true)
        let typeAnnotation = TypeAnnotationSyntax(
            type: SimpleTypeIdentifierSyntax(
                name: TokenSyntax(.identifier(typeIdentifier), presence: .present)))
        return VariableDeclSyntax(modifiers: modifiers, bindingKeyword: binding) {
            PatternBindingListSyntax {
                PatternBindingSyntax(pattern: identifierPattern, typeAnnotation: typeAnnotation)
            }
        }
    }

    private static func buildablePropertyTypeIdentifier(for type: VariableType, includeGenericClause: Bool) -> String {
        switch type {
        case .implicit:
            return ""
        case let .array(elementType):
            let genericClause = includeGenericClause ? "<\(elementType.trimmedDescription)>" : ""
            return "BuildableArrayProperty\(genericClause)"
        case let .dictionary(keyType, valueType):
            let genericClause = includeGenericClause ? "<\(keyType.trimmedDescription), \(valueType.trimmedDescription)>" : ""
            return "BuildableDictionaryProperty\(genericClause)"
        case let .set(elementType):
            let genericClause = includeGenericClause ? "<\(elementType.trimmedDescription)>" : ""
            return "BuildableSetProperty\(genericClause)"
        case let .explicit(typeNode):
            let genericClause = includeGenericClause ? "<\(typeNode.trimmedDescription)>" : ""
            return "BuildableProperty\(genericClause)"
        }
    }

    private static func variableDecl(
        modifierKeywords: [Keyword] = [],
        bindingKeyword: Keyword,
        identifier: String,
        type: TypeSyntaxProtocol
    ) -> VariableDeclSyntax {
        let modifiers: ModifierListSyntax?
        if modifierKeywords.isEmpty {
            modifiers = nil
        } else {
            modifiers = ModifierListSyntax {
                for keyword in modifierKeywords {
                    DeclModifierSyntax(name: .keyword(keyword))
                }
            }
        }
        let binding = TokenSyntax(.keyword(bindingKeyword), presence: .present)
        let identifierPattern = IdentifierPatternSyntax(identifier: .identifier(identifier))
        let typeAnnotation = TypeAnnotationSyntax(type: type)
        return VariableDeclSyntax(modifiers: modifiers, bindingKeyword: binding) {
            PatternBindingListSyntax {
                PatternBindingSyntax(pattern: identifierPattern, typeAnnotation: typeAnnotation)
            }
        }
    }

    private static func variableTypeBuilderCanFail(_ variableType: VariableType) -> Bool {
        return switch variableType {
        case .array(_), .dictionary(_, _), .set(_): false
        case .implicit, .explicit(_): true
        }
    }
}

@main
struct AutoBuilderPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        AutoBuilderMacro.self,
    ]
}
