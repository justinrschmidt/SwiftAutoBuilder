import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import SwiftDiagnostics
import XCTest
import AutoBuilderMacros

let testMacros: [String: Macro.Type] = [
    "Buildable": AutoBuilderMacro.self,
]

final class AutoBuilderMacroStructTests: XCTestCase {
    func testEmptyStruct() {
        assertMacroExpansion(
            """
            @Buildable
            struct Foo {
            }
            """,
            expandedSource:
            """
            struct Foo {
            }

            extension Foo: Buildable {
                init(with builder: Builder) throws {
                }
                func toBuilder() -> Builder {
                    let builder = Builder()
                    return builder
                }
                public class Builder: BuilderProtocol {
                    public required init() {
                    }
                    public func build() throws -> Foo {
                        return try Foo(with: self)
                    }
                }
            }
            """, macros: testMacros)
    }

    func testStructWithStoredProperties() {
        assertMacroExpansion(
            """
            @Buildable
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
            }

            extension Foo: Buildable {
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
                public class Builder: BuilderProtocol {
                    public let a: BuildableProperty<Int>
                    public let b: BuildableProperty<Double>
                    public required init() {
                        a = BuildableProperty(name: "a")
                        b = BuildableProperty(name: "b")
                    }
                    @discardableResult
                    public func set(a: Int) -> Builder {
                        self.a.set(value: a)
                        return self
                    }
                    @discardableResult
                    public func set(b: Double) -> Builder {
                        self.b.set(value: b)
                        return self
                    }
                    public func build() throws -> Foo {
                        return try Foo(with: self)
                    }
                }
            }
            """, macros: testMacros)
    }

    func testStructWithComputedProperties() {
        assertMacroExpansion(
            """
            @Buildable
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
            }

            extension Foo: Buildable {
                init(with builder: Builder) throws {
                    a = try builder.a.build()
                }
                func toBuilder() -> Builder {
                    let builder = Builder()
                    builder.set(a: a)
                    return builder
                }
                public class Builder: BuilderProtocol {
                    public let a: BuildableProperty<Int>
                    public required init() {
                        a = BuildableProperty(name: "a")
                    }
                    @discardableResult
                    public func set(a: Int) -> Builder {
                        self.a.set(value: a)
                        return self
                    }
                    public func build() throws -> Foo {
                        return try Foo(with: self)
                    }
                }
            }
            """, macros: testMacros)
    }

    func testStructWithStaticProperties() {
        assertMacroExpansion(
            """
            @Buildable
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
            }

            extension Foo: Buildable {
                init(with builder: Builder) throws {
                    b = try builder.b.build()
                }
                func toBuilder() -> Builder {
                    let builder = Builder()
                    builder.set(b: b)
                    return builder
                }
                public class Builder: BuilderProtocol {
                    public let b: BuildableProperty<Int>
                    public required init() {
                        b = BuildableProperty(name: "b")
                    }
                    @discardableResult
                    public func set(b: Int) -> Builder {
                        self.b.set(value: b)
                        return self
                    }
                    public func build() throws -> Foo {
                        return try Foo(with: self)
                    }
                }
            }
            """, macros: testMacros)
    }

    func testGenericStructWithStoredProperties() {
        assertMacroExpansion(
            """
            @Buildable
            struct Foo<T> {
                let a: T
            }
            """,
            expandedSource:
            """
            struct Foo<T> {
                let a: T
            }

            extension Foo: Buildable {
                init(with builder: Builder) throws {
                    a = try builder.a.build()
                }
                func toBuilder() -> Builder {
                    let builder = Builder()
                    builder.set(a: a)
                    return builder
                }
                public class Builder: BuilderProtocol {
                    public let a: BuildableProperty<T>
                    public required init() {
                        a = BuildableProperty(name: "a")
                    }
                    @discardableResult
                    public func set(a: T) -> Builder {
                        self.a.set(value: a)
                        return self
                    }
                    public func build() throws -> Foo {
                        return try Foo(with: self)
                    }
                }
            }
            """, macros: testMacros)
    }

    func testInvalidType() {
        assertMacroExpansion(
            """
            @Buildable
            protocol Foo {
            }
            """,
            expandedSource:
            """
            protocol Foo {
            }
            """, diagnostics: [
                DiagnosticSpec(
                    id: MessageID(domain: AutoBuilderDiagnostic.domain, id: "InvalidTypeForAutoBuilder"),
                    message: "@Buildable can only be applied to structs and enums",
                    line: 1,
                    column: 1,
                    severity: .error)
            ], macros: testMacros)
    }

