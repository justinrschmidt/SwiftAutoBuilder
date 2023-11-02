import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Handles analysis and builder class generation for enum declarations.
struct EnumExtensionGenerator: AutoBuilderExtensionGenerator {
    static func analyze(decl: EnumDeclSyntax) -> AnalysisResult<[EnumUnionCase]> {
        let cases = EnumInspector.getCases(from: decl.memberBlock.members)
        var errorDiagnostics: [Diagnostic] = []
        if cases.isEmpty {
            errorDiagnostics.append(Diagnostic(
                node: decl.cast(Syntax.self),
                message: AutoBuilderDiagnostic.enumWithNoCases(enumName: decl.name.trimmedDescription)))
        }
        let overloadedCases = getOverloadedCases(cases)
        if !overloadedCases.isEmpty {
            errorDiagnostics.append(Diagnostic(
                node: decl.cast(Syntax.self),
                message: AutoBuilderDiagnostic.enumWithOverloadedCases(overloadedCases: overloadedCases)))
        }
        errorDiagnostics += getInvalidAssociatedValueLabelsDiagnostics(cases)
        if !errorDiagnostics.isEmpty {
            return .error(diagnostics: errorDiagnostics)
        }
        var diagnostics: [Diagnostic] = []
        let hasAssociatedValues = cases.contains(where: { !$0.associatedValues.isEmpty })
        if !hasAssociatedValues {
            diagnostics.append(Diagnostic(
                node: decl.cast(Syntax.self),
                message: AutoBuilderDiagnostic.noAssociatedValues(enumName: decl.name.trimmedDescription)))
        }
        return .success(analysisOutput: cases, nonFatalDiagnostics: diagnostics)
    }

