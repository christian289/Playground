// Offline test runner: executes the platform-independent xunit suites (analysis, bidi,
// upstream parity) on any OS. The real test project targets net10.0-windows and its host
// runtime, Microsoft.WindowsDesktop.App, exists only on Windows — so this runner is the
// only way to exercise the layout core from macOS or Linux.
using System.Reflection;

namespace Pretext.Wpf.Tools.Parity;

internal static class Program
{
    private static int Main()
    {
        Type[] suites =
        [
            typeof(Pretext.Wpf.Tests.Analysis.TextAnalyzerTests),
            typeof(Pretext.Wpf.Tests.Bidi.BidiLevelResolverTests),
            typeof(Pretext.Wpf.Tests.Parity.UpstreamParityTests),
            typeof(Pretext.Wpf.Tests.Layout.TextLayoutEngineTests),
            typeof(Pretext.Wpf.Tests.Layout.UpstreamRegressionTests),
            typeof(Pretext.Wpf.Tests.RichInline.RichInlineLayoutEngineTests),
        ];

        int passed = 0;
        int failed = 0;

        foreach (Type suite in suites)
        {
            foreach (MethodInfo method in suite.GetMethods(BindingFlags.Public | BindingFlags.Instance))
            {
                bool isFact = HasAttribute(method, "FactAttribute");
                bool isTheory = HasAttribute(method, "TheoryAttribute");
                if (!isFact && !isTheory)
                {
                    continue;
                }

                foreach (object?[] arguments in GetInvocations(method, isTheory))
                {
                    object instance = Activator.CreateInstance(suite)!;
                    try
                    {
                        method.Invoke(instance, arguments);
                        passed++;
                    }
                    catch (TargetInvocationException ex)
                    {
                        failed++;
                        string argumentText = arguments.Length == 0 ? string.Empty : $"({string.Join(", ", arguments)})";
                        Console.WriteLine($"FAIL {suite.Name}.{method.Name}{argumentText}");
                        Console.WriteLine($"     {ex.InnerException?.Message}");
                    }
                }
            }
        }

        Console.WriteLine($"passed={passed} failed={failed}");
        return failed == 0 ? 0 : 1;
    }

    private static bool HasAttribute(MethodInfo method, string attributeName)
    {
        foreach (Attribute attribute in method.GetCustomAttributes())
        {
            if (attribute.GetType().Name == attributeName)
            {
                return true;
            }
        }

        return false;
    }

    private static List<object?[]> GetInvocations(MethodInfo method, bool isTheory)
    {
        if (!isTheory)
        {
            return [[]];
        }

        List<object?[]> invocations = [];
        foreach (Attribute attribute in method.GetCustomAttributes())
        {
            Type attributeType = attribute.GetType();
            if (attributeType.Name == "InlineDataAttribute"
                && attributeType.GetProperty("Data")?.GetValue(attribute) is object?[] data)
            {
                invocations.Add(data);
                continue;
            }

            if (attributeType.Name != "MemberDataAttribute"
                || attributeType.GetProperty("MemberName")?.GetValue(attribute) is not string memberName)
            {
                continue;
            }

            object? source = method.DeclaringType!
                .GetMethod(memberName, BindingFlags.Public | BindingFlags.Static)
                ?.Invoke(null, null)
                ?? method.DeclaringType!
                    .GetProperty(memberName, BindingFlags.Public | BindingFlags.Static)
                    ?.GetValue(null);

            if (source is System.Collections.IEnumerable rows)
            {
                foreach (object? row in rows)
                {
                    if (row is object?[] values)
                    {
                        invocations.Add(values);
                    }
                }
            }
        }

        return invocations;
    }
}
