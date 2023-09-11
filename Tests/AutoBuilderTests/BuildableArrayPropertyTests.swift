import AutoBuilder
import XCTest

class BuildableArrayPropertyTests: XCTestCase {
    func testSetArray_struct() throws {
        let foo = try Foo.Builder()
            .set(a: [1, 2, 3])
            .build()
        XCTAssertEqual(foo.a, [1, 2, 3])
    }

    func testSetArray_enum() throws {
        let bar = try Bar.Builder().one
            .set(a: [1, 2, 3])
            .build()
        XCTAssertEqual(bar.a, [1, 2, 3])
    }

    func testAppendElement_struct() throws {
        let foo = try Foo.Builder()
            .appendTo(a: 1)
            .appendTo(a: 2)
            .appendTo(a: 3)
            .build()
        XCTAssertEqual(foo.a, [1, 2, 3])
    }

    func testAppendElement_enum() throws {
        let bar = try Bar.Builder().one
            .appendTo(a: 1)
            .appendTo(a: 2)
            .appendTo(a: 3)
            .build()
        XCTAssertEqual(bar.a, [1, 2, 3])
    }

    func testAppendCollection_struct() throws {
        let foo = try Foo.Builder()
            .appendTo(a: [1, 2])
            .appendTo(a: [3, 4])
            .build()
        XCTAssertEqual(foo.a, [1, 2, 3, 4])
    }

    func testAppendCollection_enum() throws {
        let bar = try Bar.Builder().one
            .appendTo(a: [1, 2])
            .appendTo(a: [3, 4])
            .build()
        XCTAssertEqual(bar.a, [1, 2, 3, 4])
    }

    func testRemoveAll_struct() throws {
        let foo = Foo(a: [1, 2, 3])
        let foo2 = try foo.toBuilder()
            .removeAllFromA()
            .build()
        XCTAssertEqual(foo2.a, [])
    }

    func testRemoveAll_enum() throws {
        let bar = Bar.one(a: [1, 2, 3])
        let bar2 = try bar.toBuilder().one
            .removeAllFromA()
            .build()
        XCTAssertEqual(bar2.a, [])
    }

    @AutoBuilder
    struct Foo {
        var a: [Int]

        init(a: [Int]) {
            self.a = a
        }
    }

    @AutoBuilder
    enum Bar {
        var a: [Int] {
            switch self {
            case let .one(a):
                return a
            }
        }

        case one(a: [Int])
    }
}
