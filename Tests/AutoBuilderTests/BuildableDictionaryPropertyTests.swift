import AutoBuilder
import XCTest

class BuildableDictionaryPropertyTests: XCTestCase {
    func testSetDictionary() throws {
        let foo = try Foo.Builder()
            .set(a: ["1":1, "2":2])
            .build()
        XCTAssertEqual(foo.a, ["1":1, "2":2])
    }

    func testInsertElement() throws {
        let foo = try Foo.Builder()
            .insertIntoA(key: "1", value: 1)
            .insertIntoA(key: "2", value: 2)
            .build()
        XCTAssertEqual(foo.a, ["1":1, "2":2])
    }

    func testMergeDictionary() throws {
        let foo = try Foo.Builder()
            .set(a: ["1":1])
            .mergeIntoA(other: ["2":2], uniquingKeysWith: { $1 })
            .build()
        XCTAssertEqual(foo.a, ["1":1, "2":2])
    }

    func testRemoveAll() throws {
        let foo = Foo(a: ["1":1, "2":2])
        let foo2 = try foo.toBuilder()
            .removeAllFromA()
            .build()
        XCTAssertEqual(foo2.a, [:])
    }

    @AutoBuilder
    struct Foo {
        var a: [String:Int]

        init(a: [String:Int]) {
            self.a = a
        }
    }
}
