import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import AutoValueMacros

let testMacros: [String: Macro.Type] = [
	"AutoValue": AutoValueMacro.self,
]

final class AutoValueTests: XCTestCase {
	func testEmptyStruct() {
		assertMacroExpansion(
			"""
			@AutoValue
			struct Foo {
			}
			""",
			expandedSource:
			"""
			struct Foo {
			    class Builder {
			    }
			}
			""", macros: testMacros)
	}

	func testInvalidType() {
		assertMacroExpansion(
			"""
			@AutoValue
			class Foo {
			}
			""",
			expandedSource:
			"""
			class Foo {
			}
			""", diagnostics: [
				DiagnosticSpec(message: "@AutoValue can only be applied to structs", line: 1, column: 1)
			], macros: testMacros)
	}
}
