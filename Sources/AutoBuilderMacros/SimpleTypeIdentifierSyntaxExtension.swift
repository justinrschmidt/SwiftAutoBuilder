import SwiftSyntax

extension SimpleTypeIdentifierSyntax {
    init(name: String, genericTypes: [TypeSyntaxProtocol] = []) {
        if genericTypes.isEmpty {
            self.init(name: .identifier(name))
        } else {
            self.init(
                name: .identifier(name),
                genericArgumentClause: GenericArgumentClauseSyntax(arguments: GenericArgumentListSyntax {
                    for type in genericTypes {
                        GenericArgumentSyntax(argumentType: type)
                    }
                }))
        }
    }
}
