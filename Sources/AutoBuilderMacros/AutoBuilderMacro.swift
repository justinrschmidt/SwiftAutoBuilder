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
            let propertiesToBuild = storedProperties.filter({ !$0.isInitializedConstant })
            return .struct(structDecl: structDecl, propertiesToBuild: propertiesToBuild)
        } else {
            return .error(diagnostics: diagnostics)
        }
    }

    private static func createDecls(from properties: [Property], containerIdentifier: TokenSyntax) throws -> [DeclSyntax] {
        return [
            try InitializerDeclSyntax("init(with builder: Builder) throws", bodyBuilder: {
                for property in properties {
                    createPropertyInitializer(from: property)
                }
            }).cast(DeclSyntax.self),
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
                    try createSetValueFunction(from: property)
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
            TryExprSyntax(expression: buildFunctionCall)
        }
    }

    private static func createVariableDecl(from property: Property) -> VariableDeclSyntax {
        let bindingKeyword = TokenSyntax(.keyword(.let), presence: .present)
        let identifierPattern = IdentifierPatternSyntax(identifier: .identifier(property.identifier))
        let typeAnnotation = TypeAnnotationSyntax(
            type: SimpleTypeIdentifierSyntax(
                name: TokenSyntax(
                    .identifier("BuildableProperty<\(property.type)>"),
                    presence: .present)))
        return VariableDeclSyntax(bindingKeyword: bindingKeyword) {
            PatternBindingListSyntax {
                PatternBindingSyntax(pattern: identifierPattern, typeAnnotation: typeAnnotation)
            }
        }
    }

    private static func createBuildablePropertyInitializer(from property: Property) -> CodeBlockItemSyntax {
        let initExpression = IdentifierExprSyntax(identifier: TokenSyntax(.identifier("BuildableProperty"), presence: .present))
        return CodeBlockItemSyntax(item: CodeBlockItemSyntax.Item(SequenceExprSyntax(elementsBuilder: {
            IdentifierExprSyntax(identifier: .identifier(property.identifier))
            AssignmentExprSyntax()
            FunctionCallExprSyntax(calledExpression: initExpression, leftParen: .leftParenToken(), rightParen: .rightParenToken()) {
                TupleExprElementSyntax(label: "name", expression: StringLiteralExprSyntax(content: property.identifier))
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