    func testStructWithImplicitlyTypedVariable() {
        assertMacroExpansion(
            """
            @Buildable
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
                    message: "Type annotation missing for 'bar'. @Buildable requires all variable properties to have type annotations.",
                    line: 3,
                    column: 9,
                    severity: .error)
            ],
            macros: testMacros)
    }

    func testStructWithImplicitlyTypedConstant() {
        assertMacroExpansion(
            """
            @Buildable
            struct Foo {
                let a = 0
            }
            """,
            expandedSource: """
            struct Foo {
                let a = 0
            }

            extension Foo: Buildable {
                init(with builder: Builder) throws {
                }
                func toBuilder() -> Builder {
                    let builder = Builder()
                    return builder
                }
                public class Builder: BuilderProtocol {
                    public required init() {
                    }
                    public func build() throws -> Foo {
                        return try Foo(with: self)
                    }
                }
            }
            """, macros: testMacros)
    }

    func testStructWithArrayProperty() {
        assertMacroExpansion(
            """
            @Buildable
            struct Foo {
                var a: [Int]
            }
            """,
            expandedSource: """
            struct Foo {
                var a: [Int]
            }

            extension Foo: Buildable {
                init(with builder: Builder) throws {
                    a = builder.a.build()
                }
                func toBuilder() -> Builder {
                    let builder = Builder()
                    builder.set(a: a)
                    return builder
                }
                public class Builder: BuilderProtocol {
                    public let a: BuildableArrayProperty<Int>
                    public required init() {
                        a = BuildableArrayProperty()
                    }
                    @discardableResult
                    public func set(a: [Int]) -> Builder {
                        self.a.set(value: a)
                        return self
                    }
                    @discardableResult
                    public func appendTo(a element: Int) -> Builder {
                        self.a.append(element: element)
                        return self
                    }
                    @discardableResult
                    public func appendTo<C>(a collection: C) -> Builder where C: Collection, C.Element == Int {
                        self.a.append(contentsOf: collection)
                        return self
                    }
                    @discardableResult
                    public func removeAllFromA() -> Builder {
                        a.removeAll()
                        return self
                    }
                    public func build() throws -> Foo {
                        return try Foo(with: self)
                    }
                }
            }
            """, macros: testMacros)
    }

    func testStructWithDictionaryProperty() {
        assertMacroExpansion(
            """
            @Buildable
            struct Foo {
                var a: [String:Double]
            }
            """,
            expandedSource: """
            struct Foo {
                var a: [String:Double]
            }

            extension Foo: Buildable {
                init(with builder: Builder) throws {
                    a = builder.a.build()
                }
                func toBuilder() -> Builder {
                    let builder = Builder()
                    builder.set(a: a)
                    return builder
                }
                public class Builder: BuilderProtocol {
                    public let a: BuildableDictionaryProperty<String, Double>
                    public required init() {
                        a = BuildableDictionaryProperty()
                    }
                    @discardableResult
                    public func set(a: [String: Double]) -> Builder {
                        self.a.set(value: a)
                        return self
                    }
                    @discardableResult
                    public func insertInto(a value: Double, forKey key: String) -> Builder {
                        a.insert(key: key, value: value)
                        return self
                    }
                    @discardableResult
                    public func mergeIntoA(other: [String: Double], uniquingKeysWith combine: (Double, Double) throws -> Double) rethrows -> Builder {
                        try a.merge(other: other, uniquingKeysWith: combine)
                        return self
                    }
                    @discardableResult
                    public func removeAllFromA() -> Builder {
                        a.removeAll()
                        return self
                    }
                    public func build() throws -> Foo {
                        return try Foo(with: self)
                    }
                }
            }
            """, macros: testMacros)
    }

    func testStructWithSetProperty() {
        assertMacroExpansion(
            """
            @Buildable
            struct Foo {
                var a: Set<Int>
            }
            """,
            expandedSource: """
            struct Foo {
                var a: Set<Int>
            }

            extension Foo: Buildable {
                init(with builder: Builder) throws {
                    a = builder.a.build()
                }
                func toBuilder() -> Builder {
                    let builder = Builder()
                    builder.set(a: a)
                    return builder
                }
                public class Builder: BuilderProtocol {
                    public let a: BuildableSetProperty<Int>
                    public required init() {
                        a = BuildableSetProperty()
                    }
                    @discardableResult
                    public func set(a: Set<Int>) -> Builder {
                        self.a.set(value: a)
                        return self
                    }
                    @discardableResult
                    public func insertInto(a element: Int) -> Builder {
                        a.insert(element: element)
                        return self
                    }
                    @discardableResult
                    public func formUnionWithA(other: Set<Int>) -> Builder {
                        a.formUnion(other: other)
                        return self
                    }
                    @discardableResult
                    public func removeAllFromA() -> Builder {
                        a.removeAll()
                        return self
                    }
                    public func build() throws -> Foo {
                        return try Foo(with: self)
                    }
                }
            }
            """, macros: testMacros)
    }

    func testStructWithOptionalProperty() {
        assertMacroExpansion(
            """
            @Buildable
            struct Foo {
                var a: Int?
            }
            """,
            expandedSource: """
            struct Foo {
                var a: Int?
            }

            extension Foo: Buildable {
                init(with builder: Builder) throws {
                    a = try builder.a.build()
                }
                func toBuilder() -> Builder {
                    let builder = Builder()
                    builder.set(a: a)
                    return builder
                }
                public class Builder: BuilderProtocol {
                    public let a: BuildableOptionalProperty<Int>
                    public required init() {
                        a = BuildableOptionalProperty(name: "a")
                    }
                    @discardableResult
                    public func set(a: Int?) -> Builder {
                        self.a.set(value: a)
                        return self
                    }
                    public func build() throws -> Foo {
                        return try Foo(with: self)
                    }
                }
            }
            """, macros: testMacros)
    }

    func testPublicStructWithStoredProperty() {
        assertMacroExpansion(
            """
            @Buildable
            public struct Foo {
                let a: Int
            }
            """,
            expandedSource:
            """
            public struct Foo {
                let a: Int
            }

            extension Foo: Buildable {
                public init(with builder: Builder) throws {
                    a = try builder.a.build()
                }
                public func toBuilder() -> Builder {
                    let builder = Builder()
                    builder.set(a: a)
                    return builder
                }
                public class Builder: BuilderProtocol {
                    public let a: BuildableProperty<Int>
                    public required init() {
                        a = BuildableProperty(name: "a")
                    }
                    @discardableResult
                    public func set(a: Int) -> Builder {
                        self.a.set(value: a)
                        return self
                    }
                    public func build() throws -> Foo {
                        return try Foo(with: self)
                    }
                }
            }
            """, macros: testMacros)
    }

    func testOpenStructWithStoredProperty() {
        assertMacroExpansion(
            """
            @Buildable
            open struct Foo {
                let a: Int
            }
            """,
            expandedSource:
            """
            open struct Foo {
                let a: Int
            }

            extension Foo: Buildable {
                public init(with builder: Builder) throws {
                    a = try builder.a.build()
                }
                public func toBuilder() -> Builder {
                    let builder = Builder()
                    builder.set(a: a)
                    return builder
                }
                public class Builder: BuilderProtocol {
                    public let a: BuildableProperty<Int>
                    public required init() {
                        a = BuildableProperty(name: "a")
                    }
                    @discardableResult
                    public func set(a: Int) -> Builder {
                        self.a.set(value: a)
                        return self
                    }
                    public func build() throws -> Foo {
                        return try Foo(with: self)
                    }
                }
            }
            """, macros: testMacros)
    }

    func testNestedStructs() {
        assertMacroExpansion(
            """
            struct RootStruct {
                @Buildable
                struct A {
                    let b: RootStruct.B
                }
                struct B {
                    let i: Int
                }
            }
            """,
            expandedSource:
            """
            struct RootStruct {
                struct A {
                    let b: RootStruct.B
                }
                struct B {
                    let i: Int
                }
            }

            extension A: Buildable {
                init(with builder: Builder) throws {
                    b = try builder.b.build()
                }
                func toBuilder() -> Builder {
                    let builder = Builder()
                    builder.set(b: b)
                    return builder
                }
                public class Builder: BuilderProtocol {
                    public let b: BuildableProperty<RootStruct.B>
                    public required init() {
                        b = BuildableProperty(name: "b")
                    }
                    @discardableResult
                    public func set(b: RootStruct.B) -> Builder {
                        self.b.set(value: b)
                        return self
                    }
                    public func build() throws -> A {
                        return try A(with: self)
                    }
                }
            }
            """, macros: testMacros)
    }
}
