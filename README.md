# Swift Auto Builder
Swift Auto Builder is a macro that generates builder classes that implement the Builder design pattern for your types.

The macro currently supports structs and enums. Support for classes is planned.

## How to Add Swift Auto Builder as a Dependency

### Xcode Project

Go to File -> "Add Package Dependencies...". In the search box on the top right where it says "Search or Enter Package URL"
and enter `https://github.com/justinrschmidt/SwiftAutoBuilder`. Select the "swiftautobuilder" package from the list and click "Add Package".
Import Auto Builder by adding `import AutoBuilder`.

### Swift Package Manager

In your package, add `.package(url: "https://github.com/justinrschmidt/SwiftAutoBuilder", from: "0.1.1-beta-2")` to your
package's `dependencies` array. Then add `.product(name: "AutoBuilder", package: "SwiftAutoBuilder")` to the `dependencies`
array of any target that uses Auto Builder. Import Auto Builder by adding `import AutoBuilder`.

## How to Use Auto Builder

As an example, the following `struct`:

```swift
@Buildable
struct Foo {
  var a: Int
  var b: Int
}
```

Can be created with a builder:

```swift
let foo = try Foo.Builder()
  .set(a: 1)
  .set(b: 2)
  .build()

// prints: "1, 2"
print("\(foo.a), \(foo.b)")
```

If your type's properties are also using `@Buildable`, then you can chain those "nested" builders together:

```swift
@Buildable
struct Foo {
  var a: Int
  var b: Int
}

@Buildable
struct Bar {
  var foo: Foo
}

let barBuilder = Bar.Builder()
barBuilder.foo.builder
  .set(a: 1)
  .set(b: 2)
let bar = try barBuilder.build()

// prints: "1, 2"
print("\(bar.foo.a), \(bar.foo.b)")
```

`@Buildable` also generates helper functions in the builder class that allow you to add elements to `Array`s,
`Dictionary`s, and `Set`s:

```swift
@Buildable
struct Foo {
  var a: [Int]
  var b: [String:Int]
  var c: Set<Int>
}

let foo = try Foo.Builder()
  .appendTo(a: 1) // Append element to Array
  .insertInto(b: 2, forKey: "2") // Add key-value pair to Dictionary
  .insertInto(c: 3) // Insert element into Set
  .build()

// prints: "1, 2, 3"
print("\(foo.a.first!), \(foo.b["2"]!), \(foo.c.first!)")
```
