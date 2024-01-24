import SwiftSyntax
import SwiftDiagnostics

/// Diagnostic messages emitted by the AutoBuilder macro.
public enum AutoBuilderDiagnostic: DiagnosticMessage {
    /// The domain to use for the MessageIDs.
    public static let domain = "AutoBuilderMacro"

    /// Diagnosed when a variable's type is not explicitly stated.
    /// - Parameters:
    ///   - identifierPattern: The variable's identifier.
    case impliedVariableType(identifierPattern: IdentifierPatternSyntax)

    /// Diagnosed when no cases of an enum have associated values.
    /// - Parameters:
    ///   - enumName: The identifier of the enum.
    case noAssociatedValues(enumName: String)

    /// Diagnosed when an enum has no cases.
    /// - Parameters:
    ///   - enumName: The identifier of the enum.
    case enumWithNoCases(enumName: String)

    /// Diagnosed when an enum has one or more overloaded cases.
    ///
    /// Enums with overloaded cases are not supported because there is no way to match between the different overloaded
    /// cases. This issue is the result of SE-0155 not being fully implemented.
    /// https://github.com/apple/swift-evolution/blob/main/proposals/0155-normalize-enum-case-representation.md#revision-history
    ///
    /// - Parameters:
    ///   - overloadedCases: The list of cases that are overloaded.
    case enumWithOverloadedCases(overloadedCases: [String])

    /// Diagnosed when the label for an enum case's associated value is invalid. AutoBuilder reserves labels that match
    /// `\^index_[0-9]+$\` for associated values that have no label and must be identified by their index.
    case invalidEnumAssociatedValueLabel

    /// Diagnosed when `@Buildable` is attached to a type that AutoBuilder does not support.
    /// Supported types are defined in `AutoBuilderMacro.generators`.
    case invalidTypeForAutoBuilder

    /// Diagnosed when `@Buildable` is attached to a non-final class.
    case nonFinalClass

    public var severity: DiagnosticSeverity {
        switch self {
        case .impliedVariableType,
             .invalidTypeForAutoBuilder,
             .enumWithNoCases,
             .enumWithOverloadedCases,
             .invalidEnumAssociatedValueLabel,
             .nonFinalClass:
            return .error
        case .noAssociatedValues:
            return .warning
        }
    }

    public var message: String {
        switch self {
        case let .impliedVariableType(identifierPattern):
            return "Type annotation missing for '\(identifierPattern.identifier.text)'. @Buildable requires all variable properties to have type annotations."
        case let .noAssociatedValues(enumName):
            return "\(enumName) does not have any cases with associated values."
        case let .enumWithNoCases(enumName):
            return "\(enumName) (aka: Never) does not have any cases and cannot be instantiated."
        case let .enumWithOverloadedCases(overloadedCases):
            return "@Buildable does not support overloaded cases (\(overloadedCases.joined(separator: ", "))) due to ambiguity caused by SE-0155 not being fully implemented."
        case .invalidEnumAssociatedValueLabel:
            return "@Buildable enum associated value labels must not match \"^index_[0-9]+$\"."
        case .invalidTypeForAutoBuilder:
            return "@Buildable can only be applied to structs, enums, and classes"
        case .nonFinalClass:
            return "@Buildable can only be applied to classes that are declared as final."
        }
    }

    public var diagnosticID: MessageID {
        switch self {
        case .impliedVariableType:
            return MessageID(domain: Self.domain, id: "ImpliedVariableType")
        case .noAssociatedValues:
            return MessageID(domain: Self.domain, id: "NoAssociatedValues")
        case .enumWithNoCases:
            return MessageID(domain: Self.domain, id: "EnumWithNoCases")
        case .enumWithOverloadedCases:
            return MessageID(domain: Self.domain, id: "EnumWithOverloadedCases")
        case .invalidEnumAssociatedValueLabel:
            return MessageID(domain: Self.domain, id: "InvalidEnumAssociatedValueLabel")
        case .invalidTypeForAutoBuilder:
            return MessageID(domain: Self.domain, id: "InvalidTypeForAutoBuilder")
        case .nonFinalClass:
            return MessageID(domain: Self.domain, id: "NonFinalClass")
        }
    }
}
