import SwiftSyntax

struct EnumUnionCase: Equatable, CustomStringConvertible {
    let caseIdentifierPattern: IdentifierPatternSyntax
    let associatedValues: [AssociatedValue]

    var valueIdentifierPatterns: [IdentifierPatternSyntax] {
        return associatedValues.map({ $0.identifierPattern })
    }

    var description: String {
        return "(\(caseIdentifierPattern.identifier.text), \(associatedValues)"
    }

    static func == (lhs: EnumUnionCase, rhs: EnumUnionCase) -> Bool {
        guard lhs.caseIdentifierPattern.identifier.text == rhs.caseIdentifierPattern.identifier.text else {
            return false
        }
        guard lhs.associatedValues == rhs.associatedValues else { return false }
        return true
    }
}
