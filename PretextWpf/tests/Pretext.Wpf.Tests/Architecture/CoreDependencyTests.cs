using System.Reflection;
using Xunit;

namespace Pretext.Wpf.Tests.Architecture;

public sealed class CoreDependencyTests
{
    [Fact]
    [Trait("Category", "Error")]
    public void IsAllowed_FrameworkAndWpfAssemblies_ExpectedPolicy()
    {
        Assert.True(CoreDependencyPolicy.IsAllowed("System.Runtime"));
        Assert.True(CoreDependencyPolicy.IsAllowed("PresentationCore"));
        Assert.False(CoreDependencyPolicy.IsAllowed("Markdig"));
    }

    [Fact]
    [Trait("Category", "Error")]
    public void CoreAssembly_ReferencesOnlyFrameworkAndWpfAssemblies_Expected()
    {
        Assembly core = Assembly.Load(new AssemblyName("Pretext.Wpf"));
        string[] disallowed = core.GetReferencedAssemblies()
            .Select(reference => reference.Name ?? string.Empty)
            .Where(name => !CoreDependencyPolicy.IsAllowed(name))
            .Order(StringComparer.Ordinal)
            .ToArray();

        Assert.Empty(disallowed);
    }
}
