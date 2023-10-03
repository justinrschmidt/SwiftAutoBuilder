import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

struct StructExtensionGenerator: AutoBuilderExtensionGenerator {
    static func analyze(decl: StructDeclSyntax) -> AnalysisResult<[Property]> {
        let storedProperties = VariableInspector.getProperties(from: decl.memberBlock.members)
        let impliedTypeVariableProperties = storedProperties.filter({ $0.bindingKeyword == .var && $0.variableType.isImplicit })
        let diagnostics = impliedTypeVariableProperties.map({ property in
            return Diagnostic(
                node: property.identifierPattern.cast(Syntax.self),
                message: AutoBuilderDiagnostic.impliedVariableType(identifierPattern: property.identifierPattern))
        })
        if diagnostics.isEmpty {
            let propertiesToBuild = storedProperties.filter({ $0.isStoredProperty && $0.isIVar && !$0.isInitializedConstant })
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
            try InitializerDeclSyntax("\(raw: accessModifier)init(with builder: Builder) throws", bodyBuilder: {
                for property in properties {
                    createPropertyInitializer(from: property)
                }
            }).cast(DeclSyntax.self)
            try createToBuilderFunction(from: properties, isPublic: isPublic).cast(DeclSyntax.self)
            try createBuilderClass(
                from: properties,
                clientType: clientType
            ).cast(DeclSyntax.self)
        }
    }

    private static func createPropertyInitializer(from property: Property) -> CodeBlockItemSyntax {
        if property.variableType.isCollection {
            return "\(property.identifierPattern) = builder.\(property.identifierPattern).build()"
        } else {
            return "\(property.identifierPattern) = try builder.\(property.identifierPattern).build()"
        }
    }

    private static func createToBuilderFunction(from properties: [Property], isPublic: Bool) throws -> FunctionDeclSyntax {
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
        return try ClassDeclSyntax("public class \(builderClassTypeIdentifier): BuilderProtocol", membersBuilder: {
            for property in properties {
                try BuildablePropertyGenerator.createVariableDecl(
                    modifierKeywords: [.public],
                    bindingKeyword: .let,
                    identifierPattern: property.identifierPattern,
                    variableType: property.variableType)
            }
            try InitializerDeclSyntax("public required init()", bodyBuilder: {
                for property in properties {
                    try BuildablePropertyGenerator.createInitializer(identifierPattern: property.identifierPattern, variableType: property.variableType)
                }
            })
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
        })
    }
}
