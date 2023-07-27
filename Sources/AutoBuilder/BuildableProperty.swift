public class BuildableProperty<T> {
    private let propertyName: String
    private var value: T?
    private var subBuilder: Optional<any BuilderProtocol>

    public init(_ value: T? = nil, name: String) {
        propertyName = name
        self.value = value
        subBuilder = nil
    }

    public func set(value: T) {
        subBuilder = nil
        self.value = value
    }

    public func build() throws -> T {
        if let value = value {
            return value
        } else if let value = try subBuilder?.build() as? T {
            return value
        } else {
            throw BuilderError.missingValue(propertyName: propertyName)
        }
    }
}

extension BuildableProperty where T: Buildable, T.Builder: BuilderProtocol, T.Builder.Client == T {
    public var builder: T.Builder {
        get {
            if let subBuilder = self.subBuilder as? T.Builder {
                return subBuilder
            } else {
                let subBuilder = value?.toBuilder() ?? T.Builder()
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
