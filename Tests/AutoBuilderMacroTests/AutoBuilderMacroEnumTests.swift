import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import SwiftDiagnostics
import XCTest
import AutoBuilderMacros

final class AutoBuilderMacroEnumTests: XCTestCase {
    let testMacros: [String:Macro.Type] = [
        "AutoBuilder":AutoBuilderMacro.self
    ]

    func testEnumWithCases() {
        assertMacroExpansion(
            """
            @AutoBuilder
            enum Foo {
                case one(a: Int)
                case two(b: Double, c: String)
            }
            """,
            expandedSource:
            """
            enum Foo {
                case one(a: Int)
                case two(b: Double, c: String)
                init(with builder: Builder) throws {
                    self = builder.build()
                }
                func toBuilder() -> Builder {
                    let builder = Builder()
                    switch self {
                    case let .one(a):
                        let oneBuilder = builder.one
                        oneBuilder.set(a: a)
                    case let .two(b, c):
                        let twoBuilder = builder.two
                        twoBuilder.set(b: b)
                        twoBuilder.set(c: c)
                    }
                    return builder
                }
            }
            extension Foo: Buildable {
            }
            """, macros: testMacros)
    }
}
