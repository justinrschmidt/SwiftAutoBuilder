# Swift Auto Builder
Swift Auto Builder is a macro that generates builder classes that implement the Builder design pattern for your types.

For example, the following `struct`:

```swift
@AutoBuilder
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

If a type's properties have `@AutoBuilder` attached to them as well, then you can chain those "nested" builders together:

```swift
@AutoBuilder
  struct Foo {
  var a: Int
  var b: Int
}

@AutoBuilder
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

`@AutoBuilder` also generates helper functions in the builder class that allow you to add elements to `Array`s, `Dictionary`s, and `Set`s:

```swift
@AutoBuilder
struct Foo {
  var a: [Int]
  var b: [String:Int]
  var c: Set<Int>
}

let foo = try Foo.Builder()
  .appendTo(a: 1)
  .insertIntoB(key: "2", value: 2)
  .insertInto(c: 3)
  .build()

// prints: "1, 2, 3"
print("\(foo.a.first!), \(foo.b["2"]!), \(foo.c.first!)")
```
