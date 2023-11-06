import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import SwiftDiagnostics
import XCTest
import AutoBuilderMacros

final class AutoBuilderMacroEnumTests: XCTestCase {
    let testMacros: [String: Macro.Type] = [
        "Buildable": AutoBuilderMacro.self
    ]

    func testEnumWithNoCases() {
        assertMacroExpansion(
            """
            @Buildable
            enum Foo {
            }
            """,
            expandedSource: """
            enum Foo {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    id: MessageID(domain: AutoBuilderDiagnostic.domain, id: "EnumWithNoCases"),
                    message: "Foo (aka: Never) does not have any cases and cannot be instantiated.",
                    line: 1,
                    column: 1,
                    severity: .error)
            ],
            macros: testMacros)
    }

    func testEnumWithCases() {
        assertMacroExpansion(
            """
            @Buildable
            enum Foo {
                case one(a: Int)
                case two(b: Double, c: String)
            }
            """,
            expandedSource: """
            enum Foo {
                case one(a: Int)
                case two(b: Double, c: String)
            }

            extension Foo: Buildable {
                init(with builder: Builder) throws {
                    self = try builder.build()
                }
                func toBuilder() -> Builder {
                    let builder = Builder()
                    builder.set(value: self)
                    return builder
                }
                public class Builder: BuilderProtocol {
                    private var currentCase: BuilderCases?
                    public required init() {
                        currentCase = nil
                    }
                    public var one: One {
                        get {
                            switch currentCase {
                            case let .some(.one(builder)):
                                return builder
                            default:
                                let builder = One()
                                currentCase = .one(builder)
                                return builder
                            }
                        }
                        set {
                            currentCase = .one(newValue)
                        }
                    }
                    public var two: Two {
                        get {
                            switch currentCase {
                            case let .some(.two(builder)):
                                return builder
                            default:
                                let builder = Two()
                                currentCase = .two(builder)
                                return builder
                            }
                        }
                        set {
                            currentCase = .two(newValue)
                        }
                    }
                    public func set(value: Foo) {
                        switch value {
                        case let .one(a):
                            let builder = One()
                            builder.set(a: a)
                            currentCase = .one(builder)
                        case let .two(b, c):
                            let builder = Two()
                            builder.set(b: b)
                            builder.set(c: c)
                            currentCase = .two(builder)
                        }
                    }
                    public func build() throws -> Foo {
                        switch currentCase {
                        case let .some(.one(builder)):
                            return try builder.build()
                        case let .some(.two(builder)):
                            return try builder.build()
                        case .none:
                            throw BuilderError.noEnumCaseSet
                        }
                    }
                    public class One: BuilderProtocol {
                        public let a: BuildableProperty<Int>
                        public required init() {
                            a = BuildableProperty(name: "a")
                        }
                        @discardableResult
                        public func set(a: Int) -> One {
                            self.a.set(value: a)
                            return self
                        }
                        public func build() throws -> Foo {
                            return try .one(a: a.build())
                        }
                    }
                    public class Two: BuilderProtocol {
                        public let b: BuildableProperty<Double>
                        public let c: BuildableProperty<String>
                        public required init() {
                            b = BuildableProperty(name: "b")
                            c = BuildableProperty(name: "c")
                        }
                        @discardableResult
                        public func set(b: Double) -> Two {
                            self.b.set(value: b)
                            return self
                        }
                        @discardableResult
                        public func set(c: String) -> Two {
                            self.c.set(value: c)
                            return self
                        }
                        public func build() throws -> Foo {
                            return try .two(b: b.build(), c: c.build())
                        }
                    }
                    private enum BuilderCases {
                        case one(One)
                        case two(Two)
                    }
                }
            }
            """,
            macros: testMacros)
    }

    func testEnumWithNoAssociatedValues() {
        assertMacroExpansion(
            """
            @Buildable
            enum Foo {
                case one
                case two
            }
            """,
            expandedSource: """
            enum Foo {
                case one
                case two
            }

            extension Foo: Buildable {
                init(with builder: Builder) throws {
                    self = try builder.build()
                }
                func toBuilder() -> Builder {
                    let builder = Builder()
                    builder.set(value: self)
                    return builder
                }
                public class Builder: BuilderProtocol {
                    private var currentCase: BuilderCases?
                    public required init() {
                        currentCase = nil
                    }
                    public var one: One {
                        get {
                            switch currentCase {
                            case let .some(.one(builder)):
                                return builder
                            default:
                                let builder = One()
                                currentCase = .one(builder)
                                return builder
                            }
                        }
                        set {
                            currentCase = .one(newValue)
                        }
                    }
                    public var two: Two {
                        get {
                            switch currentCase {
                            case let .some(.two(builder)):
                                return builder
                            default:
                                let builder = Two()
                                currentCase = .two(builder)
                                return builder
                            }
                        }
                        set {
                            currentCase = .two(newValue)
                        }
                    }
                    public func set(value: Foo) {
                        switch value {
                        case .one:
                            let builder = One()
                            currentCase = .one(builder)
                        case .two:
                            let builder = Two()
                            currentCase = .two(builder)
                        }
                    }
                    public func build() throws -> Foo {
                        switch currentCase {
                        case let .some(.one(builder)):
                            return try builder.build()
                        case let .some(.two(builder)):
                            return try builder.build()
                        case .none:
                            throw BuilderError.noEnumCaseSet
                        }
                    }
                    public class One: BuilderProtocol {
                        public required init() {
                        }
                        public func build() throws -> Foo {
                            return .one
                        }
                    }
                    public class Two: BuilderProtocol {
                        public required init() {
                        }
                        public func build() throws -> Foo {
                            return .two
                        }
                    }
                    private enum BuilderCases {
                        case one(One)
                        case two(Two)
                    }
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    id: MessageID(domain: AutoBuilderDiagnostic.domain, id: "NoAssociatedValues"),
                    message: "Foo does not have any cases with associated values.",
                    line: 1,
                    column: 1,
                    severity: .warning)
            ],
            macros: testMacros)
    }

