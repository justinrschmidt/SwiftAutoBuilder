import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Handles analysis and builder class generation for class declarations.
struct ClassExtensionGenerator: AutoBuilderExtensionGenerator {
    static func analyze(decl: ClassDeclSyntax) -> AnalysisResult<[Property]> {
        let storedProperties = VariableInspector.getProperties(from: decl.memberBlock.members)
        let impliedTypeVariableProperties = storedProperties
            .filter({ $0.bindingKeyword == .var && $0.variableType.isImplicit })
        var diagnostics = impliedTypeVariableProperties.map({ property in
            return Diagnostic(
                node: property.identifierPattern.cast(Syntax.self),
                message: AutoBuilderDiagnostic.impliedVariableType(identifierPattern: property.identifierPattern))
        })
        if !decl.modifiers.contains(where: { $0.name.tokenKind == .keyword(.final) }) {
//            var modifierName = TokenSyntax(.keyword(.final), trailingTrivia: .spaces(1), presence: .present)
//            if decl.modifiers.isEmpty {
////                finalModifier.leadingTrivia = .newlines(1)
//                modifierName.leadingTrivia = .newlines(1)
//            }
            let modifierName = TokenSyntax(
                .keyword(.final),
                leadingTrivia: .newlines(1),
                trailingTrivia: .spaces(1),
                presence: .present)
            let finalModifier: DeclModifierSyntax = DeclModifierSyntax(name: modifierName, trailingTrivia: .spaces(1))
            var newModifiers = decl.modifiers
//            decl.modifiers
            newModifiers.append(finalModifier)
            diagnostics.append(Diagnostic(
                node: decl,
                message: AutoBuilderDiagnostic.nonFinalClass,
                fixIt: FixIt(
                    message: AutoBuilderFixIt.appendFinalModifier,
                    changes: [
                        .replace(
                            oldNode: decl.modifiers.cast(Syntax.self),
                            newNode: newModifiers.cast(Syntax.self)),
//                        .replaceLeadingTrivia(token: decl.classKeyword, newTrivia: Trivia(pieces: [])),
                        .replaceLeadingTrivia(token: modifierName, newTrivia: decl.classKeyword.leadingTrivia)
                    ])))
        }
        if diagnostics.isEmpty {
            let propertiesToBuild = storedProperties
                .filter({ $0.isStoredProperty && $0.isIVar && !$0.isInitializedConstant })
            return .success(analysisOutput: propertiesToBuild, nonFatalDiagnostics: [])
        } else {
            return .error(diagnostics: diagnostics)
        }
    }

    static func generateExtension(
        from properties: [Property],
        clientType: some TypeSyntaxProtocol,
        isPublic: Bool,
        in context: some MacroExpansionContext
    ) throws -> ExtensionDeclSyntax {
        let accessModifier = isPublic ? "public " : ""
        return try ExtensionDeclSyntax("extension \(clientType.trimmed): Buildable") {
            try InitializerDeclSyntax("\(raw: accessModifier)init(with builder: Builder) throws") {
                for property in properties {
                    createPropertyInitializer(from: property)
                }
            }.cast(DeclSyntax.self)
            try createToBuilderFunction(from: properties, isPublic: isPublic).cast(DeclSyntax.self)
            try createBuilderClass(from: properties, clientType: clientType).cast(DeclSyntax.self)
        }
    }

    private static func createPropertyInitializer(from property: Property) -> CodeBlockItemSyntax {
        if property.variableType.isCollection {
            return "\(property.identifierPattern) = builder.\(property.identifierPattern).build()"
        } else {
            return "\(property.identifierPattern) = try builder.\(property.identifierPattern).build()"
        }
    }

    private static func createToBuilderFunction(
        from properties: [Property],
        isPublic: Bool
    ) throws -> FunctionDeclSyntax {
        let accessModifier = isPublic ? "public " : ""
        return try FunctionDeclSyntax("\(raw: accessModifier)func toBuilder() -> Builder") {
            "let builder = Builder()"
            for property in properties {
                "builder.set(\(property.identifierPattern): \(property.identifierPattern))"
            }
            "return builder"
        }
    }

    private static func createBuilderClass(
        from properties: [Property],
        clientType: TypeSyntaxProtocol
    ) throws -> ClassDeclSyntax {
        let builderClassTypeIdentifier = IdentifierTypeSyntax(name: "Builder")
        return try ClassDeclSyntax("public class \(builderClassTypeIdentifier): BuilderProtocol") {
            for property in properties {
                try BuildablePropertyGenerator.createVariableDecl(
                    modifierKeywords: [.public],
                    bindingKeyword: .let,
                    identifierPattern: property.identifierPattern,
                    variableType: property.variableType)
            }
            try InitializerDeclSyntax("public required init()") {
                for property in properties {
                    try BuildablePropertyGenerator.createInitializer(
                        identifierPattern: property.identifierPattern,
                        variableType: property.variableType)
                }
            }
            for property in properties {
                for item in try SetValueFunctionsGenerator.createSetValueFunctions(
                    identifierPattern: property.identifierPattern,
                    variableType: property.variableType,
                    returnType: builderClassTypeIdentifier
                ) {
                    item
                }
            }
            try FunctionDeclSyntax("public func build() throws -> \(clientType)") {
                "return try \(clientType)(with: self)"
            }
        }
    }
}