    private static func getOverloadedCases(_ cases: [EnumUnionCase]) -> [String] {
        var caseIdentifiers: Set<String> = []
        var overloadedCases: Set<String> = []
        var overloadedCasesList: [String] = []
        for enumCase in cases {
            if caseIdentifiers.contains(enumCase.caseIdentifierPattern.identifier.text) {
                if !overloadedCases.contains(enumCase.caseIdentifierPattern.identifier.text) {
                    overloadedCases.insert(enumCase.caseIdentifierPattern.identifier.text)
                    overloadedCasesList.append(enumCase.caseIdentifierPattern.identifier.text)
                }
            } else {
                caseIdentifiers.insert(enumCase.caseIdentifierPattern.identifier.text)
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

    static func generateExtension(
        from cases: [EnumUnionCase],
        clientType: some TypeSyntaxProtocol,
        isPublic: Bool,
        in context: some MacroExpansionContext
    ) throws -> ExtensionDeclSyntax {
        let accessModifier = isPublic ? "public " : ""
        return try ExtensionDeclSyntax("extension \(clientType.trimmed): Buildable") {
            try InitializerDeclSyntax("\(raw: accessModifier)init(with builder: Builder) throws", bodyBuilder: {
                "self = try builder.build()"
            }).cast(DeclSyntax.self)
            try createEnumToBuilderFunction(isPublic: isPublic).cast(DeclSyntax.self)
            try createEnumBuilderClass(from: cases, clientType: clientType, in: context).cast(DeclSyntax.self)
        }
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
                modifiers: DeclModifierListSyntax(arrayLiteral: DeclModifierSyntax(name: .keyword(.private))),
                .var,
                name: IdentifierPatternSyntax(identifier: "currentCase").cast(PatternSyntax.self),
                type: TypeAnnotationSyntax(type: OptionalTypeSyntax(wrappedType: IdentifierTypeSyntax(name: .identifier("BuilderCases")))))
            try InitializerDeclSyntax("public required init()") {
                "currentCase = nil"
            }
            for enumCase in cases {
                try createCaseBuilderComputedProperty(for: enumCase)
            }
            try createEnumSetValueFunction(from: cases, clientType: clientType)
            try createEnumBuildFunction(from: cases, clientType: clientType)
            for enumCase in cases {
                try createEnumCaseBuilderClass(from: enumCase, clientType: clientType, in: context)
            }
            try createBuilderCasesEnum(from: cases)
        }
    }

    private static func createCaseBuilderComputedProperty(for enumCase: EnumUnionCase) throws -> VariableDeclSyntax {
        let builderClassTypeIdentifier = createBuilderClassTypeIdentifier(for: enumCase)
        return VariableDeclSyntax(
            modifiers: DeclModifierListSyntax(arrayLiteral: DeclModifierSyntax(name: .keyword(.public))),
            bindingSpecifier: .keyword(.var),
            bindings: try PatternBindingListSyntax(itemsBuilder: {
                PatternBindingSyntax(
                    pattern: enumCase.caseIdentifierPattern,
                    typeAnnotation: TypeAnnotationSyntax(type: builderClassTypeIdentifier),
                    accessorBlock: try AccessorBlockSyntax(accessors: .accessors(AccessorDeclListSyntax(itemsBuilder: {
                        try AccessorDeclSyntax(accessorSpecifier: .keyword(.get)) {
                            try SwitchExprSyntax("switch currentCase") {
                                SwitchCaseSyntax("case let .some(.\(enumCase.caseIdentifierPattern)(builder)):") {
                                    "return builder"
                                }
                                SwitchCaseSyntax("default:") {
                                    "let builder = \(builderClassTypeIdentifier)()"
                                    "currentCase = .\(enumCase.caseIdentifierPattern)(builder)"
                                    "return builder"
                                }
                            }
                        }
                        AccessorDeclSyntax(accessorSpecifier: .keyword(.set)) {
                            "currentCase = .\(enumCase.caseIdentifierPattern)(newValue)"
                        }
                    }))))
            }))
    }

    private static func createEnumSetValueFunction(from cases: [EnumUnionCase], clientType: TypeSyntaxProtocol) throws -> FunctionDeclSyntax {
        return try FunctionDeclSyntax("public func set(value: \(clientType))") {
            try SwitchExprSyntax("switch value") {
                for enumCase in cases {
                    let caseDeclaration = if enumCase.associatedValues.isEmpty {
                        "case .\(enumCase.caseIdentifierPattern.identifier.text):"
                    } else {
                        "case let .\(enumCase.caseIdentifierPattern.identifier.text)(\(enumCase.valueIdentifierPatterns.map({ $0.identifier.text }).joined(separator: ", "))):"
                    }
                    SwitchCaseSyntax("\(raw: caseDeclaration)") {
                        "let builder = \(raw: enumCase.caseIdentifierPattern.identifier.text.capitalized)()"
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
                    SwitchCaseSyntax("case let .some(.\(enumCase.caseIdentifierPattern)(builder)):") {
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
        let builderClassTypeIdentifier = createBuilderClassTypeIdentifier(for: enumCase)
        return try ClassDeclSyntax("public class \(builderClassTypeIdentifier): BuilderProtocol", membersBuilder: {
            for value in enumCase.associatedValues {
                switch value.label {
                case let .identifierPattern(pattern):
                    try BuildablePropertyGenerator.createVariableDecl(
                        modifierKeywords: [.public],
                        bindingKeyword: .let,
                        identifierPattern: pattern,
                        variableType: value.variableType)
                case let .index(index):
                    try BuildablePropertyGenerator.createVariableDecl(
                        modifierKeywords: [.public],
                        bindingKeyword: .let,
                        identifierPattern: IdentifierPatternSyntax(identifier: "index_\(raw: index)"),
                        variableType: value.variableType)
                }
            }
            try InitializerDeclSyntax("public required init()", bodyBuilder: {
                for value in enumCase.associatedValues {
                    switch value.label {
                    case let .identifierPattern(pattern):
                        try BuildablePropertyGenerator.createInitializer(identifierPattern: pattern, variableType: value.variableType)
                    case let .index(index):
                        try BuildablePropertyGenerator.createInitializer(identifierPattern: IdentifierPatternSyntax(identifier: "index_\(raw: index)"), variableType: value.variableType)
                    }
                }
            })
            for value in enumCase.associatedValues {
                switch value.label {
                case let .identifierPattern(pattern):
                    for item in try SetValueFunctionsGenerator.createSetValueFunctions(
                        identifierPattern: pattern,
                        variableType: value.variableType,
                        returnType: builderClassTypeIdentifier
                    ) {
                        item
                    }
                case let .index(index):
                    for item in try SetValueFunctionsGenerator.createSetValueFunctions(
                        identifierPattern: IdentifierPatternSyntax(identifier: "index_\(raw: index)"),
                        variableType: value.variableType,
                        returnType: builderClassTypeIdentifier
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
        case .implicit, .optional(_), .explicit(_): true
        }
    }

    private static func createBuilderCasesEnum(from cases: [EnumUnionCase]) throws -> EnumDeclSyntax {
        return try EnumDeclSyntax("private enum BuilderCases") {
            for enumCase in cases {
                EnumCaseDeclSyntax {
                    EnumCaseElementSyntax(
                        name: enumCase.caseIdentifierPattern.identifier,
                        parameterClause: EnumCaseParameterClauseSyntax(parameters: EnumCaseParameterListSyntax(itemsBuilder: {
                            EnumCaseParameterSyntax(type: createBuilderClassTypeIdentifier(for: enumCase))
                        })))
                }
            }
        }
    }

    private static func createBuilderClassTypeIdentifier(for enumCase: EnumUnionCase) -> IdentifierTypeSyntax {
        return IdentifierTypeSyntax(name: enumCase.caseIdentifierPattern.identifier.text.capitalized)
    }
}
