extension Optional: Buildable {
    public init(with builder: Builder) throws {
        self = try builder.build()
    }

    public func toBuilder() -> Builder {
        let builder = Builder()
        builder.set(value: self)
        return builder
    }

    public class Builder: BuilderProtocol {
        public let wrappedValue: BuildableOptionalProperty<Wrapped>

        public required init() {
            wrappedValue = BuildableOptionalProperty(name: "wrappedValue")
        }

        @discardableResult
        public func set(value: Wrapped?) -> Builder {
            wrappedValue.set(value: value)
            return self
        }

        public func build() throws -> Optional {
            return try wrappedValue.build()
        }
    }
}
