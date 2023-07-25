public class BuildableArrayProperty<Element> {
    private var array: [Element]

    public init() {
        array = []
    }

    public func set(value: [Element]) {
        array = value
    }

    public func append(element: Element) {
        array.append(element)
    }

    public func append<C>(contentsOf collection: C) where C: Collection, C.Element == Element {
        array.insert(contentsOf: collection, at: array.endIndex)
    }

    public func removeAll() {
        array.removeAll()
    }

    public func build() -> [Element] {
        return array
    }
}
