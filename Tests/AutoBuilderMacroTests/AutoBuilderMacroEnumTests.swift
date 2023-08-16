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
                public class Builder: BuilderProtocol {
                    private var currentCase: BuilderCases?
                    public required init() {
                        currentCase = nil
                    }
                    public var one: One {
                        get {
                            switch self {
                            case let .some(.one(builder)):
                                return builder
                            default:
                                let builder = One()
                                currentCase = .one(builder)
                                return builder
                            }
                        }
                        set {
                            self = .one(newValue)
                        }
                    }
                    public var two: Two {
                        get {
                            switch self {
                            case let .some(.two(builder)):
                                return builder
                            default:
                                let builder = Two()
                                currentCase = .two(builder)
                                return builder
                            }
                        }
                        set {
                            self = .two(newValue)
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
}
