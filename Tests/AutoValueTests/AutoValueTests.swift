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
                    init() {
                    }
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
                    let a: BuildableProperty<Int>
                    let b: BuildableProperty<Double>
                    init() {
                        a = BuildableProperty(name: "a")
                        b = BuildableProperty(name: "b")
                    }
                    func set(a: Int) -> Builder {
                        self.a.set(value: a)
                        return self
                    }
                    func set(b: Double) -> Builder {
                        self.b.set(value: b)
                        return self
                    }
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
                    let a: BuildableProperty<Int>
                    init() {
                        a = BuildableProperty(name: "a")
                    }
                    func set(a: Int) -> Builder {
                        self.a.set(value: a)
                        return self
                    }
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
