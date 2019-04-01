using System;
using Windows.UI.Xaml;
using Windows.UI.Xaml.Controls;
using Windows.UI.Xaml.Controls.Primitives;
using Windows.UI.Xaml.Data;
using Windows.UI.Xaml.Input;
using Windows.UI.Xaml.Media;
using Windows.UI.Xaml.Navigation;
using System.Diagnostics;
using System.ComponentModel;
using System.Collections.ObjectModel;
using AppInstallerFileBuilder.Model;
using Microsoft.Packaging.SDKUtils.AppxPackaging;
using Windows.Storage;
using Windows.Storage.Pickers;
using Windows.Storage.Streams;

// The Blank Page item template is documented at https://go.microsoft.com/fwlink/?LinkId=234238

namespace AppInstallerFileBuilder.Views
{
	/// <summary>
	/// An empty page that can be used on its own or navigated to within a Frame.
	/// </summary>
	public sealed partial class DependenciesView : Page
    {

        private RelativePanel _packageListView;
        private ListView _listView;
        private TextBlock _addNewPackageTextBlock;
        private TextBlock _removePackageTextBlock;

        private Dependency _dependencyPackage;

        public ObservableCollection<Dependency> Dependencies { get; private set; } = new ObservableCollection<Dependency>();

        private bool _isDependencies;


        /***************************************************************************
        * 
        * Constructor
        *
        ***************************************************************************/
        public DependenciesView()
        {
            this.InitializeComponent();
            this._isDependencies = true;
            this.DataContext = this;
            this.NavigationCacheMode = NavigationCacheMode.Required;
            
            _packageListView = (RelativePanel)this.FindName("Package_Relative_Panel");
            _listView = (ListView)this.FindName("List_View");
            _addNewPackageTextBlock = (TextBlock)this.FindName("Add_New_Package_Text_Block");
            _removePackageTextBlock = (TextBlock)this.FindName("Remove_Package_Text_Block");
        }

        /***************************************************************************
        * 
        * Lifecycle Methods
        *
        ***************************************************************************/

        protected override void OnNavigatedTo(NavigationEventArgs e)
        {
            Dependencies = App.Dependencies;

            _reloadViews();
            base.OnNavigatedTo(e);
        }

        protected override void OnNavigatedFrom(NavigationEventArgs e)
        {
            _save();
            base.OnNavigatedFrom(e);
        }


        /***************************************************************************
        * 
        * Private Methods
        *
        ***************************************************************************/

        private async void PackageInfoButton_Click(object sender, RoutedEventArgs e)
        {
            FileOpenPicker openPicker = new FileOpenPicker
            {
                ViewMode = PickerViewMode.Thumbnail,
                SuggestedStartLocation = PickerLocationId.Desktop
            };
            openPicker.FileTypeFilter.Add(".msix");
            openPicker.FileTypeFilter.Add(".msixbundle");
            openPicker.FileTypeFilter.Add(".appx");
            openPicker.FileTypeFilter.Add(".appxbundle");
            StorageFile file = await openPicker.PickSingleFileAsync();
            if (file != null && (file.FileType.Equals(".msix", StringComparison.OrdinalIgnoreCase) || file.FileType.Equals(".appx", StringComparison.OrdinalIgnoreCase)))
            {
                // Application now has read/write access to the picked file

                IRandomAccessStream randomAccessStream = await file.OpenReadAsync();
                AppxMetadata appPackage = new AppxMetadata(randomAccessStream);

                _dependencyPackage.FilePath = file.Path;
                _dependencyPackage.Name = appPackage.PackageName;
                _dependencyPackage.Publisher = appPackage.Publisher;
                _dependencyPackage.Version = appPackage.Version.ToString();
                _dependencyPackage.ProcessorArchitecture = appPackage.Architecture;
                _dependencyPackage.FullUriPath = file.Path;

                _dependencyPackage.PackageType = PackageType.MSIX;

            }
            else if (file != null && (file.FileType.Equals(".msixbundle", StringComparison.OrdinalIgnoreCase) || file.FileType.Equals(".appxbundle", StringComparison.OrdinalIgnoreCase)))
            {
                IRandomAccessStream randomAccessStream = await file.OpenReadAsync();
                AppxBundleMetadata appBundle = new AppxBundleMetadata(randomAccessStream);


                _dependencyPackage.FilePath = file.Path;
                _dependencyPackage.Name = appBundle.PackageName;
                _dependencyPackage.Publisher = appBundle.Publisher;
                _dependencyPackage.Version = appBundle.Version.ToString();
                _dependencyPackage.FullUriPath = file.Path;

                _dependencyPackage.PackageType = PackageType.MSIXBUNDLE;
            }

            _reloadViews();
            _save();
        }

        private void _reloadViews()
        {
            if (!_isDependencies)
            {
                _packageListView.Visibility = Visibility.Collapsed;
            }
            else
            {
                _packageListView.Visibility = Visibility.Visible;
            }

            if (Dependencies.Count > 0)
            {
                _removePackageTextBlock.Visibility = Visibility.Visible;
            }
            else
            {
                _removePackageTextBlock.Visibility = Visibility.Collapsed;
            }
        }

        private void _save()
        {
            App.Dependencies = Dependencies;

            App.IsDependencies = _isDependencies;
        }

        private void Next_Button_Click(object sender, RoutedEventArgs e)
        {
            AppShell.Current.AppFrame.Navigate(AppShell.Current.navlist3[0].DestPage);
        }

        private void Back_Button_Click(object sender, RoutedEventArgs e)
        {
            AppShell.Current.AppFrame.Navigate(AppShell.Current.navlist2[2].DestPage);
        }
        private void Review_Button_Click(object sender, RoutedEventArgs e)
        {
            AppShell.Current.AppFrame.Navigate(AppShell.Current.navlist3[0].DestPage);
        }

        private void Add_New_Package_Tapped(object sender, TappedRoutedEventArgs e)
        {
            _dependencyPackage = new Dependency();
            Dependencies.Add(_dependencyPackage);

            _save();
            _reloadViews();

        }
        private void Remove_Package_Text_Block_Tapped(object sender, TappedRoutedEventArgs e)
        {
            Dependencies.RemoveAt(Dependencies.Count - 1);
            _reloadViews();
            _save();
        }


    }
}