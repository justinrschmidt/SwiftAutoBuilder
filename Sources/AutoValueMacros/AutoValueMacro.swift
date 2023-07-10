import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct AutoValueMacro: MemberMacro {
	public static func expansion(
		of node: AttributeSyntax,
		providingMembersOf declaration: some DeclGroupSyntax,
		in context: some MacroExpansionContext) throws -> [DeclSyntax] {
			return [
				"""
				class Builder {
				}
				"""
			]
	}
}

@main
struct AutoValuePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
		AutoValueMacro.self,
    ]
}
