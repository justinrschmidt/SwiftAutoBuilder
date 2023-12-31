import AutoBuilder
import XCTest

class BuildableArrayPropertyTests: XCTestCase {
    func testSetArray_struct() throws {
        let foo = try Foo.Builder()
            .set(a: [1, 2, 3])
            .build()
        XCTAssertEqual(foo.a, [1, 2, 3])
    }

    func testSetArray_enumWithLabel() throws {
        let bar = try Bar.Builder().one
            .set(a: [1, 2, 3])
            .build()
        XCTAssertEqual(bar.a, [1, 2, 3])
    }

    func testSetArray_enumWithoutLabel() throws {
        let bar = try Bar.Builder().two
            .set(index_0: [1, 2, 3])
            .build()
        XCTAssertEqual(bar.b, [1, 2, 3])
    }

    func testAppendElement_struct() throws {
        let foo = try Foo.Builder()
            .appendTo(a: 1)
            .appendTo(a: 2)
            .appendTo(a: 3)
            .build()
        XCTAssertEqual(foo.a, [1, 2, 3])
    }

    func testAppendElement_enumWithLabel() throws {
        let bar = try Bar.Builder().one
            .appendTo(a: 1)
            .appendTo(a: 2)
            .appendTo(a: 3)
            .build()
        XCTAssertEqual(bar.a, [1, 2, 3])
    }

    func testAppendElement_enumWithoutLabel() throws {
        let bar = try Bar.Builder().two
            .appendTo(index_0: [1, 2, 3])
            .build()
        XCTAssertEqual(bar.b, [1, 2, 3])
    }

    func testAppendCollection_struct() throws {
        let foo = try Foo.Builder()
            .appendTo(a: [1, 2])
            .appendTo(a: [3, 4])
            .build()
        XCTAssertEqual(foo.a, [1, 2, 3, 4])
    }

    func testAppendCollection_enumWithLabel() throws {
        let bar = try Bar.Builder().one
            .appendTo(a: [1, 2])
            .appendTo(a: [3, 4])
            .build()
        XCTAssertEqual(bar.a, [1, 2, 3, 4])
    }

    func testAppendCollection_enumWithoutLabel() throws {
        let bar = try Bar.Builder().two
            .appendTo(index_0: [1, 2])
            .appendTo(index_0: [3, 4])
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
        var a: [Int]
    }

    @Buildable
    enum Bar {
        var a: [Int] {
            return switch self {
            case let .one(a): a
            default: []
            }
        }

        var b: [Int] {
            return switch self {
            case let .two(b): b
            default: []
            }
        }

        case one(a: [Int])
        case two([Int])
    }
}
