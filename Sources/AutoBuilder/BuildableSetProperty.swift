public class BuildableSetProperty<Element> where Element: Hashable {
    private var set: Set<Element>

    public init() {
        set = []
    }

    public func set(value: Set<Element>) {
        set = value
    }

    public func insert(element: Element) {
        set.insert(element)
    }

    public func formUnion(other: Set<Element>) {
        set.formUnion(other)
    }

    public func removeAll() {
        set.removeAll()
    }

    public func build() -> Set<Element> {
        return set
    }
}
