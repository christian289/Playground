namespace Pretext.Wpf.Tests.Architecture;

internal static class CoreDependencyPolicy
{
    private static readonly HashSet<string> ExactAssemblyNames = new(StringComparer.Ordinal)
    {
        "System",
        "Microsoft.CSharp",
        "WindowsBase",
        "PresentationCore",
        "PresentationFramework",
        "System.Xaml",
        "netstandard",
        "mscorlib",
    };

    public static bool IsAllowed(string assemblyName)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(assemblyName);

        return ExactAssemblyNames.Contains(assemblyName)
            || assemblyName.StartsWith("System.", StringComparison.Ordinal)
            || assemblyName.StartsWith("Microsoft.Win32.", StringComparison.Ordinal);
    }
}
