namespace Pretext.Wpf;

/// <summary>
/// Fixed layout profile for the WPF text engine.
/// Upstream pretext sniffs browser engines and adapts epsilon/breaking quirks
/// per engine; WPF is a single deterministic engine, so the profile collapses
/// to the upstream server-side defaults.
/// </summary>
internal static class LayoutProfile
{
    /// <summary>Tolerance for "does this advance still fit the line" comparisons.</summary>
    internal const double LineFitEpsilon = 0.005;

    /// <summary>
    /// Past this size, growing-prefix measurement of a breakable segment would
    /// recreate a pathological superlinear prepare-time path; switch to the
    /// cheaper pair-context model and keep the public behavior linear.
    /// </summary>
    internal const int MaxPrefixFitGraphemes = 96;
}
