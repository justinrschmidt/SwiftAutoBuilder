import AutoBuilder
import XCTest

class BuildableSetPropertyTests: XCTestCase {
    func testSetSet_struct() throws {
        let foo = try Foo.Builder()
            .set(a: [1, 2, 3])
            .build()
        XCTAssertEqual(foo.a, [1, 2, 3])
    }

    func testSetSet_enumWithLabel() throws {
        let bar = try Bar.Builder().one
            .set(a: [1, 2, 3])
            .build()
        XCTAssertEqual(bar.a, [1, 2, 3])
    }

    func testSetSet_enumWithoutLabel() throws {
        let bar = try Bar.Builder().two
            .set(index_0: [1, 2, 3])
            .build()
        XCTAssertEqual(bar.b, [1, 2, 3])
    }

    func testInsertElement_struct() throws {
        let foo = try Foo.Builder()
            .insertInto(a: 1)
            .insertInto(a: 2)
            .insertInto(a: 3)
            .build()
        XCTAssertEqual(foo.a, [1, 2, 3])
    }

    func testInsertElement_enumWithLabel() throws {
        let bar = try Bar.Builder().one
            .insertInto(a: 1)
            .insertInto(a: 2)
            .insertInto(a: 3)
            .build()
        XCTAssertEqual(bar.a, [1, 2, 3])
    }

    func testInsertElement_enumWithoutLabel() throws {
        let bar = try Bar.Builder().two
            .insertInto(index_0: 1)
            .insertInto(index_0: 2)
            .insertInto(index_0: 3)
            .build()
        XCTAssertEqual(bar.b, [1, 2, 3])
    }

    func testFormUnion_struct() throws {
        let foo = try Foo.Builder()
            .formUnionWithA(other: [1, 2])
            .formUnionWithA(other: [3, 4])
            .build()
        XCTAssertEqual(foo.a, [1, 2, 3, 4])
    }

    func testFormUnion_enumWithLabel() throws {
        let bar = try Bar.Builder().one
            .formUnionWithA(other: [1, 2])
            .formUnionWithA(other: [3, 4])
            .build()
        XCTAssertEqual(bar.a, [1, 2, 3, 4])
    }

    func testFormUnion_enumWithoutLabel() throws {
        let bar = try Bar.Builder().two
            .formUnionWithIndex_0(other: [1, 2])
            .formUnionWithIndex_0(other: [3, 4])
            .build()
        XCTAssertEqual(bar.b, [1, 2, 3, 4])
    }

    func testRemoveAll_struct() throws {
        let foo = Foo(a: [1, 2, 3])
        let foo2 = try foo.toBuilder()
            .removeAllFromA()
            .build()
        XCTAssertEqual(foo2.a, [])
    }

    func testRemoveAll_enumWithLabel() throws {
        let bar = Bar.one(a: [1, 2, 3])
        let bar2 = try bar.toBuilder().one
            .removeAllFromA()
            .build()
        XCTAssertEqual(bar2.a, [])
    }

    func testRemoveAll_enumWithoutLabel() throws {
        let bar = Bar.two([1, 2, 3])
        let bar2 = try bar.toBuilder().two
            .removeAllFromIndex_0()
            .build()
        XCTAssertEqual(bar2.b, [])
    }

    @Buildable
    struct Foo {
        var a: Set<Int>
    }

    @Buildable
    enum Bar {
        var a: Set<Int> {
            return switch self {
            case let .one(a): a
            default: []
            }
        }

        var b: Set<Int> {
            return switch self {
            case let .two(b): b
            default: []
            }
        }

        case one(a: Set<Int>)
        case two(Set<Int>)
    }
}
