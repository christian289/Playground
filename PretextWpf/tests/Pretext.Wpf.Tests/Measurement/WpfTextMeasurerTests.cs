using System.Globalization;
using System.Runtime.ExceptionServices;
using System.Threading;
using System.Windows;
using System.Windows.Media;
using Pretext.Wpf;

namespace Pretext.Wpf.Tests.Measurement;

public sealed class WpfTextMeasurerTests
{
    private static readonly string[] SampleSegments = ["hello", " ", "你", "ภาษาไทย"];

    [Fact]
    [Trait("Category", "Happy")]
    public void Measure_SegmentsOnSta_ReturnsFiniteAdvances()
    {
        StaThread.Run(() =>
        {
            WpfTextMeasurer measurer = WpfTextMeasurer.GetOrCreate(CreateStyle());

            foreach (string segment in SampleSegments)
            {
                double width = measurer.MeasureSegment(segment);
                Assert.True(double.IsFinite(width), $"'{segment}' produced a non-finite width: {width}.");
                Assert.True(width > 0, $"'{segment}' produced a non-positive width: {width}.");
            }
        });
    }

    [Fact]
    [Trait("Category", "Boundary")]
    public void Measure_StyledBoundaries_PreservesWidths()
    {
        StaThread.Run(() =>
        {
            WpfTextMeasurer smallMeasurer = WpfTextMeasurer.GetOrCreate(CreateStyle(fontSize: 12));
            WpfTextMeasurer largeMeasurer = WpfTextMeasurer.GetOrCreate(CreateStyle(fontSize: 48));

            Assert.NotSame(smallMeasurer, largeMeasurer);

            double smallWidth = smallMeasurer.MeasureSegment("Sample");
            double largeWidth = largeMeasurer.MeasureSegment("Sample");
            Assert.True(largeWidth > smallWidth, $"expected larger font to widen 'Sample': small={smallWidth}, large={largeWidth}.");

            WpfTextMeasurer smallMeasurerAgain = WpfTextMeasurer.GetOrCreate(CreateStyle(fontSize: 12));
            Assert.Same(smallMeasurer, smallMeasurerAgain);
        });
    }

    [Fact]
    [Trait("Category", "Happy")]
    public void Measure_RepeatedRequest_UsesCache()
    {
        StaThread.Run(() =>
        {
            WpfTextMeasurer measurer = WpfTextMeasurer.GetOrCreate(CreateStyle());

            double first = measurer.MeasureSegment("cache me");
            double second = measurer.MeasureSegment("cache me");

            Assert.Equal(BitConverter.DoubleToInt64Bits(first), BitConverter.DoubleToInt64Bits(second));

            WpfTextMeasurer sameMeasurer = WpfTextMeasurer.GetOrCreate(CreateStyle());
            Assert.Same(measurer, sameMeasurer);
        });
    }

    [Fact]
    [Trait("Category", "Error")]
    public void Measure_NonStaThread_Throws()
    {
        WpfTextMeasurer measurer = WpfTextMeasurer.GetOrCreate(CreateStyle());

        Assert.Throws<InvalidOperationException>(() => MtaThread.Run(() => measurer.MeasureSegment("mta")));
    }

    private static TextStyle CreateStyle(
        FontFamily? fontFamily = null,
        double fontSize = 16,
        CultureInfo? culture = null,
        FlowDirection flowDirection = FlowDirection.LeftToRight,
        double pixelsPerDip = 1,
        TextFormattingMode formattingMode = TextFormattingMode.Ideal)
    {
        return new TextStyle(
            fontFamily ?? new FontFamily("Segoe UI"),
            fontSize,
            FontWeights.Normal,
            FontStyles.Normal,
            FontStretches.Normal,
            culture ?? CultureInfo.GetCultureInfo("en-US"),
            flowDirection,
            pixelsPerDip,
            formattingMode);
    }

    /// <summary>
    /// Runs an action on a dedicated STA thread and rethrows any exception on the calling thread
    /// with its original stack trace preserved. WPF's text formatter is apartment-threaded, so
    /// real-measurement tests cannot run inline on the ambient xunit worker thread.
    /// </summary>
    private static class StaThread
    {
        internal static void Run(Action action)
        {
            ExceptionDispatchInfo? capturedException = null;
            Thread thread = new(() =>
            {
                try
                {
                    action();
                }
                catch (Exception exception)
                {
                    capturedException = ExceptionDispatchInfo.Capture(exception);
                }
            });
            thread.SetApartmentState(ApartmentState.STA);
            thread.Start();
            thread.Join();
            capturedException?.Throw();
        }
    }

    /// <summary>
    /// Mirrors <see cref="StaThread"/> but runs on an explicit MTA thread, used to exercise
    /// <see cref="WpfTextMeasurer"/>'s apartment-state guard from the wrong apartment.
    /// </summary>
    private static class MtaThread
    {
        internal static void Run(Action action)
        {
            ExceptionDispatchInfo? capturedException = null;
            Thread thread = new(() =>
            {
                try
                {
                    action();
                }
                catch (Exception exception)
                {
                    capturedException = ExceptionDispatchInfo.Capture(exception);
                }
            });
            thread.SetApartmentState(ApartmentState.MTA);
            thread.Start();
            thread.Join();
            capturedException?.Throw();
        }
    }
}
