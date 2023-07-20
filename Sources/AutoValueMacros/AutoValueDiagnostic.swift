import SwiftSyntax
import SwiftDiagnostics

public enum AutoValueDiagnostic: DiagnosticMessage {
    public static let domain = "AutoValueMacro"

    case impliedVariableType(identifier: String)
    case invalidTypeForAutoValue

    public var severity: DiagnosticSeverity {
        switch self {
        case .impliedVariableType(_),
                .invalidTypeForAutoValue:
            return .error
        }
    }

    public var message: String {
        switch self {
        case .impliedVariableType(let identifier):
            return "Type annotation missing for '\(identifier)'. AutoBuilder requires all variable properties to have type annotations."
        case .invalidTypeForAutoValue:
            return "@AutoValue can only be applied to structs"
        }
    }

    public var diagnosticID: MessageID {
        switch self {
        case .impliedVariableType(_):
            return MessageID(domain: Self.domain, id: "ImpliedVariableType")
        case .invalidTypeForAutoValue:
            return MessageID(domain: Self.domain, id: "InvalidTypeForAutoValue")
        }
    }
}
