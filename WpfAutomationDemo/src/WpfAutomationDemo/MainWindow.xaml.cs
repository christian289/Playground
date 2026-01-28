using WpfAutomationDemo.Controls;

namespace WpfAutomationDemo;

public sealed partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
    }

    private void ProductRating_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
    {
        if (RatingDisplay is not null)
        {
            RatingDisplay.Text = $"현재 평점: {e.NewValue} / 5";
        }
    }

    private void ServiceRating_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
    {
        if (ServiceRatingDisplay is not null)
        {
            ServiceRatingDisplay.Text = $"서비스 평점: {e.NewValue} / 5";
        }
    }
}
