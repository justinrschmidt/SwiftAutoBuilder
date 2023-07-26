import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import SwiftDiagnostics
import XCTest
import AutoBuilderMacros

let testMacros: [String: Macro.Type] = [
    "AutoBuilder": AutoBuilderMacro.self,
]

final class AutoBuilderMacroTests: XCTestCase {
    func testEmptyStruct() {
        assertMacroExpansion(
            """
            @AutoBuilder
            struct Foo {
            }
            """,
            expandedSource:
            """
            struct Foo {
                init(with builder: Builder) throws {
                }
                func toBuilder() -> Builder {
                    let builder = Builder()
                    return builder
                }
                class Builder: BuilderProtocol {
                    required init() {
                    }
                    func build() throws -> Foo {
                        return try Foo(with: self)
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
            @AutoBuilder
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
                func toBuilder() -> Builder {
                    let builder = Builder()
                    builder.set(a: a)
                    builder.set(b: b)
                    return builder
                }
                class Builder: BuilderProtocol {
                    let a: BuildableProperty<Int>
                    let b: BuildableProperty<Double>
                    required init() {
                        a = BuildableProperty(name: "a")
                        b = BuildableProperty(name: "b")
                    }
                    @discardableResult
                    func set(a: Int) -> Builder {
                        self.a.set(value: a)
                        return self
                    }
                    @discardableResult
                    func set(b: Double) -> Builder {
                        self.b.set(value: b)
                        return self
                    }
                    func build() throws -> Foo {
                        return try Foo(with: self)
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
            @AutoBuilder
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
                func toBuilder() -> Builder {
                    let builder = Builder()
                    builder.set(a: a)
                    return builder
                }
                class Builder: BuilderProtocol {
                    let a: BuildableProperty<Int>
                    required init() {
                        a = BuildableProperty(name: "a")
                    }
                    @discardableResult
                    func set(a: Int) -> Builder {
                        self.a.set(value: a)
                        return self
                    }
                    func build() throws -> Foo {
                        return try Foo(with: self)
                    }
                }
            }
            extension Foo: Buildable {
            }
            """, macros: testMacros)
    }

    func testStructWithStaticProperties() {
        assertMacroExpansion(
            """
            @AutoBuilder
            struct Foo {
                static var a: Double
                var b: Int
            }
            """,
            expandedSource:
            """
            struct Foo {
                static var a: Double
                var b: Int
                init(with builder: Builder) throws {
                    b = try builder.b.build()
                }
                func toBuilder() -> Builder {
                    let builder = Builder()
                    builder.set(b: b)
                    return builder
                }
                class Builder: BuilderProtocol {
                    let b: BuildableProperty<Int>
                    required init() {
                        b = BuildableProperty(name: "b")
                    }
                    @discardableResult
                    func set(b: Int) -> Builder {
                        self.b.set(value: b)
                        return self
                    }
                    func build() throws -> Foo {
                        return try Foo(with: self)
                    }
                }
            }
            extension Foo: Buildable {
            }
            """, macros: testMacros)
    }

    func testGenericStructWithStoredProperties() {
        assertMacroExpansion(
            """
            @AutoBuilder
            struct Foo<T> {
                let a: T
            }
            """,
            expandedSource:
            """
            struct Foo<T> {
                let a: T
                init(with builder: Builder) throws {
                    a = try builder.a.build()
                }
                func toBuilder() -> Builder {
                    let builder = Builder()
                    builder.set(a: a)
                    return builder
                }
                class Builder: BuilderProtocol {
                    let a: BuildableProperty<T>
                    required init() {
                        a = BuildableProperty(name: "a")
                    }
                    @discardableResult
                    func set(a: T) -> Builder {
                        self.a.set(value: a)
                        return self
                    }
                    func build() throws -> Foo {
                        return try Foo(with: self)
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
            @AutoBuilder
            class Foo {
            }
            """,
            expandedSource:
            """
            class Foo {
            }
            """, diagnostics: [
                DiagnosticSpec(
                    id: MessageID(domain: AutoBuilderDiagnostic.domain, id: "InvalidTypeForAutoBuilder"),
                    message: "@AutoBuilder can only be applied to structs",
                    line: 1,
                    column: 1,
                    severity: .error)
            ], macros: testMacros)
    }

