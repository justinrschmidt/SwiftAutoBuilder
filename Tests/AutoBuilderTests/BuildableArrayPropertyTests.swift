import AutoBuilder
import XCTest

class BuildableArrayPropertyTests: XCTestCase {
    func testSetArray() throws {
        let foo = try Foo.Builder()
            .set(a: [1, 2, 3])
            .build()
        XCTAssertEqual(foo.a, [1, 2, 3])
    }

    func testAppendElement() throws {
        let foo = try Foo.Builder()
            .appendTo(a: 1)
            .appendTo(a: 2)
            .appendTo(a: 3)
            .build()
        XCTAssertEqual(foo.a, [1, 2, 3])
    }

    func testAppendCollection() throws {
        let foo = try Foo.Builder()
            .appendTo(a: [1, 2])
            .appendTo(a: [3, 4])
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
        var a: [Int]

        init(a: [Int]) {
            self.a = a
        }
    }
}
