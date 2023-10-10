/// A macro that generates a builder class that implements the builder design pattern for the attached type.
/// The attached type is referred to as the builder's "client".
///
/// # Attached Conformance Macro
/// The `@attached(conformance)` macro adds conformance to the `Buildable` protocol.
/// The methods declared in `Buildable` are implemented by the `@attached(member)` macro.
///
/// # Attached Member Macro
/// The `@attached(member)` macro adds methods to the attached type to provide conformance
/// to `Buildable`. It also creates a nested class named `Builder` which implements the
/// `BuilderProtocol` protocol and is the builder for the attached type.
///
/// # Builder Class
/// The nested `Builder` class has a `BuildableProperty` (or one of its variants) for each of
/// the client's stored instance properties, except for constants that are initialized in their declaration.
/// The builder also provides convience methods when working with types that also make use of
/// `@Buildable` and also when working with `Array`s, `Dictionary`s, and `Set`s.
/// The `Builder` class provides a `build()` method that creates an instance of the client from
/// the values set in the builder. If any property does not have a value set, the `build()` method
/// throws an error containing the name of the property that was not set.
///
/// ## Simple Values
/// The `Builder` class provides methods that allow you to set values for each of the client's
/// properties. The set method is called `set([client_property_name]:)`. For example,
/// if the client declares the following property:
///
///     var a: Int
///
/// Then the `Builder` class will have the following set method:
///
///     set(a: Int) -> Builder
///
/// The set methods return the builder that they were called on, which allows the user to chain
/// calls to set methods. For example, the following struct:
///
///     @Buildable
///     struct Foo {
///         var a: Int
///         var b: Int
///     }
///
/// Could be built as:
///
///     let foo = try Foo.Builder()
///         .set(a: 1)
///         .set(b: 2)
///         .build()
///     // prints "1, 2"
///     print("\(foo.a), \(foo.b)")
///
/// ## Nested Builder Values
/// When the value of a client's property also has the `@Buildable` attached to it, it allows the
/// user to access the property on the builder as a nested sub-builder. For example, the following
/// structs:
///
///     @Buildable
///     struct Foo {
///         var a: Int
///         var b: Int
///     }
///     @Buildable
///     struct Bar {
///         var foo: Foo
///     }
///
/// Could be built as:
///
///     let barBuilder = Bar.Builder()
///     barBuilder.foo.builder
///         .set(a: 1)
///         .set(b: 2)
///     let bar = try barBuilder.build()
///     // prints "1, 2"
///     print("\(bar.foo.a), \(bar.foo.b)")
///
/// ## Array Values
/// When the value of a client's property is an `Array`, the `Builder` class adds the following
/// methods:
/// - `appendTo([client_property_name] element:) -> Builder`: Appends an
/// element to the array in the builder.
/// - `appendTo<C>([client_property_name] collection:) -> Builder`: Appends
/// the contents of a collection to the end of the array in the builder.
/// - `removeAllFrom[capitalized_client_property_name]() -> Builder`:
/// Removes all elements from the array in the builder.
///
/// * SeeAlso: `BuildableArrayProperty`
///
/// ## Dictionary Values
/// When the value of a client's property is a `Dictionary`, the `Builder` class adds the
/// following methods:
/// - `insertInto([client_property_name]:forKey:) -> Builder`:
/// Inserts a key-value pair into the dictionary in the builder.
/// - `mergeInto[capitalized_client_property_name](other:uniquingKeysWith:) -> Builder`:
/// Merges the contents of another dictionary into the dictionary in the builder. Also takes a closure
/// for handling duplicate values resulting from the merge.
/// - `removeAllFrom[capitalized_client_property_name]() -> Builder`:
/// Removes all key-value pairs from the dictionary in the builder.
///
/// * SeeAlso: `BuildableDictionaryProperty`
///
/// ## Set Values
/// When the value of a client's property is a `Set`, the `Builder` class add the following
/// methods:
/// - `insertInto([client_property_name]:) -> Builder`: Inserts an element
/// into the set in the builder.
/// - `formUnionWith[capitalized_client_property_name](other:) -> Builder`:
/// Inserts the elements of another set into the set in the builder.
/// - `removeAllFrom[capitalized_client_property_name]() -> Builder`:
/// Removes all elements from the set in the builder.
///
/// * SeeAlso: `BuildableSetProperty`
///
/// ## Creating Builders From Existing Values
/// Any type with `@Buildable` attached to it is also given a `toBuilder()`
/// method. This method creates an instance of that type's `Builder` class with
/// all of the builder's properties initialized to the values of the properties of the
/// value `toBuilder()` was called on.
///
/// For example:
///
///     @Buildable
///     struct Foo {
///         var a: Int
///         var b: Int
///     }
///
///     let foo1 = try Foo.Builder()
///         .set(a: 1)
///         .set(b: 2)
///         .build()
///     let foo2 = try foo1.toBuilder()
///         .set(b: 3)
///         .build()
///     // prints "1, 3"
///     print("\(foo2.a), \(foo2.b)")
///
import AutoBuilderMacros

@attached(extension, conformances: Buildable, names: named(Builder), named(init(with:)), named(toBuilder))
public macro Buildable() = #externalMacro(module: "AutoBuilderMacros", type: "AutoBuilderMacro")
