import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import SwiftDiagnostics
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
                init(with builder: Builder) throws {
                }
                class Builder: BuilderProtocol {
                    init() {
                    }
                }
            }
            extension Foo: Buildable {
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
                init(with builder: Builder) throws {
                    a = try builder.a.build()
                    b = try builder.b.build()
                }
                class Builder: BuilderProtocol {
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
            extension Foo: Buildable {
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
                init(with builder: Builder) throws {
                    a = try builder.a.build()
                }
                class Builder: BuilderProtocol {
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
            extension Foo: Buildable {
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
                DiagnosticSpec(
                    id: MessageID(domain: AutoValueDiagnostic.domain, id: "InvalidTypeForAutoValue"),
                    message: "@AutoValue can only be applied to structs",
                    line: 1,
                    column: 1,
                    severity: .error)
            ], macros: testMacros)
    }

    func testStructWithImplicitlyTypedVariable() {
        assertMacroExpansion(
            """
            @AutoValue
            struct Foo {
                var bar = 0
            }
            """,
            expandedSource: """
            struct Foo {
                var bar = 0
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    id: MessageID(domain: AutoValueDiagnostic.domain, id: "ImpliedVariableType"),
                    message: "Type annotation missing for 'bar'. AutoBuilder requires all variable properties to have type annotations.",
                    line: 3,
                    column: 9,
                    severity: .error)
            ],
            macros: testMacros)
    }

    func testStructWithImplicitlyTypedConstant() {
        assertMacroExpansion(
            """
            @AutoValue
            struct Foo {
                let a = 0
            }
            """,
            expandedSource: """
            struct Foo {
                let a = 0
                init(with builder: Builder) throws {
                }
                class Builder: BuilderProtocol {
                    init() {
                    }
                }
            }
            extension Foo: Buildable {
            }
            """, macros: testMacros)
    }
}
