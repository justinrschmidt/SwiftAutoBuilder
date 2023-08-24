import SwiftSyntax
import SwiftDiagnostics

public enum AutoBuilderDiagnostic: DiagnosticMessage {
    public static let domain = "AutoBuilderMacro"

    case impliedVariableType(identifier: String)
    case noAssociatedValues(enumName: String)
    case enumWithNoCases(enumName: String)
    case enumWithOverloadedCases(overloadedCases: [String])
    case invalidTypeForAutoBuilder

    public var severity: DiagnosticSeverity {
        switch self {
        case .impliedVariableType(_),
                .invalidTypeForAutoBuilder,
                .enumWithNoCases(_),
                .enumWithOverloadedCases(_):
            return .error
        case .noAssociatedValues(_):
            return .warning
        }
    }

    public var message: String {
        switch self {
        case let .impliedVariableType(identifier):
            return "Type annotation missing for '\(identifier)'. AutoBuilder requires all variable properties to have type annotations."
        case let .noAssociatedValues(enumName):
            return "\(enumName) does not have any cases with associated values."
        case let .enumWithNoCases(enumName):
            return "\(enumName) (aka: Never) does not have any cases and cannot be instantiated."
        case let .enumWithOverloadedCases(overloadedCases):
            return "@AutoBuilder does not support overloaded cases (\(overloadedCases.joined(separator: ", "))) due to ambiguity caused by SE-0155 not being fully implemented."
        case .invalidTypeForAutoBuilder:
            return "@AutoBuilder can only be applied to structs"
        }
    }

    public var diagnosticID: MessageID {
        switch self {
        case .impliedVariableType(_):
            return MessageID(domain: Self.domain, id: "ImpliedVariableType")
        case .noAssociatedValues(_):
            return MessageID(domain: Self.domain, id: "NoAssociatedValues")
        case .enumWithNoCases(_):
            return MessageID(domain: Self.domain, id: "EnumWithNoCases")
        case .enumWithOverloadedCases(_):
            return MessageID(domain: Self.domain, id: "EnumWithOverloadedCases")
        case .invalidTypeForAutoBuilder:
            return MessageID(domain: Self.domain, id: "InvalidTypeForAutoBuilder")
        }
    }
}
