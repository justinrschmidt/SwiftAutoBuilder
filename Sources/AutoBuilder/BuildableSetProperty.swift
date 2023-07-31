/// A variant of `BuildableProperty` that is used when the client's property is a `Set`.
///
/// This class's `Element` type is the same type as the client property's `Set.Element` type.
///
/// - SeeAlso:
///   - `BuildableProperty`
///   - `BuildableArrayProperty`
///   - `BuildableDictionaryProperty`
public class BuildableSetProperty<Element> where Element: Hashable {

    /// The set that the client's property will be initialized to when the builder builds.
    private var set: Set<Element>

    /// Initialize the `BuildableSetProperty`.
    public init() {
        set = []
    }

    /// Sets the set that the client's property will be initialized to.
    /// - Parameters:
    ///   - value: The set that the client's property will be initialized to.
    public func set(value: Set<Element>) {
        set = value
    }

    /// Inserts an element into the set that the client's property will be initialized to.
    /// - Parameters:
    ///   - element: The element that will be inserted into the set.
    public func insert(element: Element) {
        set.insert(element)
    }

    /// Inserts the elements of another set into the set that the client's property will be initialized to.
    /// - Parameters:
    ///   - other: The other set whose elements should be inserted into this `BuildableSetProperty`'s set.
    public func formUnion(other: Set<Element>) {
        set.formUnion(other)
    }

    /// Removes all elements from the set that the client's property will be initialized to.
    public func removeAll() {
        set.removeAll()
    }

    /// Returns the set that the client's property should be initialized to.
    /// - Returns: The set that the client's property should be initialized to.
    public func build() -> Set<Element> {
        return set
    }
}
