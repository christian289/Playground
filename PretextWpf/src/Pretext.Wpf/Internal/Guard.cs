namespace Pretext.Wpf;

internal static class Guard
{
    public static double PositiveFinite(double value, string parameterName)
    {
        if (!double.IsFinite(value) || value <= 0)
        {
            throw new ArgumentOutOfRangeException(parameterName, value, "Value must be finite and greater than zero.");
        }

        return value;
    }

    public static double NonNegativeFinite(double value, string parameterName)
    {
        if (!double.IsFinite(value) || value < 0)
        {
            throw new ArgumentOutOfRangeException(parameterName, value, "Value must be finite and non-negative.");
        }

        return value;
    }

    public static double Finite(double value, string parameterName)
    {
        if (!double.IsFinite(value))
        {
            throw new ArgumentOutOfRangeException(parameterName, value, "Value must be finite.");
        }

        return value;
    }

    public static TEnum DefinedEnum<TEnum>(TEnum value, string parameterName)
        where TEnum : struct, Enum
    {
        if (!Enum.IsDefined(value))
        {
            throw new ArgumentOutOfRangeException(parameterName, value, "Value must be a defined enum member.");
        }

        return value;
    }
}
