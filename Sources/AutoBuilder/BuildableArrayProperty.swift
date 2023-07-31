/// A variant of `BuildableProperty` that is used when the client's property is an `Array`.
///
/// This class's `Element` type is the same type as the client property's `Array.Element` type.
///
/// - SeeAlso:
///   - `BuildableProperty`
///   - `BuildableDictionaryProperty`
///   - `BuildableSetProperty`
public class BuildableArrayProperty<Element> {

    /// The array that the client's property will be initialized to when the builder builds.
    private var array: [Element]

    /// Initialize the `BuildableArrayProperty`.
    public init() {
        array = []
    }

    /// Sets the array that the client's property will be initialized to.
    /// - Parameters:
    ///   - value: The array that the client's property will be initialized to.
    public func set(value: [Element]) {
        array = value
    }

    /// Appends an element to the array that the client's property will be initialized to.
    /// - Parameters:
    ///   - element: The element to append to the array.
    public func append(element: Element) {
        array.append(element)
    }

    /// Appends the contents of a collection to the array that the client's property will be initialized to.
    /// - Parameters:
    ///   - collection: The collection whose elements should be appended to the array.
    public func append<C>(contentsOf collection: C) where C: Collection, C.Element == Element {
        array.insert(contentsOf: collection, at: array.endIndex)
    }

    /// Removes all elements from the array that the client's property will be initialized to.
    public func removeAll() {
        array.removeAll()
    }

    /// Returns the array that the client's property should be initialized to.
    /// - Returns: The array that the client's property should be initialized to.
    public func build() -> [Element] {
        return array
    }
}
