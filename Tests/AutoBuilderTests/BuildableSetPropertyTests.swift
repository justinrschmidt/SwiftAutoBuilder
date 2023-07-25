import AutoBuilder
import XCTest

class BuildableSetPropertyTests: XCTestCase {
    func testSetSet() throws {
        let foo = try Foo.Builder()
            .set(a: [1, 2, 3])
            .build()
        XCTAssertEqual(foo.a, [1, 2, 3])
    }

    func testInsertElement() throws {
        let foo = try Foo.Builder()
            .insertInto(a: 1)
            .insertInto(a: 2)
            .insertInto(a: 3)
            .build()
        XCTAssertEqual(foo.a, [1, 2, 3])
    }

    func testFormUnion() throws {
        let foo = try Foo.Builder()
            .formUnionWithA(other: [1, 2])
            .formUnionWithA(other: [3, 4])
            .build()
        XCTAssertEqual(foo.a, [1, 2, 3, 4])
    }

    func testRemoveAll() throws {
        let foo = Foo(a: [1, 2, 3])
        let foo2 = try foo.toBuilder()
            .removeAllFromA()
            .build()
        XCTAssertEqual(foo2.a, [])
    }

    @AutoBuilder
    struct Foo {
        var a: Set<Int>

        init(a: Set<Int>) {
            self.a = a
        }
    }
}
