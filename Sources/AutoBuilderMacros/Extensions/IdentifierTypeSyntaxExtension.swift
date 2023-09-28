import SwiftSyntax

extension IdentifierTypeSyntax {
    init(name: String, genericTypes: [TypeSyntaxProtocol] = []) {
        if genericTypes.isEmpty {
            self.init(name: .identifier(name))
        } else {
            self.init(
                name: .identifier(name),
                genericArgumentClause: GenericArgumentClauseSyntax(arguments: GenericArgumentListSyntax {
                    for type in genericTypes {
                        GenericArgumentSyntax(argument: type)
                    }
                }))
        }
    }
}
