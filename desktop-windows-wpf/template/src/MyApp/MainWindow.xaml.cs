using System.Windows;
using MyApp.Features.Example;

namespace MyApp;

public partial class MainWindow : Window
{
    public MainWindow(ExampleViewModel viewModel)
    {
        InitializeComponent();
        DataContext = viewModel;
    }
}
