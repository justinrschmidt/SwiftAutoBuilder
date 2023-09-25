import SwiftCompilerPlugin
import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

public struct AutoBuilderMacro: ExtensionMacro {
    private enum DeclAnalysisResponse {
        case `struct`(structDecl: StructDeclSyntax, propertiesToBuild: [Property])
        case `enum`(enumDecl: EnumDeclSyntax, cases: [EnumUnionCase])
        case error(diagnostics: [Diagnostic])
    }

    // TODO: Look at the types passed into conformingTo once issue #2031 is fixed.
    // Issue #2031 describes how `assertMacroExpansion()` always passes an empty array
    // into the conformingTo parameter in tests.
    // https://github.com/apple/swift-syntax/issues/2031
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let (response, nonFatalDiagnostics) = analyze(declaration: declaration, of: node)
        nonFatalDiagnostics.forEach(context.diagnose(_:))
        switch response {
        case let .struct(structDecl, propertiesToBuild):
            let isPublic = hasPublic(modifiers: structDecl.modifiers)
            let decls = try createStructDecls(from: propertiesToBuild, clientType: type.trimmed, isPublic: isPublic)
            return try [
                ExtensionDeclSyntax("extension \(type.trimmed): Buildable") {
                    for decl in decls {
                        decl
                    }
                }
            ]
        case let .enum(enumDecl, cases):
            let isPublic = hasPublic(modifiers: enumDecl.modifiers)
            let decls = try createEnumDecls(from: cases, clientType: type.trimmed, isPublic: isPublic, in: context)
            return try [
                ExtensionDeclSyntax("extension \(type.trimmed): Buildable") {
                    for decl in decls {
                        decl
                    }
                }
            ]
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

    private static func createStructDecls(from properties: [Property], clientType: TypeSyntaxProtocol, isPublic: Bool) throws -> [DeclSyntax] {
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
                buildFunction: createStructBuildFunction(clientType: clientType)
            ).cast(DeclSyntax.self)
        ]
    }

    private static func createPropertyInitializer(from property: Property) -> CodeBlockItemSyntax {
        if property.variableType.isCollection {
            return "\(raw: property.identifier) = builder.\(raw: property.identifier).build()"
        } else {
            return "\(raw: property.identifier) = try builder.\(raw: property.identifier).build()"
        }
    }

    private static func createToBuilderFunction(from properties: [Property], isPublic: Bool) throws -> FunctionDeclSyntax {
        let accessModifier = isPublic ? "public " : ""
        return try FunctionDeclSyntax("\(raw: accessModifier)func toBuilder() -> Builder") {
            "let builder = Builder()"
            for property in properties {
                "builder.set(\(raw: property.identifier): \(raw: property.identifier))"
            }
            "return builder"
        }
    }

    private static func createStructBuildFunction(clientType: TypeSyntaxProtocol) throws -> FunctionDeclSyntax {
        return try FunctionDeclSyntax("public func build() throws -> \(clientType)") {
            "return try \(clientType)(with: self)"
        }
    }

    // MARK: - Create Enum Syntax Tokens

    private static func createEnumDecls(
        from cases: [EnumUnionCase],
        clientType: TypeSyntaxProtocol,
        isPublic: Bool,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let accessModifier = isPublic ? "public " : ""
        return [
            try InitializerDeclSyntax("\(raw: accessModifier)init(with builder: Builder) throws", bodyBuilder: {
                "self = try builder.build()"
            }).cast(DeclSyntax.self),
            try createEnumToBuilderFunction(isPublic: isPublic).cast(DeclSyntax.self),
            try createEnumBuilderClass(from: cases, clientType: clientType, in: context).cast(DeclSyntax.self)
        ]
    }

    private static func createEnumToBuilderFunction(isPublic: Bool) throws -> FunctionDeclSyntax {
        let accessModifier = isPublic ? "public " : ""
        return try FunctionDeclSyntax("\(raw: accessModifier)func toBuilder() -> Builder") {
            "let builder = Builder()"
            "builder.set(value: self)"
            "return builder"
        }
    }

    private static func createEnumBuilderClass(
        from cases: [EnumUnionCase],
        clientType: TypeSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> ClassDeclSyntax {
        return try ClassDeclSyntax("public class Builder: BuilderProtocol") {
            VariableDeclSyntax(
                modifiers: ModifierListSyntax(arrayLiteral: DeclModifierSyntax(name: .keyword(.private))),
                .var,
                name: IdentifierPatternSyntax(identifier: .identifier("currentCase")).cast(PatternSyntax.self),
                type: TypeAnnotationSyntax(type: OptionalTypeSyntax(wrappedType: SimpleTypeIdentifierSyntax(name: .identifier("BuilderCases")))))
            try InitializerDeclSyntax("public required init()") {
                "currentCase = nil"
            }
            for enumCase in cases {
                let caseIdentifier = enumCase.caseIdentifier
                try createCaseBuilderComputedProperty(named: caseIdentifier, builderCase: caseIdentifier, builderClassName: caseIdentifier.capitalized)
            }
            try createEnumSetValueFunction(from: cases, clientType: clientType)
            try createEnumBuildFunction(from: cases, clientType: clientType)
            for enumCase in cases {
                try createEnumCaseBuilderClass(from: enumCase, clientType: clientType, in: context)
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
                        try AccessorDeclSyntax(accessorKind: .keyword(.get)) {
                            try SwitchExprSyntax("switch currentCase") {
                                SwitchCaseSyntax("case let .some(.\(raw: builderCase)(builder)):") {
                                    "return builder"
                                }
                                SwitchCaseSyntax("default:") {
                                    "let builder = \(raw: builderClassName)()"
                                    "currentCase = .\(raw: builderCase)(builder)"
                                    "return builder"
                                }
                            }
                        }
                        AccessorDeclSyntax(accessorKind: .keyword(.set)) {
                            "currentCase = .\(raw: builderCase)(newValue)"
                        }
                    }))))
            }))
    }

    private static func createEnumSetValueFunction(from cases: [EnumUnionCase], clientType: TypeSyntaxProtocol) throws -> FunctionDeclSyntax {
        return try FunctionDeclSyntax("public func set(value: \(clientType))") {
            try SwitchExprSyntax("switch value") {
                for enumCase in cases {
                    let caseDeclaration = if enumCase.associatedValues.isEmpty {
                        "case .\(enumCase.caseIdentifier):"
                    } else {
                        "case let .\(enumCase.caseIdentifier)(\(enumCase.valueIdentifiers.joined(separator: ", "))):"
                    }
                    SwitchCaseSyntax("\(raw: caseDeclaration)") {
                        "let builder = \(raw: enumCase.capitalizedCaseIdentifier)()"
                        for value in enumCase.associatedValues {
                            switch value.label {
                            case let .identifierPattern(pattern):
                                "builder.set(\(pattern): \(pattern))"
                            case let .index(index):
                                "builder.set(index_\(raw: index): i\(raw: index))"
                            }
                        }
                        "currentCase = .\(enumCase.caseIdentifierPattern)(builder)"
                    }
                }
            }
        }
    }

    private static func createEnumBuildFunction(from cases: [EnumUnionCase], clientType: TypeSyntaxProtocol) throws -> FunctionDeclSyntax {
        return try FunctionDeclSyntax("public func build() throws -> \(clientType)") {
            try SwitchExprSyntax("switch currentCase") {
                for enumCase in cases {
                    SwitchCaseSyntax("case let .some(.\(raw: enumCase.caseIdentifier)(builder)):") {
                        "return try builder.build()"
                    }
                }
                SwitchCaseSyntax("case .none:") {
                    "throw BuilderError.noEnumCaseSet"
                }
            }
        }
    }

    private static func createEnumCaseBuilderClass(
        from enumCase: EnumUnionCase,
        clientType: TypeSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> ClassDeclSyntax {
        let builderClassName = enumCase.caseIdentifier.capitalized
        return try ClassDeclSyntax("public class \(raw: builderClassName): BuilderProtocol", membersBuilder: {
            for value in enumCase.associatedValues {
                switch value.label {
                case let .identifierPattern(pattern):
                    try buildablePropertyVariableDecl(
                        modifierKeywords: [.public],
                        bindingKeyword: .let,
                        identifier: pattern.trimmedDescription,
                        variableType: value.variableType)
                case let .index(index):
                    try buildablePropertyVariableDecl(
                        modifierKeywords: [.public],
                        bindingKeyword: .let,
                        identifier: "index_\(index)",
                        variableType: value.variableType)
                }
            }
            try InitializerDeclSyntax("public required init()", bodyBuilder: {
                for value in enumCase.associatedValues {
                    switch value.label {
                    case let .identifierPattern(pattern):
                        try createBuildablePropertyInitializer(identifier: pattern.identifier.text, variableType: value.variableType)
                    case let .index(index):
                        try createBuildablePropertyInitializer(identifier: "index_\(index)", variableType: value.variableType)
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
            try FunctionDeclSyntax("public func build() throws -> \(clientType)") {
                if enumCase.associatedValues.isEmpty {
                    "return .\(enumCase.caseIdentifierPattern)"
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
                        "return try .\(enumCase.caseIdentifierPattern)(\(raw: args))"
                    } else {
                        "return .\(enumCase.caseIdentifierPattern)(\(raw: args))"
                    }
                }
            }
        })
    }

    private static func variableTypeBuilderCanFail(_ variableType: VariableType) -> Bool {
        return switch variableType {
        case .array(_), .dictionary(_, _), .set(_): false
        case .implicit, .explicit(_): true
        }
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
        buildFunction: FunctionDeclSyntax
    ) throws -> ClassDeclSyntax {
        return try ClassDeclSyntax("public class \(raw: builderClassName): BuilderProtocol", membersBuilder: {
            for property in properties {
                try createVariableDecl(from: property)
            }
            try InitializerDeclSyntax("public required init()", bodyBuilder: {
                for property in properties {
                    try createBuildablePropertyInitializer(identifier: property.identifier, variableType: property.variableType)
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

    private static func createVariableDecl(from property: Property) throws -> VariableDeclSyntax {
        return try buildablePropertyVariableDecl(
            modifierKeywords: [.public],
            bindingKeyword: .let,
            identifier: property.identifier,
            variableType: property.variableType)
    }

    private static func createBuildablePropertyInitializer(identifier: String, variableType: VariableType) throws -> CodeBlockItemSyntax {
        let typeIdentifier = try buildablePropertyTypeIdentifier(for: variableType, includeGenericClause: false)
        let args = variableType.isCollection ? "" : "name: \"\(identifier)\""
        return "\(raw: identifier) = \(raw: typeIdentifier)(\(raw: args))"
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

    private static func buildablePropertyVariableDecl(
        modifierKeywords: [Keyword] = [],
        bindingKeyword: Keyword,
        identifier: String,
        variableType: VariableType
    ) throws -> VariableDeclSyntax {
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
        let type = try buildablePropertyTypeIdentifier(for: variableType, includeGenericClause: true)
        let typeAnnotation = TypeAnnotationSyntax(type: type)
        return VariableDeclSyntax(modifiers: modifiers, bindingKeyword: binding) {
            PatternBindingListSyntax {
                PatternBindingSyntax(pattern: identifierPattern, typeAnnotation: typeAnnotation)
            }
        }
    }

    private static func buildablePropertyTypeIdentifier(
        for type: VariableType,
        includeGenericClause: Bool
    ) throws -> SimpleTypeIdentifierSyntax {
        switch type {
        case .implicit:
            throw AutoBuilderMacroError.missingType
        case let .array(elementType):
            let genericTypes = includeGenericClause ? [elementType.trimmed] : []
            return SimpleTypeIdentifierSyntax(name: "BuildableArrayProperty", genericTypes: genericTypes)
        case let .dictionary(keyType, valueType):
            let genericTypes = includeGenericClause ? [keyType.trimmed, valueType.trimmed] : []
            return SimpleTypeIdentifierSyntax(name: "BuildableDictionaryProperty", genericTypes: genericTypes)
        case let .set(elementType):
            let genericTypes = includeGenericClause ? [elementType.trimmed] : []
            return SimpleTypeIdentifierSyntax(name: "BuildableSetProperty", genericTypes: genericTypes)
        case let .explicit(typeNode):
            let genericTypes = includeGenericClause ? [typeNode.trimmed] : []
            return SimpleTypeIdentifierSyntax(name: "BuildableProperty", genericTypes: genericTypes)
        }
    }
}

enum AutoBuilderMacroError: Error {
    case missingType
}

@main
struct AutoBuilderPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        AutoBuilderMacro.self,
    ]
}
