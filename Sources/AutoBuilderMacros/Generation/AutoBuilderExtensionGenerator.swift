import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Types that conform to `AutoBuilderExtensionGenerator` are able to generate a builder class for a declaration.
protocol AutoBuilderExtensionGenerator {

    /// The type of the declaration that the generator handles.
    associatedtype DeclType: DeclGroupSyntax

    /// The type of the output of the analysis phase that will be passed into the generation phase.
    associatedtype AnalysisOutput

    /// Analyzes the declaration that the `@Buildable` macro is attached to.
    /// - Parameters:
    ///   - decl: The declaration that the `@Buildable` macro is attached to.
    /// - Returns: An `AnalysisResult` that contains the `AnalysisOutput` if the declaration is well formed, or the
    /// error diagnostics if the declaration is not well formed.
    static func analyze(decl: DeclType) -> AnalysisResult<AnalysisOutput>

    /// Generates the builder class and builder related methods for the declaration that the `@Buildable` macro is
    /// attached to.
    /// - Parameters:
    ///   - analysisOutput: The `AnalysisOutput` that was returned from `analyze(decl:)`.
    ///   - clientType: The type of the builder's client.
    ///   - isPublic: `true` if the client type was declared with the `public` or `open` access modifiers, `false`
    ///   otherwise.
    ///   - context: The macro expansion context.
    /// - Returns: The builder class for the declaration the macro is attached to, as well as the `init(with:)` and
    /// `toBuilder()` methods.
    static func generateMembers(
        from analysisOutput: AnalysisOutput,
        clientDecl: DeclType,
        isPublic: Bool,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax]
}

/// The result of analyzing a declaration that has the `@Buildable` macro attached to it.
enum AnalysisResult<AnalysisOutput> {

    /// The analysis completed successfully.
    /// - Parameters:
    ///   - analysisOutput: The output data structure that will be used in the generation phase.
    ///   - nonFatalDiagnostics: Any diagnostics discovered during analysis that do not prevent generating the builder
    ///   class, such as warnings and notes.
    case success(analysisOutput: AnalysisOutput, nonFatalDiagnostics: [Diagnostic])

    /// The analysis discovered one or more issues that prevent generating the builder class.
    /// - Parameters:
    ///   - diagnostics: The diagnostics that describe the issues that prevent generating the builder class.
    case error(diagnostics: [Diagnostic])
}
