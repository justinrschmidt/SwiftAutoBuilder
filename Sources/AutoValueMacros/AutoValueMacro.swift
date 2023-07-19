import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

public enum AutoValueDiagnostic: DiagnosticMessage {
    public static let domain = "AutoValueMacro"

    case impliedVariableType(identifier: String)
    case invalidTypeForAutoValue

    public var severity: DiagnosticSeverity {
        switch self {
        case .impliedVariableType(_),
                .invalidTypeForAutoValue:
            return .error
        }
    }

    public var message: String {
        switch self {
        case .impliedVariableType(let identifier):
            return "Type annotation missing for '\(identifier)'. AutoBuilder requires all variable properties to have type annotations."
        case .invalidTypeForAutoValue:
            return "@AutoValue can only be applied to structs"
        }
    }

    public var diagnosticID: MessageID {
        switch self {
        case .impliedVariableType(_):
            return MessageID(domain: Self.domain, id: "ImpliedVariableType")
        case .invalidTypeForAutoValue:
            return MessageID(domain: Self.domain, id: "InvalidTypeForAutoValue")
        }
    }
}

public struct AutoValueMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext) throws -> [DeclSyntax] {
            if let structDecl = declaration.as(StructDeclSyntax.self) {
                return try expandStruct(structDecl, of: node, in: context)
            } else {
                context.diagnose(Diagnostic(
                    node: node.cast(Syntax.self),
                    message: AutoValueDiagnostic.invalidTypeForAutoValue))
                return []
            }
        }

    private static func expandStruct(
        _ structDecl: StructDeclSyntax,
        of node: AttributeSyntax,
        in context: some MacroExpansionContext) throws -> [DeclSyntax] {
            let storedProperties = VariableHelper.getStoredProperties(from: structDecl.memberBlock.members)
            let impliedTypeVariableProperties = storedProperties.filter({ $0.bindingKeyword == .var && $0.variableType.isImplicit })
            guard impliedTypeVariableProperties.isEmpty else {
                for property in impliedTypeVariableProperties {
                    context.diagnose(Diagnostic(
                        node: property.identifierPattern.cast(Syntax.self),
                        message: AutoValueDiagnostic.impliedVariableType(identifier: property.identifier)))
                }
                return []
            }
            let propertiesToBuild = storedProperties.filter({ !$0.isInitializedConstant })
            return try createDecls(from: propertiesToBuild)
        }

    private static func createDecls(from properties: [Property]) throws -> [DeclSyntax] {
        return [
            try InitializerDeclSyntax("init(with builder: Builder) throws", bodyBuilder: {
                for property in properties {
                    createPropertyInitializer(from: property)
                }
            }).cast(DeclSyntax.self),
            try ClassDeclSyntax("class Builder", membersBuilder: {
                for property in properties {
                    createVariableDecl(from: property)
                }
                try InitializerDeclSyntax("init()", bodyBuilder: {
                    for property in properties {
                        createBuildablePropertyInitializer(from: property)
                    }
                })
                for property in properties {
                    try createSetValueFunction(from: property)
                }
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
        return try FunctionDeclSyntax("func set(\(raw: property.identifier): \(raw: property.type)) -> Builder") {
            FunctionCallExprSyntax(calledExpression: setValueExpression, leftParen: .leftParenToken(), rightParen: .rightParenToken()) {
                TupleExprElementSyntax(label: "value", expression: IdentifierExprSyntax(identifier: .identifier(property.identifier)))
            }
            ReturnStmtSyntax(expression: IdentifierExprSyntax(identifier: .keyword(.`self`)))
        }
    }
}

@main
struct AutoValuePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        AutoValueMacro.self,
    ]
}
