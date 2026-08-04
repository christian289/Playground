namespace Pretext.Wpf;

/// <summary>
/// Opaque prepared handle produced by <see cref="RichInlineLayoutEngine.Prepare(IReadOnlyList{RichInlineItem})"/>.
/// Bundles the boundary-collapsed, whole-item-measured rich-inline items so repeated
/// layout walks at varying widths pay no re-measurement cost. Mirrors upstream's
/// branded <c>PreparedRichInline</c> handle from <c>rich-inline.ts</c>.
/// </summary>
public sealed class PreparedRichInline
{
    internal PreparedRichInline(
        IReadOnlyList<PreparedRichInlineItem> items,
        IReadOnlyList<PreparedRichInlineItem?> itemsBySourceItemIndex)
    {
        Items = items;
        ItemsBySourceItemIndex = itemsBySourceItemIndex;
    }

    /// <summary>Items surviving boundary-whitespace collapse, in flow order.</summary>
    internal IReadOnlyList<PreparedRichInlineItem> Items { get; }

    /// <summary>
    /// Parallel to the original <see cref="RichInlineItem"/> array passed to
    /// <see cref="RichInlineLayoutEngine.Prepare(IReadOnlyList{RichInlineItem})"/>;
    /// null where an item collapsed away entirely (pure boundary whitespace).
    /// </summary>
    internal IReadOnlyList<PreparedRichInlineItem?> ItemsBySourceItemIndex { get; }
}
