import SwiftSyntax
import SwiftDiagnostics

public enum AutoBuilderFixIt: FixItMessage {
    public static let domain = "AutoBuilderMacro"

    case appendFinalModifier

    public var message: String {
        switch self {
        case .appendFinalModifier:
            return "Add \"final\""
        }
    }

    public var fixItID: MessageID {
        switch self {
        case .appendFinalModifier:
            MessageID(domain: "", id: "")
        }
    }
}
