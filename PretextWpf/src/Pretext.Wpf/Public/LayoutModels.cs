namespace Pretext.Wpf;

public delegate void LineRangeVisitor(in LayoutLineRange line);

public readonly record struct LayoutCursor(int SegmentIndex, int GraphemeIndex);

public readonly record struct LayoutResult(int LineCount, double Height);

public readonly record struct LineStats(int LineCount, double MaxLineWidth);

public readonly record struct LayoutLineRange(
    double Width,
    LayoutCursor Start,
    LayoutCursor End);

public sealed record LayoutLine(
    string Text,
    double Width,
    LayoutCursor Start,
    LayoutCursor End);

public sealed record LayoutLinesResult(
    int LineCount,
    double Height,
    IReadOnlyList<LayoutLine> Lines);
