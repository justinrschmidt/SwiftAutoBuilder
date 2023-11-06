import SwiftSyntax
import SwiftSyntaxBuilder

/// Contains methods relating to analyzing enum case declarations and extracting the information about those
/// declarations that is needed in the generation phase.
struct EnumInspector {
    static func getCases(from members: MemberBlockItemListSyntax) -> [EnumUnionCase] {
        return members.compactMap({ $0.decl.as(EnumCaseDeclSyntax.self) }).flatMap(getCases(from:))
    }

    private static func getCases(from caseDecl: EnumCaseDeclSyntax) -> [EnumUnionCase] {
        return caseDecl.elements.map(getCase(from:))
    }

    private static func getCase(from element: EnumCaseElementSyntax) -> EnumUnionCase {
        let values = (element.parameterClause?.parameters).map(getAssociatedValues(from:)) ?? []
        return EnumUnionCase(
            caseIdentifierPattern: IdentifierPatternSyntax(identifier: element.name),
            associatedValues: values)
    }

    private static func getAssociatedValues(from list: EnumCaseParameterListSyntax) -> [AssociatedValue] {
        var values: [AssociatedValue] = []
        for (index, element) in list.enumerated() {
            let label: AssociatedValue.Label
            if let nameToken = element.firstName {
                label = .identifierPattern(IdentifierPatternSyntax(identifier: nameToken))
            } else {
                label = .index(index)
            }
            values.append(AssociatedValue(
                            label: label,
                            variableType: VariableInspector.getVariableType(from: element.type),
                            isInitialized: element.defaultValue != nil,
                            firstNameToken: element.firstName))
        }
        return values
    }
}
