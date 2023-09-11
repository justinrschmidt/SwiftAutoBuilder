import AutoBuilder
import XCTest

class BuildableDictionaryPropertyTests: XCTestCase {
    func testSetDictionary_struct() throws {
        let foo = try Foo.Builder()
            .set(a: ["1":1, "2":2])
            .build()
        XCTAssertEqual(foo.a, ["1":1, "2":2])
    }

    func testSetDictionary_enum() throws {
        let bar = try Bar.Builder().one
            .set(a: ["1":1, "2":2])
            .build()
        XCTAssertEqual(bar.a, ["1":1, "2":2])
    }

    func testInsertElement_struct() throws {
        let foo = try Foo.Builder()
            .insertInto(a: 1, forKey: "1")
            .insertInto(a: 2, forKey: "2")
            .build()
        XCTAssertEqual(foo.a, ["1":1, "2":2])
    }

    func testInsertElement_enum() throws {
        let bar = try Bar.Builder().one
            .insertInto(a: 1, forKey: "1")
            .insertInto(a: 2, forKey: "2")
            .build()
        XCTAssertEqual(bar.a, ["1":1, "2":2])
    }

    func testMergeDictionary_struct() throws {
        let foo = try Foo.Builder()
            .set(a: ["1":1])
            .mergeIntoA(other: ["2":2], uniquingKeysWith: { $1 })
            .build()
        XCTAssertEqual(foo.a, ["1":1, "2":2])
    }

    func testMergeDictionary_enum() throws {
        let bar = try Bar.Builder().one
            .set(a: ["1":1])
            .mergeIntoA(other: ["2":2], uniquingKeysWith: { $1 })
            .build()
        XCTAssertEqual(bar.a, ["1":1, "2":2])
    }

    func testRemoveAll_struct() throws {
        let foo = Foo(a: ["1":1, "2":2])
        let foo2 = try foo.toBuilder()
            .removeAllFromA()
            .build()
        XCTAssertEqual(foo2.a, [:])
    }

    func testRemoveAll_enum() throws {
        let bar = Bar.one(a: ["1":1, "2":2])
        let bar2 = try bar.toBuilder().one
            .removeAllFromA()
            .build()
        XCTAssertEqual(bar2.a, [:])
    }

    @AutoBuilder
    struct Foo {
        var a: [String:Int]

        init(a: [String:Int]) {
            self.a = a
        }
    }

    @AutoBuilder
    enum Bar {
        var a: [String:Int] {
            switch self {
            case let .one(a):
                return a
            }
        }

        case one(a: [String:Int])
    }
}
