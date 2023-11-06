import SwiftSyntax

extension IdentifierTypeSyntax {
    /// Initialize an `IdentifierTypeSyntax` from a name and with optional generic arguments.
    /// - Parameters:
    ///   - name: The identifier of the type.
    ///   - genericTypes: A list of types to use in the generic argument list. If empty, no generic argument clause is
    ///   created.
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