    func testStructWithImplicitlyTypedVariable() {
        assertMacroExpansion(
            """
            @AutoBuilder
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
                    id: MessageID(domain: AutoBuilderDiagnostic.domain, id: "ImpliedVariableType"),
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
            @AutoBuilder
            struct Foo {
                let a = 0
            }
            """,
            expandedSource: """
            struct Foo {
                let a = 0
                init(with builder: Builder) throws {
                }
                func toBuilder() -> Builder {
                    let builder = Builder()
                    return builder
                }
                class Builder: BuilderProtocol {
                    required init() {
                    }
                    func build() throws -> Foo {
                        return try Foo(with: self)
                    }
                }
            }
            extension Foo: Buildable {
            }
            """, macros: testMacros)
    }

    func testStructWithArrayProperty() {
        assertMacroExpansion(
            """
            @AutoBuilder
            struct Foo {
                var a: [Int]
            }
            """,
            expandedSource: """
            struct Foo {
                var a: [Int]
                init(with builder: Builder) throws {
                    a = builder.a.build()
                }
                func toBuilder() -> Builder {
                    let builder = Builder()
                    builder.set(a: a)
                    return builder
                }
                class Builder: BuilderProtocol {
                    let a: BuildableArrayProperty<Int>
                    required init() {
                        a = BuildableArrayProperty()
                    }
                    @discardableResult
                    func set(a: [Int]) -> Builder {
                        self.a.set(value: a)
                        return self
                    }
                    @discardableResult
                    func appendTo(a element: Int) -> Builder {
                        self.a.append(element: element)
                        return self
                    }
                    @discardableResult
                    func appendTo<C>(a collection: C) -> Builder where C: Collection, C.Element == Int {
                        self.a.append(contentsOf: collection)
                        return self
                    }
                    @discardableResult
                    func removeAllFromA() -> Builder {
                        a.removeAll()
                        return self
                    }
                    func build() throws -> Foo {
                        return try Foo(with: self)
                    }
                }
            }
            extension Foo: Buildable {
            }
            """, macros: testMacros)
    }

    func testStructWithDictionaryProperty() {
        assertMacroExpansion(
            """
            @AutoBuilder
            struct Foo {
                var a: [String:Double]
            }
            """,
            expandedSource: """
            struct Foo {
                var a: [String: Double]
                init(with builder: Builder) throws {
                    a = builder.a.build()
                }
                func toBuilder() -> Builder {
                    let builder = Builder()
                    builder.set(a: a)
                    return builder
                }
                class Builder: BuilderProtocol {
                    let a: BuildableDictionaryProperty<String, Double>
                    required init() {
                        a = BuildableDictionaryProperty()
                    }
                    @discardableResult
                    func set(a: [String: Double]) -> Builder {
                        self.a.set(value: a)
                        return self
                    }
                    @discardableResult
                    func insertIntoA(key: String, value: Double) -> Builder {
                        a.insert(key: key, value: value)
                        return self
                    }
                    @discardableResult
                    func mergeIntoA(other: [String: Double], uniquingKeysWith combine: (Double, Double) throws -> Double) rethrows -> Builder {
                        try a.merge(other: other, uniquingKeysWith: combine)
                        return self
                    }
                    @discardableResult
                    func removeAllFromA() -> Builder {
                        a.removeAll()
                        return self
                    }
                    func build() throws -> Foo {
                        return try Foo(with: self)
                    }
                }
            }
            extension Foo: Buildable {
            }
            """, macros: testMacros)
    }

    func testStructWithSetProperty() {
        assertMacroExpansion(
            """
            @AutoBuilder
            struct Foo {
                var a: Set<Int>
            }
            """,
            expandedSource: """
            struct Foo {
                var a: Set<Int>
                init(with builder: Builder) throws {
                    a = builder.a.build()
                }
                func toBuilder() -> Builder {
                    let builder = Builder()
                    builder.set(a: a)
                    return builder
                }
                class Builder: BuilderProtocol {
                    let a: BuildableSetProperty<Int>
                    required init() {
                        a = BuildableSetProperty()
                    }
                    @discardableResult
                    func set(a: Set<Int>) -> Builder {
                        self.a.set(value: a)
                        return self
                    }
                    @discardableResult
                    func insertInto(a element: Int) -> Builder {
                        a.insert(element: element)
                        return self
                    }
                    @discardableResult
                    func formUnionWithA(other: Set<Int>) -> Builder {
                        a.formUnion(other: other)
                        return self
                    }
                    @discardableResult
                    func removeAllFromA() -> Builder {
                        a.removeAll()
                        return self
                    }
                    func build() throws -> Foo {
                        return try Foo(with: self)
                    }
                }
            }
            extension Foo: Buildable {
            }
            """, macros: testMacros)
    }
}