    func testEnumWithCasesWithAndWithoutAssociatedValues() {
        assertMacroExpansion(
            """
            @Buildable
            enum Foo {
                case one(a: Int)
                case two
            }
            """,
            expandedSource: """
            enum Foo {
                case one(a: Int)
                case two
            }

            extension Foo: Buildable {
                init(with builder: Builder) throws {
                    self = try builder.build()
                }
                func toBuilder() -> Builder {
                    let builder = Builder()
                    builder.set(value: self)
                    return builder
                }
                public class Builder: BuilderProtocol {
                    private var currentCase: BuilderCases?
                    public required init() {
                        currentCase = nil
                    }
                    public var one: One {
                        get {
                            switch currentCase {
                            case let .some(.one(builder)):
                                return builder
                            default:
                                let builder = One()
                                currentCase = .one(builder)
                                return builder
                            }
                        }
                        set {
                            currentCase = .one(newValue)
                        }
                    }
                    public var two: Two {
                        get {
                            switch currentCase {
                            case let .some(.two(builder)):
                                return builder
                            default:
                                let builder = Two()
                                currentCase = .two(builder)
                                return builder
                            }
                        }
                        set {
                            currentCase = .two(newValue)
                        }
                    }
                    public func set(value: Foo) {
                        switch value {
                        case let .one(a):
                            let builder = One()
                            builder.set(a: a)
                            currentCase = .one(builder)
                        case .two:
                            let builder = Two()
                            currentCase = .two(builder)
                        }
                    }
                    public func build() throws -> Foo {
                        switch currentCase {
                        case let .some(.one(builder)):
                            return try builder.build()
                        case let .some(.two(builder)):
                            return try builder.build()
                        case .none:
                            throw BuilderError.noEnumCaseSet
                        }
                    }
                    public class One: BuilderProtocol {
                        public let a: BuildableProperty<Int>
                        public required init() {
                            a = BuildableProperty(name: "a")
                        }
                        @discardableResult
                        public func set(a: Int) -> One {
                            self.a.set(value: a)
                            return self
                        }
                        public func build() throws -> Foo {
                            return try .one(a: a.build())
                        }
                    }
                    public class Two: BuilderProtocol {
                        public required init() {
                        }
                        public func build() throws -> Foo {
                            return .two
                        }
                    }
                    private enum BuilderCases {
                        case one(One)
                        case two(Two)
                    }
                }
            }
            """,
            macros: testMacros)
    }

