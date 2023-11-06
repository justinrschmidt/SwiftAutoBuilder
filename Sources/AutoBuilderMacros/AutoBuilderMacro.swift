import SwiftCompilerPlugin
import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

/// The macro that generates a builder class for the type that the macro is attached to. The builder class is generated
/// in an extension of the attached type. The extension also provides conformance to `Buildable` for the attached type.
///
/// The macro's work is divided into two main phases: the analysis phase and the generation phase.
///
/// The analysis phase inspects the declarations in the attached type. It extracts the information that is needed to
/// generate the builder class and passes that information into the generation phase. If there are any issues that would
/// prevent the builder class from being generated, those issues are emitted from the analysis phase as compiler
/// diagnostics and the generation phase is not run.
///
/// The generation phase assumes that the code of the attached type is well formed. It uses the information emitted by
/// the analysis phase to generate a builder class for the attached type.
///
/// The analysis and generation are handled by types that conform to `AutoBuilderExtensionGenerator`.
public struct AutoBuilderMacro: ExtensionMacro {

    /// The list of `AutoBuilderExtensionGenerator`s that can generate a builder class from a declaration.
    private static let generators: [any AutoBuilderExtensionGenerator.Type] = [
        EnumExtensionGenerator.self,
        StructExtensionGenerator.self
    ]

    // TODO: Look at the types passed into conformingTo once issue #2031 is fixed.
    // Issue #2031 describes how `assertMacroExpansion()` always passes an empty array into the conformingTo parameter
    // in tests. This method should only return an `ExtensionDeclSyntax` when `conformingTo` contains `Buildable`.
    // https://github.com/apple/swift-syntax/issues/2031
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        for generator in Self.generators {
            if canExpand(declaration, with: generator) {
                return try expand(declaration, with: generator, clientType: type, in: context)
            }
        }
        context.diagnose(
            Diagnostic(node: node.cast(Syntax.self), message: AutoBuilderDiagnostic.invalidTypeForAutoBuilder)
        )
        return []
    }

    private static func canExpand<Generator>(
        _ declaration: some DeclGroupSyntax,
        with generator: Generator.Type
    ) -> Bool where Generator: AutoBuilderExtensionGenerator {
        return declaration.is(Generator.DeclType.self)
    }

    private static func expand<Generator>(
        _ declaration: DeclGroupSyntax,
        with generator: Generator.Type,
        clientType: some TypeSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] where Generator: AutoBuilderExtensionGenerator {
        let decl = declaration.cast(Generator.DeclType.self)
        switch generator.analyze(decl: decl) {
        case let .success(analysisOutput, nonFatalDiagnostics):
            nonFatalDiagnostics.forEach(context.diagnose(_:))
            let isPublic = hasPublic(modifiers: decl.modifiers)
            return try [
                generator.generateExtension(
                    from: analysisOutput,
                    clientType: clientType.trimmed,
                    isPublic: isPublic, in: context)
            ]
        case let .error(diagnostics):
            diagnostics.forEach(context.diagnose(_:))
            return []
        }
    }

    private static func hasPublic(modifiers: DeclModifierListSyntax) -> Bool {
        return modifiers.contains(where: { modifier in
            modifier.name.tokenKind == .keyword(.public) || modifier.name.tokenKind == .keyword(.open)
        })
    }
}

enum AutoBuilderMacroError: Error {
    case missingType
}

@main
struct AutoBuilderPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        AutoBuilderMacro.self
    ]
}
