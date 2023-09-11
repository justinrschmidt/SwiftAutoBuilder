import AutoBuilder
import XCTest

class BuildableSetPropertyTests: XCTestCase {
    func testSetSet_struct() throws {
        let foo = try Foo.Builder()
            .set(a: [1, 2, 3])
            .build()
        XCTAssertEqual(foo.a, [1, 2, 3])
    }

    func testSetSet_enum() throws {
        let bar = try Bar.Builder().one
            .set(a: [1, 2, 3])
            .build()
        XCTAssertEqual(bar.a, [1, 2, 3])
    }

    func testInsertElement_struct() throws {
        let foo = try Foo.Builder()
            .insertInto(a: 1)
            .insertInto(a: 2)
            .insertInto(a: 3)
            .build()
        XCTAssertEqual(foo.a, [1, 2, 3])
    }

    func testInsertElement_enum() throws {
        let bar = try Bar.Builder().one
            .insertInto(a: 1)
            .insertInto(a: 2)
            .insertInto(a: 3)
            .build()
        XCTAssertEqual(bar.a, [1, 2, 3])
    }

    func testFormUnion_struct() throws {
        let foo = try Foo.Builder()
            .formUnionWithA(other: [1, 2])
            .formUnionWithA(other: [3, 4])
            .build()
        XCTAssertEqual(foo.a, [1, 2, 3, 4])
    }

    func testFormUnion_enum() throws {
        let bar = try Bar.Builder().one
            .formUnionWithA(other: [1, 2])
            .formUnionWithA(other: [3, 4])
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
        var a: Set<Int>

        init(a: Set<Int>) {
            self.a = a
        }
    }

    @AutoBuilder
    enum Bar {
        var a: Set<Int> {
            switch self {
            case let .one(a):
                return a
            }
        }

        case one(a: Set<Int>)
    }
}
