import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import SwiftDiagnostics
import XCTest
import AutoBuilderMacros

final class AutoBuilderMacroEnumTests: XCTestCase {
    let testMacros: [String:Macro.Type] = [
        "AutoBuilder":AutoBuilderMacro.self
    ]

        func testEnumWithNoCases() {
            assertMacroExpansion(
                """
                @AutoBuilder
                enum Foo {
                }
                """,
                expandedSource:
                """
                enum Foo {
                }
                """, diagnostics: [
                    DiagnosticSpec(
                        id: MessageID(domain: AutoBuilderDiagnostic.domain, id: "EnumWithNoCases"),
                        message: "Foo (aka: Never) does not have any cases and cannot be instantiated.",
                        line: 1,
                        column: 1,
                        severity: .error)
                ], macros: testMacros)
        }
    
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
                    self = try builder.build()
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
            extension Foo: Buildable {
            }
            """, macros: testMacros)
    }
    
    func testEnumWithNoAssociatedValues() {
        assertMacroExpansion(
            """
            @AutoBuilder
            enum Foo {
                case one
                case two
            }
            """,
            expandedSource:
            """
            enum Foo {
                case one
                case two
                init(with builder: Builder) throws {
                    self = try builder.build()
                }
                func toBuilder() -> Builder {
                    let builder = Builder()
                    switch self {
                    case .one:
                        _ = builder.one
                    case .two:
                        _ = builder.two
                    }
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
            extension Foo: Buildable {
            }
            """, diagnostics: [
                DiagnosticSpec(
                    id: MessageID(domain: AutoBuilderDiagnostic.domain, id: "NoAssociatedValues"),
                    message: "Foo does not have any cases with associated values.",
                    line: 1,
                    column: 1,
                    severity: .warning)
            ], macros: testMacros)
    }

    func testEnumWithCasesWithAndWithoutAssociatedValues() {
        assertMacroExpansion(
        """
        @AutoBuilder
        enum Foo {
            case one(a: Int)
            case two
        }
        """,
        expandedSource:
        """
        enum Foo {
            case one(a: Int)
            case two
            init(with builder: Builder) throws {
                self = try builder.build()
            }
            func toBuilder() -> Builder {
                let builder = Builder()
                switch self {
                case let .one(a):
                    let oneBuilder = builder.one
                    oneBuilder.set(a: a)
                case .two:
                    _ = builder.two
                }
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
        extension Foo: Buildable {
        }
        """, macros: testMacros)
    }

    func testEnumCaseWithNoLabels() {
        assertMacroExpansion(
            """
            @AutoBuilder
            enum Foo {
                case one(Int, Double, String)
            }
            """,
            expandedSource:
            """
            enum Foo {
                case one(Int, Double, String)
                init(with builder: Builder) throws {
                    self = try builder.build()
                }
                func toBuilder() -> Builder {
                    let builder = Builder()
                    switch self {
                    case let .one(i0, i1, i2):
                        let oneBuilder = builder.one
                        oneBuilder.set(i0: i0)
                        oneBuilder.set(i1: i1)
                        oneBuilder.set(i2: i2)
                    }
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
                        case let .one(i0, i1, i2):
                            let builder = One()
                            builder.set(i0: i0)
                            builder.set(i1: i1)
                            builder.set(i2: i2)
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
                        public let i0: BuildableProperty<Int>
                        public let i1: BuildableProperty<Double>
                        public let i2: BuildableProperty<String>
                        public required init() {
                            i0 = BuildableProperty(name: "i0")
                            i1 = BuildableProperty(name: "i1")
                            i2 = BuildableProperty(name: "i2")
                        }
                        @discardableResult
                        public func set(i0: Int) -> One {
                            self.i0.set(value: i0)
                            return self
                        }
                        @discardableResult
                        public func set(i1: Double) -> One {
                            self.i1.set(value: i1)
                            return self
                        }
                        @discardableResult
                        public func set(i2: String) -> One {
                            self.i2.set(value: i2)
                            return self
                        }
                        public func build() throws -> Foo {
                            return try .one(i0: i0.build(), i1: i1.build(), i2: i2.build())
                        }
                    }
                    private enum BuilderCases {
                        case one(One)
                    }
                }
            }
            extension Foo: Buildable {
            }
            """, macros: testMacros)
    }
}