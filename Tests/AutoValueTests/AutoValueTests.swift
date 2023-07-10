import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import AutoValueMacros

let testMacros: [String: Macro.Type] = [
    "stringify": StringifyMacro.self,
	"AutoValue": AutoValueMacro.self,
]

final class AutoValueTests: XCTestCase {
    func testMacro() {
        assertMacroExpansion(
            """
            #stringify(a + b)
            """,
            expandedSource: """
            (a + b, "a + b")
            """,
            macros: testMacros
        )
    }

    func testMacroWithStringLiteral() {
        assertMacroExpansion(
            #"""
            #stringify("Hello, \(name)")
            """#,
            expandedSource: #"""
            ("Hello, \(name)", #""Hello, \(name)""#)
            """#,
            macros: testMacros
        )
    }

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
