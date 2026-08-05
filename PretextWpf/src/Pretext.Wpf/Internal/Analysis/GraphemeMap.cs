using System.Globalization;

namespace Pretext.Wpf;

internal sealed class GraphemeMap
{
    private readonly string text;

    public GraphemeMap(string text)
    {
        ArgumentNullException.ThrowIfNull(text);
        this.text = text;

        List<int> starts = new(text.Length);
        TextElementEnumerator enumerator = StringInfo.GetTextElementEnumerator(text);
        while (enumerator.MoveNext())
        {
            starts.Add(enumerator.ElementIndex);
        }

        Starts = starts.ToArray();
    }

    public int[] Starts { get; }

    public int Count => Starts.Length;

    public string GetTextElement(int index)
    {
        ArgumentOutOfRangeException.ThrowIfGreaterThanOrEqual(index, Count);
        ArgumentOutOfRangeException.ThrowIfNegative(index);

        int start = Starts[index];
        int end = index + 1 < Count ? Starts[index + 1] : text.Length;
        return text[start..end];
    }

    public string GetPrefixText(int graphemeCount)
    {
        if ((uint)graphemeCount > (uint)Count)
        {
            throw new ArgumentOutOfRangeException(nameof(graphemeCount));
        }

        int end = graphemeCount == Count ? text.Length : Starts[graphemeCount];
        return text[..end];
    }
}
