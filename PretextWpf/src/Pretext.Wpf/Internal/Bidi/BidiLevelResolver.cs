using System.Windows;

namespace Pretext.Wpf;

internal static class BidiLevelResolver
{
    internal static sbyte[]? ComputeSegmentLevels(
        string normalized,
        int[] segmentStarts,
        FlowDirection flowDirection)
    {
        ArgumentNullException.ThrowIfNull(normalized);
        ArgumentNullException.ThrowIfNull(segmentStarts);
        Guard.DefinedEnum(flowDirection, nameof(flowDirection));
        ValidateSegmentStarts(normalized, segmentStarts);

        int baseLevel = flowDirection == FlowDirection.RightToLeft ? 1 : 0;
        sbyte[]? codeUnitLevels = ComputeCodeUnitLevels(normalized, baseLevel);
        if (codeUnitLevels is null)
        {
            return null;
        }

        sbyte[] segmentLevels = new sbyte[segmentStarts.Length];
        for (int index = 0; index < segmentStarts.Length; index++)
        {
            segmentLevels[index] = codeUnitLevels[segmentStarts[index]];
        }

        return segmentLevels;
    }

    private static sbyte[]? ComputeCodeUnitLevels(string text, int baseLevel)
    {
        int length = text.Length;
        if (length == 0)
        {
            return baseLevel == 0 ? null : Array.Empty<sbyte>();
        }

        BidiType[] types = new BidiType[length];
        bool sawBidi = false;
        for (int index = 0; index < length;)
        {
            int codePoint;
            int codeUnitLength;
            char first = text[index];
            if (char.IsHighSurrogate(first) && index + 1 < length && char.IsLowSurrogate(text[index + 1]))
            {
                codePoint = char.ConvertToUtf32(first, text[index + 1]);
                codeUnitLength = 2;
            }
            else
            {
                codePoint = first;
                codeUnitLength = 1;
            }

            BidiType type = ClassifyCodePoint(codePoint);
            sawBidi |= type is BidiType.R or BidiType.AL or BidiType.AN;
            for (int codeUnit = 0; codeUnit < codeUnitLength; codeUnit++)
            {
                types[index + codeUnit] = type;
            }

            index += codeUnitLength;
        }

        if (baseLevel == 0 && !sawBidi)
        {
            return null;
        }

        sbyte[] levels = new sbyte[length];
        Array.Fill(levels, (sbyte)baseLevel);
        BidiType embeddingDirection = (baseLevel & 1) == 0 ? BidiType.L : BidiType.R;
        ResolveWeakTypes(types, embeddingDirection);
        ResolveNeutralTypes(types, embeddingDirection);
        ResolveImplicitLevels(types, levels);
        return levels;
    }

    private static void ResolveWeakTypes(BidiType[] types, BidiType startOfRun)
    {
        BidiType lastType = startOfRun;
        for (int index = 0; index < types.Length; index++)
        {
            if (types[index] == BidiType.NSM)
            {
                types[index] = lastType;
            }
            else
            {
                lastType = types[index];
            }
        }

        lastType = startOfRun;
        for (int index = 0; index < types.Length; index++)
        {
            BidiType type = types[index];
            if (type == BidiType.EN)
            {
                types[index] = lastType == BidiType.AL ? BidiType.AN : BidiType.EN;
            }
            else if (type is BidiType.R or BidiType.L or BidiType.AL)
            {
                lastType = type;
            }
        }

        for (int index = 0; index < types.Length; index++)
        {
            if (types[index] == BidiType.AL)
            {
                types[index] = BidiType.R;
            }
        }

        for (int index = 1; index < types.Length - 1; index++)
        {
            if (types[index] == BidiType.ES && types[index - 1] == BidiType.EN && types[index + 1] == BidiType.EN)
            {
                types[index] = BidiType.EN;
            }

            if (types[index] == BidiType.CS
                && types[index - 1] is BidiType.EN or BidiType.AN
                && types[index + 1] == types[index - 1])
            {
                types[index] = types[index - 1];
            }
        }

        for (int index = 0; index < types.Length; index++)
        {
            if (types[index] != BidiType.EN)
            {
                continue;
            }

            for (int before = index - 1; before >= 0 && types[before] == BidiType.ET; before--)
            {
                types[before] = BidiType.EN;
            }

            for (int after = index + 1; after < types.Length && types[after] == BidiType.ET; after++)
            {
                types[after] = BidiType.EN;
            }
        }

        for (int index = 0; index < types.Length; index++)
        {
            if (types[index] is BidiType.WS or BidiType.ES or BidiType.ET or BidiType.CS)
            {
                types[index] = BidiType.ON;
            }
        }

        lastType = startOfRun;
        for (int index = 0; index < types.Length; index++)
        {
            BidiType type = types[index];
            if (type == BidiType.EN)
            {
                types[index] = lastType == BidiType.L ? BidiType.L : BidiType.EN;
            }
            else if (type is BidiType.R or BidiType.L)
            {
                lastType = type;
            }
        }
    }

