import SwiftSyntax
import SwiftDiagnostics

public enum AutoBuilderFixIt: FixItMessage {
    public static let domain = "AutoBuilderMacro"

    case appendFinalModifier
    case removeSuperclassInitializer

    public var message: String {
        switch self {
        case .appendFinalModifier:
            return "Add \"final\""
        case .removeSuperclassInitializer:
            return "Remove superclass initializer"
        }
    }

    public var fixItID: MessageID {
        switch self {
        case .appendFinalModifier:
            MessageID(domain: "", id: "")
        case .removeSuperclassInitializer:
            MessageID(domain: "", id: "")
        }
    }
}
