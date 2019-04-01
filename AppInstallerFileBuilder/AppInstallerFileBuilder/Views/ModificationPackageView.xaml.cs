using AppInstallerFileBuilder.Model;
using Microsoft.Packaging.SDKUtils.AppxPackaging;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using Windows.UI.Xaml;
using Windows.UI.Xaml.Controls;
using Windows.UI.Xaml.Input;
using Windows.UI.Xaml.Media;
using Windows.UI.Xaml.Navigation;
using Windows.Storage;
using Windows.Storage.Pickers;
using Windows.Storage.Streams;

// The Blank Page item template is documented at https://go.microsoft.com/fwlink/?LinkId=234238

namespace AppInstallerFileBuilder.Views
{
    /// <summary>
    /// An empty page that can be used on its own or navigated to within a Frame.
    /// </summary>
    public sealed partial class ModificationPackagesView : Page
    {

        private RelativePanel _packageListView;
        private ListView _listView;
        private TextBlock _addNewPackageTextBlock;
        private TextBlock _removePackageTextBlock;

        private ModificationPackage _modificationPackage;

        public ObservableCollection<ModificationPackage> ModificationPackages { get; private set; } = new ObservableCollection<ModificationPackage>();

        private bool _isModificationPackages;




        /***************************************************************************
        * 
        * Constructor
        *
        ***************************************************************************/
        public ModificationPackagesView()
        {
            this.InitializeComponent();
            this._isModificationPackages = true;
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
            ModificationPackages = App.ModificationPackages;

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

                //_filePathTextBox.Text = file.Path;
                _modificationPackage.FilePath = file.Path;

                //_nameTextBox.Text = appPackage.PackageName;
                _modificationPackage.Name = appPackage.PackageName;

                //_publisherTextBox.Text = appPackage.Publisher;
                _modificationPackage.Publisher = appPackage.Publisher;

                //_versionTextBox.Text = appPackage.Version.ToString();
                _modificationPackage.Version = appPackage.Version.ToString();

                //_resourceIdTextBox.Text = appPackage.ResourceId;
                //_mainPackage.ResourceId = appPackage.ResourceId;

                //_processorArchTextBox.Text = appPackage.Architecture;
                _modificationPackage.ProcessorArchitecture = appPackage.Architecture;

                //_uriPathTextBox.Text = file.Path;
                _modificationPackage.FullUriPath = file.Path;

                _modificationPackage.PackageType = PackageType.MSIX;

            }
            else if (file != null && (file.FileType.Equals(".msixbundle", StringComparison.OrdinalIgnoreCase) || file.FileType.Equals(".appxbundle", StringComparison.OrdinalIgnoreCase)))
            {
                IRandomAccessStream randomAccessStream = await file.OpenReadAsync();
                AppxBundleMetadata appBundle = new AppxBundleMetadata(randomAccessStream);

                //_filePathTextBox.Text = file.Path;
                _modificationPackage.FilePath = file.Path;

                //_nameTextBox.Text = appBundle.PackageName;
                _modificationPackage.Name = appBundle.PackageName;

                //_publisherTextBox.Text = appBundle.Publisher;
                _modificationPackage.Publisher = appBundle.Publisher;

                //_versionTextBox.Text = appBundle.Version.ToString();
                _modificationPackage.Version = appBundle.Version.ToString();

                //_uriPathTextBox.Text = file.Path;
                _modificationPackage.FullUriPath = file.Path;

                _modificationPackage.PackageType = PackageType.MSIXBUNDLE;
            }


            _reloadViews();
            _save();
        }
        private void _reloadViews()
        {
            if (!_isModificationPackages)
            {
                _packageListView.Visibility = Visibility.Collapsed;
            }
            else
            {
                _packageListView.Visibility = Visibility.Visible;
            }

            if (ModificationPackages.Count > 0)
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
            App.ModificationPackages = ModificationPackages;
            App.IsModificationPackages = _isModificationPackages;
        }

        private void Next_Button_Click(object sender, RoutedEventArgs e)
        {
            AppShell.Current.AppFrame.Navigate(AppShell.Current.navlist2[2].DestPage);
        }

        private void Back_Button_Click(object sender, RoutedEventArgs e)
        {
            AppShell.Current.AppFrame.Navigate(AppShell.Current.navlist2[1].DestPage);
        }
        private void Review_Button_Click(object sender, RoutedEventArgs e)
        {
            AppShell.Current.AppFrame.Navigate(AppShell.Current.navlist3[0].DestPage);
        }

        private void Add_New_Package_Tapped(object sender, TappedRoutedEventArgs e)
        {
            _modificationPackage = new ModificationPackage();
            ModificationPackages.Add(_modificationPackage);

            _save();
            _reloadViews();

        }
        private void Remove_Package_Text_Block_Tapped(object sender, TappedRoutedEventArgs e)
        {
            ModificationPackages.RemoveAt(ModificationPackages.Count - 1);
            _reloadViews();
            _save();
        }

    }
}