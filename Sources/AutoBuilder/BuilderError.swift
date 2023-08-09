/// Errors that are thrown by builders.
public enum BuilderError: Error {

    /// Thrown when a value in one of a builder's properties is not set.
    /// - Parameter propertyName: The name of the property in the client type that this error is associated with.
    case missingValue(propertyName: String)

    /// Thrown when a builder for an enum does not have a case set.
    case noEnumCaseSet
}
