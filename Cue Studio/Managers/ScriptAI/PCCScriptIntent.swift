import FoundationModels

/// Chosen from the current request during guided generation, never from an English keyword list.
@Generable
nonisolated enum PCCScriptIntent {
    case developed
    case conciseStatement
}
