// Minimal xunit attribute stand-ins so the real test sources compile into this
// harness; assertions still come from the genuine xunit.v3.assert package.
namespace Xunit;

[AttributeUsage(AttributeTargets.Method, AllowMultiple = false)]
internal sealed class FactAttribute : Attribute
{
    public string? Skip { get; set; }
}

[AttributeUsage(AttributeTargets.Method, AllowMultiple = false)]
internal sealed class TheoryAttribute : Attribute
{
    public string? Skip { get; set; }
}

[AttributeUsage(AttributeTargets.Method, AllowMultiple = true)]
internal sealed class InlineDataAttribute : Attribute
{
    public InlineDataAttribute(params object?[] data) => Data = data;

    public object?[] Data { get; }
}

[AttributeUsage(AttributeTargets.Method, AllowMultiple = true)]
internal sealed class MemberDataAttribute : Attribute
{
    public MemberDataAttribute(string memberName, params object?[] parameters)
    {
        MemberName = memberName;
        Parameters = parameters;
    }

    public string MemberName { get; }

    public object?[] Parameters { get; }
}

[AttributeUsage(AttributeTargets.Method | AttributeTargets.Class, AllowMultiple = true)]
internal sealed class TraitAttribute : Attribute
{
    public TraitAttribute(string name, string value)
    {
        Name = name;
        Value = value;
    }

    public string Name { get; }

    public string Value { get; }
}
