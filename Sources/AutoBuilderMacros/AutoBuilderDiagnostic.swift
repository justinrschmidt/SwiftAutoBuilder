import SwiftSyntax
import SwiftDiagnostics

public enum AutoBuilderDiagnostic: DiagnosticMessage {
    public static let domain = "AutoBuilderMacro"

    case impliedVariableType(identifier: String)
    case noAssociatedValues(enumName: String)
    case invalidTypeForAutoBuilder

    public var severity: DiagnosticSeverity {
        switch self {
        case .impliedVariableType(_),
                .invalidTypeForAutoBuilder:
            return .error
        case .noAssociatedValues(_):
            return .warning
        }
    }

    public var message: String {
        switch self {
        case .impliedVariableType(let identifier):
            return "Type annotation missing for '\(identifier)'. AutoBuilder requires all variable properties to have type annotations."
        case .noAssociatedValues(let enumName):
            return "\(enumName) does not have any cases with associated values."
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
        case .invalidTypeForAutoBuilder:
            return MessageID(domain: Self.domain, id: "InvalidTypeForAutoBuilder")
        }
    }
}
