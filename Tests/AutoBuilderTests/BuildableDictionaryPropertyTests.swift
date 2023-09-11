import AutoBuilder
import XCTest

class BuildableDictionaryPropertyTests: XCTestCase {
    func testSetDictionary_struct() throws {
        let foo = try Foo.Builder()
            .set(a: ["1":1, "2":2])
            .build()
        XCTAssertEqual(foo.a, ["1":1, "2":2])
    }

    func testSetDictionary_enumWithLabel() throws {
        let bar = try Bar.Builder().one
            .set(a: ["1":1, "2":2])
            .build()
        XCTAssertEqual(bar.a, ["1":1, "2":2])
    }

    func testSetDictionary_enumWithoutLabel() throws {
        let bar = try Bar.Builder().two
            .setIndex0(["1":1, "2":2])
            .build()
        XCTAssertEqual(bar.b, ["1":1, "2":2])
    }

    func testInsertElement_struct() throws {
        let foo = try Foo.Builder()
            .insertInto(a: 1, forKey: "1")
            .insertInto(a: 2, forKey: "2")
            .build()
        XCTAssertEqual(foo.a, ["1":1, "2":2])
    }

    func testInsertElement_enumWithLabel() throws {
        let bar = try Bar.Builder().one
            .insertInto(a: 1, forKey: "1")
            .insertInto(a: 2, forKey: "2")
            .build()
        XCTAssertEqual(bar.a, ["1":1, "2":2])
    }

    func testInsertElement_enumWithoutLabel() throws {
        let bar = try Bar.Builder().two
            .insertIntoIndex0(1, forKey: "1")
            .insertIntoIndex0(2, forKey: "2")
            .build()
        XCTAssertEqual(bar.b, ["1":1, "2":2])
    }

    func testMergeDictionary_struct() throws {
        let foo = try Foo.Builder()
            .set(a: ["1":1])
            .mergeIntoA(other: ["2":2], uniquingKeysWith: { $1 })
            .build()
        XCTAssertEqual(foo.a, ["1":1, "2":2])
    }

    func testMergeDictionary_enumWithLabel() throws {
        let bar = try Bar.Builder().one
            .set(a: ["1":1])
            .mergeIntoA(other: ["2":2], uniquingKeysWith: { $1 })
            .build()
        XCTAssertEqual(bar.a, ["1":1, "2":2])
    }

    func testMergeDictionary_enumWithoutLabel() throws {
        let bar = try Bar.Builder().two
            .setIndex0(["1":1])
            .mergeIntoIndex0(other: ["2":2], uniquingKeysWith: { $1 })
            .build()
        XCTAssertEqual(bar.b, ["1":1, "2":2])
    }

    func testRemoveAll_struct() throws {
        let foo = Foo(a: ["1":1, "2":2])
        let foo2 = try foo.toBuilder()
            .removeAllFromA()
            .build()
        XCTAssertEqual(foo2.a, [:])
    }

    func testRemoveAll_enumWithLabel() throws {
        let bar = Bar.one(a: ["1":1, "2":2])
        let bar2 = try bar.toBuilder().one
            .removeAllFromA()
            .build()
        XCTAssertEqual(bar2.a, [:])
    }

    func testRemoveAll_enumWithoutLabel() throws {
        let bar = Bar.two(["1":1, "2":2])
        let bar2 = try bar.toBuilder().two
            .removeAllFromIndex0()
            .build()
        XCTAssertEqual(bar2.b, [:])
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
            return switch self {
            case let .one(a): a
            default: [:]
            }
        }

        var b: [String:Int] {
            return switch self {
            case let .two(b): b
            default: [:]
            }
        }

        case one(a: [String:Int])
        case two([String:Int])
    }
}
