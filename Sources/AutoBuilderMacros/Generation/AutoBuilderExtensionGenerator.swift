import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

protocol AutoBuilderExtensionGenerator {
    associatedtype DeclType: DeclGroupSyntax
    associatedtype AnalysisOutput

    static func analyze(decl: DeclType) -> AnalysisResult<AnalysisOutput>
    static func generateExtension(
        from analysisOutput: AnalysisOutput,
        clientType: some TypeSyntaxProtocol,
        isPublic: Bool,
        in context: some MacroExpansionContext
    ) throws -> ExtensionDeclSyntax
}

enum AnalysisResult<AnalysisOutput> {
    case success(analysisOutput: AnalysisOutput, nonFatalDiagnostics: [Diagnostic])
    case error(diagnostics: [Diagnostic])
}
