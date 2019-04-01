using AppInstallerFileBuilder.Model;
using Microsoft.Packaging.SDKUtils.AppxPackaging;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices.WindowsRuntime;
using Windows.Foundation;
using Windows.Foundation.Collections;
using Windows.Storage;
using Windows.Storage.Pickers;
using Windows.Storage.Streams;
using Windows.UI.Xaml;
using Windows.UI.Xaml.Controls;
using Windows.UI.Xaml.Controls.Primitives;
using Windows.UI.Xaml.Data;
using Windows.UI.Xaml.Input;
using Windows.UI.Xaml.Media;
using Windows.UI.Xaml.Navigation;

// The Blank Page item template is documented at https://go.microsoft.com/fwlink/?LinkId=234238

namespace AppInstallerFileBuilder.Views
{
	/// <summary>
	/// Optional package view 
	/// </summary>
	
    public sealed partial class OptionalPackagesView : Page
    {

        
        private RelativePanel _packageListView;
        private ListView _listView;
        private TextBlock _addNewPackageTextBlock;
        private TextBlock _removePackageTextBlock;

        private OptionalPackage _optionalPackage;

        public ObservableCollection<OptionalPackage> OptionalPackages { get; private set; } = new ObservableCollection<OptionalPackage>();

        private bool _isOptionalPackages;

        /***************************************************************************
        * 
        * Constructor
        *
        ***************************************************************************/
        public OptionalPackagesView()
		{
            this.InitializeComponent();
            this._isOptionalPackages = true;
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
            OptionalPackages = App.OptionalPackages;

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
                _optionalPackage.FilePath = file.Path;

                //_nameTextBox.Text = appPackage.PackageName;
                _optionalPackage.Name = appPackage.PackageName;

                //_publisherTextBox.Text = appPackage.Publisher;
                _optionalPackage.Publisher = appPackage.Publisher;

                //_versionTextBox.Text = appPackage.Version.ToString();
                _optionalPackage.Version = appPackage.Version.ToString();

                //_resourceIdTextBox.Text = appPackage.ResourceId;
                //_mainPackage.ResourceId = appPackage.ResourceId;

                //_processorArchTextBox.Text = appPackage.Architecture;
                _optionalPackage.ProcessorArchitecture = appPackage.Architecture;

                //_uriPathTextBox.Text = file.Path;
                _optionalPackage.FullUriPath = file.Path;

                _optionalPackage.PackageType = PackageType.MSIX;

            }
            else if (file != null && (file.FileType.Equals(".msixbundle", StringComparison.OrdinalIgnoreCase) || file.FileType.Equals(".appxbundle", StringComparison.OrdinalIgnoreCase)))
            {
                IRandomAccessStream randomAccessStream = await file.OpenReadAsync();
                AppxBundleMetadata appBundle = new AppxBundleMetadata(randomAccessStream);

                
                _optionalPackage.FilePath = file.Path;
                _optionalPackage.Name = appBundle.PackageName;
                _optionalPackage.Publisher = appBundle.Publisher;
                _optionalPackage.Version = appBundle.Version.ToString();
                _optionalPackage.FullUriPath = file.Path;
                _optionalPackage.PackageType = PackageType.MSIXBUNDLE;
            }

            
            _reloadViews();
            _save();
        }


        private void _reloadViews()
        {
            if (!_isOptionalPackages)
            {
                _packageListView.Visibility = Visibility.Collapsed;
            }
            else
            {
                _packageListView.Visibility = Visibility.Visible;
            }

            if (OptionalPackages.Count > 0)
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
            App.OptionalPackages = OptionalPackages;
            App.IsOptionalPackages = _isOptionalPackages;
        }

        private void Next_Button_Click(object sender, RoutedEventArgs e)
        {
            AppShell.Current.AppFrame.Navigate(AppShell.Current.navlist2[1].DestPage);
        }

        private void Back_Button_Click(object sender, RoutedEventArgs e)
        {
            AppShell.Current.AppFrame.Navigate(AppShell.Current.navlist[0].DestPage);
        }
        private void Review_Button_Click(object sender, RoutedEventArgs e)
        {
            AppShell.Current.AppFrame.Navigate(AppShell.Current.navlist3[0].DestPage);
        }

        private void Add_New_Package_Tapped(object sender, TappedRoutedEventArgs e)
        {
            _optionalPackage = new OptionalPackage();
            OptionalPackages.Add(_optionalPackage);
            
            _save();
            _reloadViews();

        }

        private void Remove_Package_Text_Block_Tapped(object sender, TappedRoutedEventArgs e)
        {
            OptionalPackages.RemoveAt(OptionalPackages.Count - 1);
            _reloadViews();
            _save();
        }
    }
}


