import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

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
                name: IdentifierPatternSyntax(identifier: .identifier("currentCase")).cast(PatternSyntax.self),
                type: TypeAnnotationSyntax(type: OptionalTypeSyntax(wrappedType: IdentifierTypeSyntax(name: .identifier("BuilderCases")))))
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
            modifiers: DeclModifierListSyntax(arrayLiteral: DeclModifierSyntax(name: .keyword(.public))),
            bindingSpecifier: .keyword(.var),
            bindings: try PatternBindingListSyntax(itemsBuilder: {
                PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(identifier: .identifier(propertyName)),
                    typeAnnotation: TypeAnnotationSyntax(type: IdentifierTypeSyntax(name: .identifier(builderClassName))),
                    accessorBlock: try AccessorBlockSyntax(accessors: .accessors(AccessorDeclListSyntax(itemsBuilder: {
                        try AccessorDeclSyntax(accessorSpecifier: .keyword(.get)) {
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
                        AccessorDeclSyntax(accessorSpecifier: .keyword(.set)) {
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
                    try BuildablePropertyGenerator.createVariableDecl(
                        modifierKeywords: [.public],
                        bindingKeyword: .let,
                        identifier: pattern.trimmedDescription,
                        variableType: value.variableType)
                case let .index(index):
                    try BuildablePropertyGenerator.createVariableDecl(
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
                        try BuildablePropertyGenerator.createInitializer(identifier: pattern.identifier.text, variableType: value.variableType)
                    case let .index(index):
                        try BuildablePropertyGenerator.createInitializer(identifier: "index_\(index)", variableType: value.variableType)
                    }
                }
            })
            for value in enumCase.associatedValues {
                switch value.label {
                case let .identifierPattern(pattern):
                    for item in try SetValueFunctionsGenerator.createSetValueFunctions(
                        identifier: pattern.identifier.text,
                        variableType: value.variableType,
                        returnType: builderClassName
                    ) {
                        item
                    }
                case let .index(index):
                    for item in try SetValueFunctionsGenerator.createSetValueFunctions(
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
                        name: .identifier(caseIdentifier),
                        parameterClause: EnumCaseParameterClauseSyntax(parameters: EnumCaseParameterListSyntax(itemsBuilder: {
                            EnumCaseParameterSyntax(type: IdentifierTypeSyntax(name: .identifier(caseIdentifier.capitalized)))
                        })))
                }
            }
        }
    }
}
