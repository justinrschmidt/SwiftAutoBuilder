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
			    init(with builder: Builder) {
			    }
			    class Builder {
			    }
			}
			""", macros: testMacros)
	}

	func testStructWithStoredProperties() {
		assertMacroExpansion(
			"""
			@AutoValue
			struct Foo {
				let a: Int
				let b: Double
			}
			""",
			expandedSource:
			"""
			struct Foo {
				let a: Int
				let b: Double
				init(with builder: Builder) {
				}
				class Builder {
				}
			}
			""", macros: testMacros)
	}

	func testStructWithComputedProperties() {
		assertMacroExpansion(
			"""
			@AutoValue
			struct Foo {
				let a: Int
				var b: Int {
					get {
						return a
					}
					set {
						a = newValue
					}
				}
			}
			""",
			expandedSource:
			"""
			struct Foo {
				let a: Int
				var b: Int {
					get {
						return a
					}
					set {
						a = newValue
					}
				}
				init(with builder: Builder) {
				}
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
