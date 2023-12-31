import AutoBuilder
import XCTest

class BuildableOptionalPropertyTests: XCTestCase {
    func testSetOptional_struct() throws {
        let foo = try Foo.Builder()
            .set(a: 1)
            .set(b: nil)
            .build()
        XCTAssertEqual(foo.a, 1)
        XCTAssertNil(foo.b)
    }

    func testSetOptional_enumWithLabel() throws {
        let bar = try Bar.Builder().one
            .set(a: 1)
            .set(b: nil)
            .build()
        switch bar {
        case let .one(a, b):
            XCTAssertEqual(a, 1)
            XCTAssertNil(b)
        default:
            XCTFail()
        }
    }

    func testSetOptional_enumWithoutLabel() throws {
        let bar = try Bar.Builder().two
            .set(index_0: 1)
            .set(index_1: nil)
            .build()
        switch bar {
        case let .two(i0, i1):
            XCTAssertEqual(i0, 1)
            XCTAssertNil(i1)
        default:
            XCTFail()
        }
    }

    func testNestedOptional() throws {
        let builder = Baz.Builder()
        builder.a.builder.wrappedValue.set(value: nil)
        let baz = try builder.build()
        XCTAssertEqual(baz.a, .some(.none))
    }

    func testWrappedBuildable() throws {
        let aBuilder = A.Builder()
            .set(b: B(i: 1))
        aBuilder.b.builder.set(i: 2)
        let a = try aBuilder.build()
        XCTAssertEqual(a.b?.i, 2)
    }

    @Buildable
    struct Foo {
        var a: Int?
        var b: String?
    }

    @Buildable
    enum Bar {
        case one(a: Int?, b: String?)
        case two(Int?, String?)
    }

    @Buildable
    struct Baz {
        var a: Int??
    }

    @Buildable
    struct A {
        var b: BuildableOptionalPropertyTests.B?
    }

    @Buildable
    struct B {
        var i: Int
    }
}
