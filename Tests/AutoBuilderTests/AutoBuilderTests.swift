import AutoBuilder
import XCTest

final class AutoBuilderTests: XCTestCase {
    func testBuilder() throws {
        let foo = try Foo.Builder()
            .set(a: 42)
            .build()
        XCTAssertEqual(foo.a, 42)
    }

    func testChainNestedBuilders() throws {
        let barBuilder = Bar.Builder()
        barBuilder.foo.builder.set(a: 42)
        let bar = try barBuilder.build()
        XCTAssertEqual(bar.foo.a, 42)
    }

    func testSettingValueOverridesNestedBuilder() throws {
        let barBuilder = Bar.Builder()
        barBuilder.foo.builder.set(a: 1)
        barBuilder.set(foo: try Foo.Builder().set(a: 2).build())
        let bar = try barBuilder.build()
        XCTAssertEqual(bar.foo.a, 2)
    }

    func testSettingNestedBuilderOverridesValue() throws {
        let barBuilder = Bar.Builder()
        barBuilder.set(foo: try Foo.Builder().set(a: 2).build())
        barBuilder.foo.builder.set(a: 1)
        let bar = try barBuilder.build()
        XCTAssertEqual(bar.foo.a, 1)
    }

    func testSettingNestedBuilderConvertsValueToBuilder() throws {
        let barBuilder = Bar2.Builder()
        barBuilder.set(foo: try Foo2.Builder().set(a: 1).set(b: 2).build())
        barBuilder.foo.builder.set(a: 3)
        let bar = try barBuilder.build()
        XCTAssertEqual(bar.foo.a, 3)
        XCTAssertEqual(bar.foo.b, 2)
    }

    func testSettingBuilder() throws {
        let fooBuilder = Foo.Builder()
            .set(a: 42)
        let barBuilder = Bar.Builder()
        barBuilder.foo.builder = fooBuilder
        let bar = try barBuilder.build()
        XCTAssertEqual(bar.foo.a, 42)
    }

    func testPropertyWrapper() throws {
        let foo = try FooWithPropertyWrapper.Builder()
            .set(a: 42)
            .set(b: 1)
            .build()
        XCTAssertEqual(foo.a, 12)
        XCTAssertEqual(foo.b, 1)
    }

    func testPropertyNotSet() throws {
        let builder = Foo.Builder()
        XCTAssertThrowsError(try builder.build()) { error in
            switch error {
            case let BuilderError.missingValue(propertyName):
                XCTAssertEqual(propertyName, "a")
            default:
                XCTFail()
            }
        }
    }
}

@Buildable
private struct Foo {
    let a: Int
}

@Buildable
private struct Bar {
    let foo: Foo
}

@Buildable
private struct Foo2 {
    let a: Int
    let b: Int
}

@Buildable
private struct Bar2 {
    let foo: Foo2
}

@propertyWrapper
private struct TwelveOrLess {
    private var number = 0
    var wrappedValue: Int {
        get { return number }
        set { number = min(newValue, 12) }
    }
}

@Buildable
private struct FooWithPropertyWrapper {
    @TwelveOrLess var a: Int
    @TwelveOrLess var b: Int
}
