import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import AutoValueMacros

let testMacros: [String: Macro.Type] = [
	"AutoValue": AutoValueMacro.self,
]

final class AutoValueTests: XCTestCase {
	func testAutoValue_emptyStruct() {
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
}