    private static void ResolveNeutralTypes(BidiType[] types, BidiType embeddingDirection)
    {
        for (int index = 0; index < types.Length; index++)
        {
            if (types[index] != BidiType.ON)
            {
                continue;
            }

            int end = index + 1;
            while (end < types.Length && types[end] == BidiType.ON)
            {
                end++;
            }

            BidiType before = index > 0 ? types[index - 1] : embeddingDirection;
            BidiType after = end < types.Length ? types[end] : embeddingDirection;
            BidiType beforeDirection = before == BidiType.L ? BidiType.L : BidiType.R;
            BidiType afterDirection = after == BidiType.L ? BidiType.L : BidiType.R;
            if (beforeDirection == afterDirection)
            {
                for (int neutral = index; neutral < end; neutral++)
                {
                    types[neutral] = beforeDirection;
                }
            }

            index = end - 1;
        }

        for (int index = 0; index < types.Length; index++)
        {
            if (types[index] == BidiType.ON)
            {
                types[index] = embeddingDirection;
            }
        }
    }

    private static void ResolveImplicitLevels(BidiType[] types, sbyte[] levels)
    {
        for (int index = 0; index < types.Length; index++)
        {
            BidiType type = types[index];
            if ((levels[index] & 1) == 0)
            {
                if (type == BidiType.R)
                {
                    levels[index]++;
                }
                else if (type is BidiType.AN or BidiType.EN)
                {
                    levels[index] += 2;
                }
            }
            else if (type is BidiType.L or BidiType.AN or BidiType.EN)
            {
                levels[index]++;
            }
        }
    }

    private static BidiType ClassifyCodePoint(int codePoint)
    {
        if ((uint)codePoint <= byte.MaxValue)
        {
            return BidiData.Latin1BidiTypes[codePoint];
        }

        int low = 0;
        int high = BidiData.NonLatin1BidiRanges.Length - 1;
        while (low <= high)
        {
            int middle = low + ((high - low) / 2);
            BidiRange range = BidiData.NonLatin1BidiRanges[middle];
            if (codePoint < range.Start)
            {
                high = middle - 1;
            }
            else if (codePoint > range.End)
            {
                low = middle + 1;
            }
            else
            {
                return range.Type;
            }
        }

        return BidiType.L;
    }

    private static void ValidateSegmentStarts(string normalized, int[] segmentStarts)
    {
        int previous = -1;
        for (int index = 0; index < segmentStarts.Length; index++)
        {
            int start = segmentStarts[index];
            if (start < 0 || start >= normalized.Length)
            {
                throw new ArgumentOutOfRangeException(nameof(segmentStarts), start, "Segment start must index normalized UTF-16 text.");
            }

            if (start <= previous)
            {
                throw new ArgumentException("Segment starts must be strictly increasing.", nameof(segmentStarts));
            }

            if (start > 0 && char.IsLowSurrogate(normalized[start]) && char.IsHighSurrogate(normalized[start - 1]))
            {
                throw new ArgumentException("Segment start cannot split a surrogate pair.", nameof(segmentStarts));
            }

            previous = start;
        }
    }
}
