import SwiftSyntax

struct EnumUnionCase: Equatable, CustomStringConvertible {
    let caseIdentifierPattern: IdentifierPatternSyntax
    let associatedValues: [Property]

    var caseIdentifier: String {
        return caseIdentifierPattern.identifier.text
    }

    var description: String {
        return "(\(caseIdentifier), \(associatedValues)"
    }

    static func ==(lhs: EnumUnionCase, rhs: EnumUnionCase) -> Bool {
        guard lhs.caseIdentifier == rhs.caseIdentifier else { return false }
        guard lhs.associatedValues == rhs.associatedValues else { return false }
        return true
    }
}