    func testEnumCaseWithMissingLabels() {
        assertMacroExpansion(
            """
            @Buildable
            enum Foo {
                case one(Int, b: Double, String)
            }
            """,
            expandedSource: """
            enum Foo {
                case one(Int, b: Double, String)
            }

            extension Foo: Buildable {
                init(with builder: Builder) throws {
                    self = try builder.build()
                }
                func toBuilder() -> Builder {
                    let builder = Builder()
                    builder.set(value: self)
                    return builder
                }
                public class Builder: BuilderProtocol {
                    private var currentCase: BuilderCases?
                    public required init() {
                        currentCase = nil
                    }
                    public var one: One {
                        get {
                            switch currentCase {
                            case let .some(.one(builder)):
                                return builder
                            default:
                                let builder = One()
                                currentCase = .one(builder)
                                return builder
                            }
                        }
                        set {
                            currentCase = .one(newValue)
                        }
                    }
                    public func set(value: Foo) {
                        switch value {
                        case let .one(i0, b, i2):
                            let builder = One()
                            builder.set(index_0: i0)
                            builder.set(b: b)
                            builder.set(index_2: i2)
                            currentCase = .one(builder)
                        }
                    }
                    public func build() throws -> Foo {
                        switch currentCase {
                        case let .some(.one(builder)):
                            return try builder.build()
                        case .none:
                            throw BuilderError.noEnumCaseSet
                        }
                    }
                    public class One: BuilderProtocol {
                        public let index_0: BuildableProperty<Int>
                        public let b: BuildableProperty<Double>
                        public let index_2: BuildableProperty<String>
                        public required init() {
                            index_0 = BuildableProperty(name: "index_0")
                            b = BuildableProperty(name: "b")
                            index_2 = BuildableProperty(name: "index_2")
                        }
                        @discardableResult
                        public func set(index_0: Int) -> One {
                            self.index_0.set(value: index_0)
                            return self
                        }
                        @discardableResult
                        public func set(b: Double) -> One {
                            self.b.set(value: b)
                            return self
                        }
                        @discardableResult
                        public func set(index_2: String) -> One {
                            self.index_2.set(value: index_2)
                            return self
                        }
                        public func build() throws -> Foo {
                            return try .one(index_0.build(), b: b.build(), index_2.build())
                        }
                    }
                    private enum BuilderCases {
                        case one(One)
                    }
                }
            }
            """,
            macros: testMacros)
    }

