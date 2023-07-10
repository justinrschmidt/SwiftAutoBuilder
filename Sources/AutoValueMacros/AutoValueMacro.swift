import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

enum AutoValueError: CustomStringConvertible, Error {
	case invalidType

	var description: String {
		switch self {
		case .invalidType:
			return "@AutoValue can only be applied to structs"
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
			return [
				try ClassDeclSyntax("class Builder", membersBuilder: {
				}).as(DeclSyntax.self)!
			]
		}
}

@main
struct AutoValuePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
		AutoValueMacro.self,
    ]
}
