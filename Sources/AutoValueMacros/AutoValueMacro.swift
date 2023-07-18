import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

enum AutoValueError: CustomStringConvertible, Error {
    case invalidType

    var description: String {
        switch self {
        case .invalidType:
            return "@AutoValue can only be applied to structs"
        }
    }
}

public enum AutoValueDiagnostic: DiagnosticMessage {
    public static let domain = "AutoValueMacro"

    case impliedVariableType(identifier: String)

    public var severity: DiagnosticSeverity {
        switch self {
        case .impliedVariableType(_):
            return .error
        }
    }

    public var message: String {
        switch self {
        case .impliedVariableType(let identifier):
            return "Type annotation missing for '\(identifier)'. AutoBuilder requires all variable properties to have type annotations."
        }
    }

    public var diagnosticID: MessageID {
        switch self {
        case .impliedVariableType(_):
            return MessageID(domain: Self.domain, id: "ImpliedVariableType")
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
                throw AutoValueError.invalidType
            }
        }

    private static func expandStruct(
        _ structDecl: StructDeclSyntax,
        of node: AttributeSyntax,
        in context: some MacroExpansionContext) throws -> [DeclSyntax] {
            // TODO: need to emit diagnostic errors when type information is missing
            // - stored constants with inline initializers can be ignored
            // - use DiagnosticSpec for tests
            // TODO: need to skip over stored constants with inline initializers because they are already initialized
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
            return [
                try InitializerDeclSyntax("init(with builder: Builder) throws", bodyBuilder: {
                    for property in storedProperties {
                        createPropertyInitializer(from: property)
                    }
                }).cast(DeclSyntax.self),
                try ClassDeclSyntax("class Builder", membersBuilder: {
                    for property in storedProperties {
                        createVariableDecl(from: property)
                    }
                    try InitializerDeclSyntax("init()", bodyBuilder: {
                        for property in storedProperties {
                            createBuildablePropertyInitializer(from: property)
                        }
                    })
                    for property in storedProperties {
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
        let identifierPattern = IdentifierPatternSyntax(identifier: property.identifierToken)
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
            IdentifierExprSyntax(identifier: property.identifierToken)
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
