public class BuildableOptionalProperty<Wrapped> {
    private let propertyName: String
    private var value: Wrapped?
    private var subBuilder: Optional<any BuilderProtocol>

    public init(_ value: Wrapped? = nil, name: String) {
        propertyName = name
        self.value = nil
        subBuilder = nil
        set(value: value)
    }

    public func set(value: Wrapped?) {
        if let buildableValue = value.flatMap({ $0 as? any Buildable }) {
            subBuilder = buildableValue.toBuilder() as any BuilderProtocol
            self.value = nil
        } else {
            subBuilder = nil
            self.value = value
        }
    }

    public func build() throws -> Wrapped? {
        return try value ?? subBuilder?.build() as? Wrapped
    }
}

extension BuildableOptionalProperty where Wrapped: Buildable {
    public var builder: Wrapped.Builder {
        get {
            if let subBuilder = self.subBuilder.flatMap({ $0 as? Wrapped.Builder }) {
                return subBuilder
            } else {
                let subBuilder = value?.toBuilder() ?? Wrapped.Builder()
                value = nil
                self.subBuilder = subBuilder
                return subBuilder
            }
        }
        set {
            value = nil
            subBuilder = newValue
        }
    }
}