    func testEnumWithOverloadedCase() {
        assertMacroExpansion(
            """
            @Buildable
            enum Foo {
                case one(Int)
                case one(Int, Int)
                case one(Int, a: Int)
                case one(a: Int, Int)
                case one(b: Double, Int)
            }
            """,
            expandedSource: """
            enum Foo {
                case one(Int)
                case one(Int, Int)
                case one(Int, a: Int)
                case one(a: Int, Int)
                case one(b: Double, Int)
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    id: MessageID(domain: AutoBuilderDiagnostic.domain, id: "EnumWithOverloadedCases"),
                    message: "@Buildable does not support overloaded cases (one) due to ambiguity caused by SE-0155 not being fully implemented.",
                    line: 1,
                    column: 1,
                    severity: .error)
            ],
            macros: testMacros)
    }

    func testEnumWithArrayAssociatedValue() {
        assertMacroExpansion(
            """
            @Buildable
            enum Foo {
                case one(a: [Int], [Int])
            }
            """,
            expandedSource: """
            enum Foo {
                case one(a: [Int], [Int])
            }

            extension Foo: Buildable {
                init(with builder: Builder) throws {
                    self = try builder.build()
                }
                func toBuilder() -> Builder {
                    let builder = Builder()
                    builder.set(value: self)
                    return builder
                }
                public class Builder: BuilderProtocol {
                    private var currentCase: BuilderCases?
                    public required init() {
                        currentCase = nil
                    }
                    public var one: One {
                        get {
                            switch currentCase {
                            case let .some(.one(builder)):
                                return builder
                            default:
                                let builder = One()
                                currentCase = .one(builder)
                                return builder
                            }
                        }
                        set {
                            currentCase = .one(newValue)
                        }
                    }
                    public func set(value: Foo) {
                        switch value {
                        case let .one(a, i1):
                            let builder = One()
                            builder.set(a: a)
                            builder.set(index_1: i1)
                            currentCase = .one(builder)
                        }
                    }
                    public func build() throws -> Foo {
                        switch currentCase {
                        case let .some(.one(builder)):
                            return try builder.build()
                        case .none:
                            throw BuilderError.noEnumCaseSet
                        }
                    }
                    public class One: BuilderProtocol {
                        public let a: BuildableArrayProperty<Int>
                        public let index_1: BuildableArrayProperty<Int>
                        public required init() {
                            a = BuildableArrayProperty()
                            index_1 = BuildableArrayProperty()
                        }
                        @discardableResult
                        public func set(a: [Int]) -> One {
                            self.a.set(value: a)
                            return self
                        }
                        @discardableResult
                        public func appendTo(a element: Int) -> One {
                            self.a.append(element: element)
                            return self
                        }
                        @discardableResult
                        public func appendTo<C>(a collection: C) -> One where C: Collection, C.Element == Int {
                            self.a.append(contentsOf: collection)
                            return self
                        }
                        @discardableResult
                        public func removeAllFromA() -> One {
                            a.removeAll()
                            return self
                        }
                        @discardableResult
                        public func set(index_1: [Int]) -> One {
                            self.index_1.set(value: index_1)
                            return self
                        }
                        @discardableResult
                        public func appendTo(index_1 element: Int) -> One {
                            self.index_1.append(element: element)
                            return self
                        }
                        @discardableResult
                        public func appendTo<C>(index_1 collection: C) -> One where C: Collection, C.Element == Int {
                            self.index_1.append(contentsOf: collection)
                            return self
                        }
                        @discardableResult
                        public func removeAllFromIndex_1() -> One {
                            index_1.removeAll()
                            return self
                        }
                        public func build() throws -> Foo {
                            return .one(a: a.build(), index_1.build())
                        }
                    }
                    private enum BuilderCases {
                        case one(One)
                    }
                }
            }
            """,
            macros: testMacros)
    }

    func testEnumWithDictionaryAssociatedValue() {
        assertMacroExpansion(
            """
            @Buildable
            enum Foo {
                case one(a: [String:Int], [String:Int])
            }
            """,
            expandedSource: """
            enum Foo {
                case one(a: [String:Int], [String:Int])
            }

            extension Foo: Buildable {
                init(with builder: Builder) throws {
                    self = try builder.build()
                }
                func toBuilder() -> Builder {
                    let builder = Builder()
                    builder.set(value: self)
                    return builder
                }
                public class Builder: BuilderProtocol {
                    private var currentCase: BuilderCases?
                    public required init() {
                        currentCase = nil
                    }
                    public var one: One {
                        get {
                            switch currentCase {
                            case let .some(.one(builder)):
                                return builder
                            default:
                                let builder = One()
                                currentCase = .one(builder)
                                return builder
                            }
                        }
                        set {
                            currentCase = .one(newValue)
                        }
                    }
                    public func set(value: Foo) {
                        switch value {
                        case let .one(a, i1):
                            let builder = One()
                            builder.set(a: a)
                            builder.set(index_1: i1)
                            currentCase = .one(builder)
                        }
                    }
                    public func build() throws -> Foo {
                        switch currentCase {
                        case let .some(.one(builder)):
                            return try builder.build()
                        case .none:
                            throw BuilderError.noEnumCaseSet
                        }
                    }
                    public class One: BuilderProtocol {
                        public let a: BuildableDictionaryProperty<String, Int>
                        public let index_1: BuildableDictionaryProperty<String, Int>
                        public required init() {
                            a = BuildableDictionaryProperty()
                            index_1 = BuildableDictionaryProperty()
                        }
                        @discardableResult
                        public func set(a: [String: Int]) -> One {
                            self.a.set(value: a)
                            return self
                        }
                        @discardableResult
                        public func insertInto(a value: Int, forKey key: String) -> One {
                            a.insert(key: key, value: value)
                            return self
                        }
                        @discardableResult
                        public func mergeIntoA(other: [String: Int], uniquingKeysWith combine: (Int, Int) throws -> Int) rethrows -> One {
                            try a.merge(other: other, uniquingKeysWith: combine)
                            return self
                        }
                        @discardableResult
                        public func removeAllFromA() -> One {
                            a.removeAll()
                            return self
                        }
                        @discardableResult
                        public func set(index_1: [String: Int]) -> One {
                            self.index_1.set(value: index_1)
                            return self
                        }
                        @discardableResult
                        public func insertInto(index_1 value: Int, forKey key: String) -> One {
                            index_1.insert(key: key, value: value)
                            return self
                        }
                        @discardableResult
                        public func mergeIntoIndex_1(other: [String: Int], uniquingKeysWith combine: (Int, Int) throws -> Int) rethrows -> One {
                            try index_1.merge(other: other, uniquingKeysWith: combine)
                            return self
                        }
                        @discardableResult
                        public func removeAllFromIndex_1() -> One {
                            index_1.removeAll()
                            return self
                        }
                        public func build() throws -> Foo {
                            return .one(a: a.build(), index_1.build())
                        }
                    }
                    private enum BuilderCases {
                        case one(One)
                    }
                }
            }
            """,
            macros: testMacros)
    }

    func testEnumWithSetAssociatedValue() {
        assertMacroExpansion(
            """
            @Buildable
            enum Foo {
                case one(a: Set<Int>, Set<Int>)
            }
            """,
            expandedSource: """
            enum Foo {
                case one(a: Set<Int>, Set<Int>)
            }

            extension Foo: Buildable {
                init(with builder: Builder) throws {
                    self = try builder.build()
                }
                func toBuilder() -> Builder {
                    let builder = Builder()
                    builder.set(value: self)
                    return builder
                }
                public class Builder: BuilderProtocol {
                    private var currentCase: BuilderCases?
                    public required init() {
                        currentCase = nil
                    }
                    public var one: One {
                        get {
                            switch currentCase {
                            case let .some(.one(builder)):
                                return builder
                            default:
                                let builder = One()
                                currentCase = .one(builder)
                                return builder
                            }
                        }
                        set {
                            currentCase = .one(newValue)
                        }
                    }
                    public func set(value: Foo) {
                        switch value {
                        case let .one(a, i1):
                            let builder = One()
                            builder.set(a: a)
                            builder.set(index_1: i1)
                            currentCase = .one(builder)
                        }
                    }
                    public func build() throws -> Foo {
                        switch currentCase {
                        case let .some(.one(builder)):
                            return try builder.build()
                        case .none:
                            throw BuilderError.noEnumCaseSet
                        }
                    }
                    public class One: BuilderProtocol {
                        public let a: BuildableSetProperty<Int>
                        public let index_1: BuildableSetProperty<Int>
                        public required init() {
                            a = BuildableSetProperty()
                            index_1 = BuildableSetProperty()
                        }
                        @discardableResult
                        public func set(a: Set<Int>) -> One {
                            self.a.set(value: a)
                            return self
                        }
                        @discardableResult
                        public func insertInto(a element: Int) -> One {
                            a.insert(element: element)
                            return self
                        }
                        @discardableResult
                        public func formUnionWithA(other: Set<Int>) -> One {
                            a.formUnion(other: other)
                            return self
                        }
                        @discardableResult
                        public func removeAllFromA() -> One {
                            a.removeAll()
                            return self
                        }
                        @discardableResult
                        public func set(index_1: Set<Int>) -> One {
                            self.index_1.set(value: index_1)
                            return self
                        }
                        @discardableResult
                        public func insertInto(index_1 element: Int) -> One {
                            index_1.insert(element: element)
                            return self
                        }
                        @discardableResult
                        public func formUnionWithIndex_1(other: Set<Int>) -> One {
                            index_1.formUnion(other: other)
                            return self
                        }
                        @discardableResult
                        public func removeAllFromIndex_1() -> One {
                            index_1.removeAll()
                            return self
                        }
                        public func build() throws -> Foo {
                            return .one(a: a.build(), index_1.build())
                        }
                    }
                    private enum BuilderCases {
                        case one(One)
                    }
                }
            }
            """,
            macros: testMacros)
    }

    func testEnumWithOptionalAssociatedValue() {
        assertMacroExpansion(
            """
            @Buildable
            enum Foo {
                case one(a: Int?, Int?)
            }
            """,
            expandedSource: """
            enum Foo {
                case one(a: Int?, Int?)
            }

            extension Foo: Buildable {
                init(with builder: Builder) throws {
                    self = try builder.build()
                }
                func toBuilder() -> Builder {
                    let builder = Builder()
                    builder.set(value: self)
                    return builder
                }
                public class Builder: BuilderProtocol {
                    private var currentCase: BuilderCases?
                    public required init() {
                        currentCase = nil
                    }
                    public var one: One {
                        get {
                            switch currentCase {
                            case let .some(.one(builder)):
                                return builder
                            default:
                                let builder = One()
                                currentCase = .one(builder)
                                return builder
                            }
                        }
                        set {
                            currentCase = .one(newValue)
                        }
                    }
                    public func set(value: Foo) {
                        switch value {
                        case let .one(a, i1):
                            let builder = One()
                            builder.set(a: a)
                            builder.set(index_1: i1)
                            currentCase = .one(builder)
                        }
                    }
                    public func build() throws -> Foo {
                        switch currentCase {
                        case let .some(.one(builder)):
                            return try builder.build()
                        case .none:
                            throw BuilderError.noEnumCaseSet
                        }
                    }
                    public class One: BuilderProtocol {
                        public let a: BuildableOptionalProperty<Int>
                        public let index_1: BuildableOptionalProperty<Int>
                        public required init() {
                            a = BuildableOptionalProperty(name: "a")
                            index_1 = BuildableOptionalProperty(name: "index_1")
                        }
                        @discardableResult
                        public func set(a: Int?) -> One {
                            self.a.set(value: a)
                            return self
                        }
                        @discardableResult
                        public func set(index_1: Int?) -> One {
                            self.index_1.set(value: index_1)
                            return self
                        }
                        public func build() throws -> Foo {
                            return try .one(a: a.build(), index_1.build())
                        }
                    }
                    private enum BuilderCases {
                        case one(One)
                    }
                }
            }
            """,
            macros: testMacros)
    }

    func testEnumWithInvalidAssociatedValueLabels() {
        assertMacroExpansion(
            """
            @Buildable
            enum Foo {
                case one(_index_0: Int, index_0_: Int, index_123: Int)
                case two(index_0: Int, index_1: Int)
            }
            """,
            expandedSource: """
            enum Foo {
                case one(_index_0: Int, index_0_: Int, index_123: Int)
                case two(index_0: Int, index_1: Int)
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    id: MessageID(domain: AutoBuilderDiagnostic.domain, id: "InvalidEnumAssociatedValueLabel"),
                    message: "@Buildable enum associated value labels must not match \"^index_[0-9]+$\".",
                    line: 3,
                    column: 44,
                    severity: .error),
                DiagnosticSpec(
                    id: MessageID(domain: AutoBuilderDiagnostic.domain, id: "InvalidEnumAssociatedValueLabel"),
                    message: "@Buildable enum associated value labels must not match \"^index_[0-9]+$\".",
                    line: 4,
                    column: 14,
                    severity: .error),
                DiagnosticSpec(
                    id: MessageID(domain: AutoBuilderDiagnostic.domain, id: "InvalidEnumAssociatedValueLabel"),
                    message: "@Buildable enum associated value labels must not match \"^index_[0-9]+$\".",
                    line: 4,
                    column: 28,
                    severity: .error)
            ],
            macros: testMacros)
    }

    func testEnumWithMixedAssociatedValueCollectionTypes() {
        assertMacroExpansion(
            """
            @Buildable
            enum Foo {
                case one(a: Int, b: [String])
            }
            """,
            expandedSource: """
            enum Foo {
                case one(a: Int, b: [String])
            }

            extension Foo: Buildable {
                init(with builder: Builder) throws {
                    self = try builder.build()
                }
                func toBuilder() -> Builder {
                    let builder = Builder()
                    builder.set(value: self)
                    return builder
                }
                public class Builder: BuilderProtocol {
                    private var currentCase: BuilderCases?
                    public required init() {
                        currentCase = nil
                    }
                    public var one: One {
                        get {
                            switch currentCase {
                            case let .some(.one(builder)):
                                return builder
                            default:
                                let builder = One()
                                currentCase = .one(builder)
                                return builder
                            }
                        }
                        set {
                            currentCase = .one(newValue)
                        }
                    }
                    public func set(value: Foo) {
                        switch value {
                        case let .one(a, b):
                            let builder = One()
                            builder.set(a: a)
                            builder.set(b: b)
                            currentCase = .one(builder)
                        }
                    }
                    public func build() throws -> Foo {
                        switch currentCase {
                        case let .some(.one(builder)):
                            return try builder.build()
                        case .none:
                            throw BuilderError.noEnumCaseSet
                        }
                    }
                    public class One: BuilderProtocol {
                        public let a: BuildableProperty<Int>
                        public let b: BuildableArrayProperty<String>
                        public required init() {
                            a = BuildableProperty(name: "a")
                            b = BuildableArrayProperty()
                        }
                        @discardableResult
                        public func set(a: Int) -> One {
                            self.a.set(value: a)
                            return self
                        }
                        @discardableResult
                        public func set(b: [String]) -> One {
                            self.b.set(value: b)
                            return self
                        }
                        @discardableResult
                        public func appendTo(b element: String) -> One {
                            self.b.append(element: element)
                            return self
                        }
                        @discardableResult
                        public func appendTo<C>(b collection: C) -> One where C: Collection, C.Element == String {
                            self.b.append(contentsOf: collection)
                            return self
                        }
                        @discardableResult
                        public func removeAllFromB() -> One {
                            b.removeAll()
                            return self
                        }
                        public func build() throws -> Foo {
                            return try .one(a: a.build(), b: b.build())
                        }
                    }
                    private enum BuilderCases {
                        case one(One)
                    }
                }
            }
            """,
            macros: testMacros)
    }

    func testPublicEnum() {
        assertMacroExpansion(
            """
            @Buildable
            public enum Foo {
                case one(a: Int)
            }
            """,
            expandedSource: """
            public enum Foo {
                case one(a: Int)
            }

            extension Foo: Buildable {
                public init(with builder: Builder) throws {
                    self = try builder.build()
                }
                public func toBuilder() -> Builder {
                    let builder = Builder()
                    builder.set(value: self)
                    return builder
                }
                public class Builder: BuilderProtocol {
                    private var currentCase: BuilderCases?
                    public required init() {
                        currentCase = nil
                    }
                    public var one: One {
                        get {
                            switch currentCase {
                            case let .some(.one(builder)):
                                return builder
                            default:
                                let builder = One()
                                currentCase = .one(builder)
                                return builder
                            }
                        }
                        set {
                            currentCase = .one(newValue)
                        }
                    }
                    public func set(value: Foo) {
                        switch value {
                        case let .one(a):
                            let builder = One()
                            builder.set(a: a)
                            currentCase = .one(builder)
                        }
                    }
                    public func build() throws -> Foo {
                        switch currentCase {
                        case let .some(.one(builder)):
                            return try builder.build()
                        case .none:
                            throw BuilderError.noEnumCaseSet
                        }
                    }
                    public class One: BuilderProtocol {
                        public let a: BuildableProperty<Int>
                        public required init() {
                            a = BuildableProperty(name: "a")
                        }
                        @discardableResult
                        public func set(a: Int) -> One {
                            self.a.set(value: a)
                            return self
                        }
                        public func build() throws -> Foo {
                            return try .one(a: a.build())
                        }
                    }
                    private enum BuilderCases {
                        case one(One)
                    }
                }
            }
            """,
            macros: testMacros)
    }

    func testOpenEnum() {
        assertMacroExpansion(
            """
            @Buildable
            open enum Foo {
                case one(a: Int)
            }
            """,
            expandedSource: """
            open enum Foo {
                case one(a: Int)
            }

            extension Foo: Buildable {
                public init(with builder: Builder) throws {
                    self = try builder.build()
                }
                public func toBuilder() -> Builder {
                    let builder = Builder()
                    builder.set(value: self)
                    return builder
                }
                public class Builder: BuilderProtocol {
                    private var currentCase: BuilderCases?
                    public required init() {
                        currentCase = nil
                    }
                    public var one: One {
                        get {
                            switch currentCase {
                            case let .some(.one(builder)):
                                return builder
                            default:
                                let builder = One()
                                currentCase = .one(builder)
                                return builder
                            }
                        }
                        set {
                            currentCase = .one(newValue)
                        }
                    }
                    public func set(value: Foo) {
                        switch value {
                        case let .one(a):
                            let builder = One()
                            builder.set(a: a)
                            currentCase = .one(builder)
                        }
                    }
                    public func build() throws -> Foo {
                        switch currentCase {
                        case let .some(.one(builder)):
                            return try builder.build()
                        case .none:
                            throw BuilderError.noEnumCaseSet
                        }
                    }
                    public class One: BuilderProtocol {
                        public let a: BuildableProperty<Int>
                        public required init() {
                            a = BuildableProperty(name: "a")
                        }
                        @discardableResult
                        public func set(a: Int) -> One {
                            self.a.set(value: a)
                            return self
                        }
                        public func build() throws -> Foo {
                            return try .one(a: a.build())
                        }
                    }
                    private enum BuilderCases {
                        case one(One)
                    }
                }
            }
            """,
            macros: testMacros)
    }

    func testNestedEnums() {
        assertMacroExpansion(
            """
            enum RootEnum {
                @Buildable
                enum A {
                    case one(b: RootEnum.B)
                }
                enum B {
                    case two(i: Int)
                }
            }
            """,
            expandedSource: """
            enum RootEnum {
                enum A {
                    case one(b: RootEnum.B)
                }
                enum B {
                    case two(i: Int)
                }
            }

            extension A: Buildable {
                init(with builder: Builder) throws {
                    self = try builder.build()
                }
                func toBuilder() -> Builder {
                    let builder = Builder()
                    builder.set(value: self)
                    return builder
                }
                public class Builder: BuilderProtocol {
                    private var currentCase: BuilderCases?
                    public required init() {
                        currentCase = nil
                    }
                    public var one: One {
                        get {
                            switch currentCase {
                            case let .some(.one(builder)):
                                return builder
                            default:
                                let builder = One()
                                currentCase = .one(builder)
                                return builder
                            }
                        }
                        set {
                            currentCase = .one(newValue)
                        }
                    }
                    public func set(value: A) {
                        switch value {
                        case let .one(b):
                            let builder = One()
                            builder.set(b: b)
                            currentCase = .one(builder)
                        }
                    }
                    public func build() throws -> A {
                        switch currentCase {
                        case let .some(.one(builder)):
                            return try builder.build()
                        case .none:
                            throw BuilderError.noEnumCaseSet
                        }
                    }
                    public class One: BuilderProtocol {
                        public let b: BuildableProperty<RootEnum.B>
                        public required init() {
                            b = BuildableProperty(name: "b")
                        }
                        @discardableResult
                        public func set(b: RootEnum.B) -> One {
                            self.b.set(value: b)
                            return self
                        }
                        public func build() throws -> A {
                            return try .one(b: b.build())
                        }
                    }
                    private enum BuilderCases {
                        case one(One)
                    }
                }
            }
            """,
            macros: testMacros)
    }
}
