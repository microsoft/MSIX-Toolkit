using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices.WindowsRuntime;
using Windows.Foundation;
using Windows.Foundation.Collections;
using Windows.UI.Xaml;
using Windows.UI.Xaml.Controls;
using Windows.UI.Xaml.Controls.Primitives;
using Windows.UI.Xaml.Data;
using Windows.UI.Xaml.Input;
using Windows.UI.Xaml.Media;
using Windows.UI.Xaml.Navigation;
using System.Diagnostics;
using AppInstallerFileBuilder.Model;
using Windows.Storage.Pickers;
using Windows.Storage;
using System.Runtime.InteropServices.ComTypes;
using Microsoft.Packaging.SDKUtils.AppxPackagingInterop;
using Microsoft.Packaging.SDKUtils;
using Windows.Storage.Streams;
using Microsoft.Packaging.SDKUtils.AppxPackaging;
using System.ComponentModel;

// The Blank Page item template is documented at https://go.microsoft.com/fwlink/?LinkId=234238

namespace AppInstallerFileBuilder.Views
{
	/// <summary>
	/// An empty page that can be used on its own or navigated to within a Frame.
	/// </summary>
	public sealed partial class MainPackageView : Page
	{
        private TextBox _filePathTextBox;
        //private ComboBox _packageTypeComboBox;
        //private ComboBox _processorTypeComboBox;
        private TextBox _processorArchTextBox;
        private TextBox _versionTextBox;
        private TextBox _publisherTextBox;
        private TextBox _nameTextBox;
        private TextBox _resourceIdTextBox;
        private TextBox _uriPathTextBox;
        private StackPanel _resourceIdStackPanel;
        
        private MainPackage _mainPackage;

        private StackPanel _processorTypeStackPanel;
        private StackPanel _updateSettingsStackPanel;
        private ComboBox _compatComboBox;

        private TextBox _hoursBetweenUpdatesTextBox;
        private TextBlock _updateFrequencyTextBlock;
        private ToggleSwitch _checkUpdatesSwitch;
        private ToggleSwitch _showPromptSwitch;
        private ToggleSwitch _forceUpdateSwitch;
        private ToggleSwitch _blockUpdateSwitch;
        private ToggleSwitch _autoUpdateSwitch;

        private StackPanel _1709updateSettingsStackPanel;
        private StackPanel _1803updateSettingsStackPanel;
        private StackPanel _1809updateSettingsStackPanel;

        private int _hoursBetweenUpdates;
        
        /***************************************************************************
        * 
        * Constructor
        *
        ***************************************************************************/

        public MainPackageView()
		{
			this.InitializeComponent();

            _filePathTextBox = (TextBox)this.FindName("File_Path_Text_Box");
            //_packageTypeComboBox = (ComboBox)this.FindName("Package_Type_Combo_Box");
            _versionTextBox = (TextBox)this.FindName("Version_Text_Box");
            _publisherTextBox = (TextBox)this.FindName("Publisher_Text_Box");
            _nameTextBox = (TextBox)this.FindName("Name_Text_Box");
            _resourceIdTextBox = (TextBox)this.FindName("Resource_Id_Text_Box");
            //_processorTypeComboBox = (ComboBox)this.FindName("Processor_Type_Combo_Box");
            _processorArchTextBox = (TextBox)this.FindName("Processor_Arch_Text_Box");
            _uriPathTextBox = (TextBox)this.FindName("Uri_Path_Text_Box");
            _processorTypeStackPanel = (StackPanel)this.FindName("Processor_Type_Stack_Panel");
            _resourceIdStackPanel = (StackPanel)this.FindName("Resource_Id_Stack_Panel");

            PackageInfoButton.Click += new RoutedEventHandler(PackageInfoButton_Click);

            _updateSettingsStackPanel = (StackPanel)this.FindName("Update_Settings_Stack_Panel");
            _checkUpdatesSwitch = (ToggleSwitch)this.FindName("Check_For_Updates_Switch");
            _compatComboBox = (ComboBox)this.FindName("CompatComboBox");
            _hoursBetweenUpdatesTextBox = (TextBox)this.FindName("Hours_Between_Updates_Text_Box");
            _updateFrequencyTextBlock = (TextBlock)this.FindName("Update_Frequency_Text_Block");

            _showPromptSwitch = (ToggleSwitch)this.FindName("Show_Prompt_Switch");
            _forceUpdateSwitch = (ToggleSwitch)this.FindName("Force_Update_Switch");
            _blockUpdateSwitch = (ToggleSwitch)this.FindName("Block_Update_Switch");
            _autoUpdateSwitch = (ToggleSwitch)this.FindName("Auto_Update_Switch");

            _1709updateSettingsStackPanel = (StackPanel)this.FindName("One_Update_Settings_Stack_Panel");
            _1803updateSettingsStackPanel = (StackPanel)this.FindName("Two_Update_Settings_Stack_Panel");
            _1809updateSettingsStackPanel = (StackPanel)this.FindName("Three_Update_Settings_Stack_Panel");
            
        }

        /***************************************************************************
       * 
       * Lifecycle Methods
       *
       ***************************************************************************/

        private async void PackageInfoButton_Click(object sender, RoutedEventArgs e)
        {
            FileOpenPicker openPicker = new FileOpenPicker();
            openPicker.ViewMode = PickerViewMode.Thumbnail;
            openPicker.SuggestedStartLocation = PickerLocationId.PicturesLibrary;
            openPicker.FileTypeFilter.Add(".msix");
            openPicker.FileTypeFilter.Add(".msixbundle");
            openPicker.FileTypeFilter.Add(".appx");
            openPicker.FileTypeFilter.Add(".appxbundle");
            StorageFile file = await openPicker.PickSingleFileAsync();
            if (file != null && (file.FileType.Equals(".msix",StringComparison.OrdinalIgnoreCase) || file.FileType.Equals(".appx",StringComparison.OrdinalIgnoreCase)))
            {
                // Application now has read/write access to the picked file
                
                IRandomAccessStream randomAccessStream = await file.OpenReadAsync();
                AppxMetadata appPackage = new AppxMetadata(randomAccessStream);

                _filePathTextBox.Text = file.Path;
                _mainPackage.FilePath = file.Path;

                _nameTextBox.Text = appPackage.PackageName;
                _mainPackage.Name = appPackage.PackageName;

                _publisherTextBox.Text = appPackage.Publisher;
                _mainPackage.Publisher = appPackage.Publisher;

                _versionTextBox.Text = appPackage.Version.ToString();
                _mainPackage.Version = appPackage.Version.ToString();

                _resourceIdTextBox.Text = appPackage.ResourceId;
                _mainPackage.ResourceId = appPackage.ResourceId;

                _processorArchTextBox.Text = appPackage.Architecture;
                _mainPackage.ProcessorArchitecture = appPackage.Architecture;

                _uriPathTextBox.Text = file.Path;
                _mainPackage.FullUriPath = file.Path;

                _mainPackage.PackageType = PackageType.MSIX;

            }
            else if(file != null && (file.FileType.Equals(".msixbundle", StringComparison.OrdinalIgnoreCase) || file.FileType.Equals(".appxbundle", StringComparison.OrdinalIgnoreCase)))
            {
                IRandomAccessStream randomAccessStream = await file.OpenReadAsync();
                AppxBundleMetadata appBundle = new AppxBundleMetadata(randomAccessStream);

                _filePathTextBox.Text = file.Path;
                _mainPackage.FilePath = file.Path;

                _nameTextBox.Text = appBundle.PackageName;
                _mainPackage.Name = appBundle.PackageName;

                _publisherTextBox.Text = appBundle.Publisher;
                _mainPackage.Publisher = appBundle.Publisher;

                _versionTextBox.Text = appBundle.Version.ToString();
                _mainPackage.Version = appBundle.Version.ToString();

                _uriPathTextBox.Text = file.Path;
                _mainPackage.FullUriPath = file.Path;

                _mainPackage.PackageType = PackageType.MSIXBUNDLE;
            }

            _reloadViews();
            _save();
        }


        protected override void OnNavigatedTo(NavigationEventArgs e)
        {
            _mainPackage = App.MainPackage;

            _versionTextBox.Text = _mainPackage.Version;
            _publisherTextBox.Text = _mainPackage.Publisher;
            _nameTextBox.Text = _mainPackage.Name;
            _resourceIdTextBox.Text = _mainPackage.ResourceId; 
            _filePathTextBox.Text = _mainPackage.FilePath;
            //_processorTypeComboBox.SelectedValue = _mainPackage.ProcessorArchitecture;
            _processorArchTextBox.Text = _mainPackage.ProcessorArchitecture;
            //_packageTypeComboBox.SelectedValue = _mainPackage.PackageType;

            _hoursBetweenUpdates = App.HoursBetweenUpdates;
            _hoursBetweenUpdatesTextBox.Text = _hoursBetweenUpdates.ToString();
            _save();
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
        private void _reloadViews()
        {
            if (_mainPackage.PackageType == PackageType.MSIX)
            {
                _processorTypeStackPanel.Visibility = Visibility.Visible;
                _resourceIdStackPanel.Visibility = Visibility.Visible;
            }
            else
            {
                _processorTypeStackPanel.Visibility = Visibility.Collapsed;
                _resourceIdStackPanel.Visibility = Visibility.Collapsed;
                _mainPackage.ProcessorArchitecture = ""; 
            }
            //Debug.WriteLine("isCheckUpdates is " + App.IsCheckUpdates + " - " + _checkUpdatesSwitch.IsOn);
            if (!App.IsCheckUpdates)
            {
                _checkUpdatesSwitch.IsOn = false;
                _updateSettingsStackPanel.Visibility = Visibility.Collapsed;
            }
            else
            {
                _checkUpdatesSwitch.IsOn = true;
                _updateSettingsStackPanel.Visibility = Visibility.Visible;
            }
        }

        private void _save()
        {
            App.MainPackage = _mainPackage;
            
            if(_hoursBetweenUpdatesTextBox.Text.Length > 0)
                _hoursBetweenUpdates = Convert.ToInt32(_hoursBetweenUpdatesTextBox.Text);
            App.HoursBetweenUpdates = _hoursBetweenUpdates;

            if(_mainPackage.PackageType.Equals(PackageType.MSIX))
            {
                if((_nameTextBox.Text.Length > 0) &&
                    (_publisherTextBox.Text.Length > 0) &&
                    (_versionTextBox.Text.Length > 0) &&
                    (_processorArchTextBox.Text.Length > 0) &&
                    (_uriPathTextBox.Text.Length > 0) )
                {
                    Next_Button.IsEnabled = true;
                    Review_Button.IsEnabled = true;
                }
            }
            else if (_mainPackage.PackageType.Equals(PackageType.MSIXBUNDLE))
            {
                if ((_nameTextBox.Text.Length > 0) &&
                   (_publisherTextBox.Text.Length > 0) &&
                   (_versionTextBox.Text.Length > 0) &&
                   (_uriPathTextBox.Text.Length > 0))
                {
                    Next_Button.IsEnabled = true;
                    Review_Button.IsEnabled = true;
                }
            }
        }

        private void Next_Button_Click(object sender, RoutedEventArgs e)
        {
            AppShell.Current.AppFrame.Navigate(AppShell.Current.navlist2[0].DestPage);
        }

        private void Back_Button_Click(object sender, RoutedEventArgs e)
        {
            //AppShell.Current.AppFrame.Navigate(AppShell.Current.navlist[0].DestPage);
        }

        private void Review_Button_Click(object sender, RoutedEventArgs e)
        {
            AppShell.Current.AppFrame.Navigate(AppShell.Current.navlist3[0].DestPage);
        }

        //private void Package_Type_Combo_Box_SelectionChanged(object sender, SelectionChangedEventArgs e)
        //{
        //    _save();
        //    _reloadViews();
        //}

        //private void Processor_Type_Combo_Box_SelectionChanged(object sender, SelectionChangedEventArgs e)
        //{
        //    _save();
        //    _reloadViews();
        //}

        public IList<String> Schemas
        {
            get
            {
                // Will result in a list like {"Win10Ver1709", Win10Ver1803, "Win10Ver1809"}
                List<String> lStrings = new List<string>
                {
                    "Windows 10 Version 1809 or later",
                    "Windows 10 Version 1803 or later",
                    "Windows 10 Version 1709 or later"
                };

                //return Enum.GetValues(typeof(Schema)).Cast<Schema>().ToList<Schema>();
                return lStrings;
            }
        }

        private void ToggleSwitch_Toggled(object sender, RoutedEventArgs e)
        {
            App.IsCheckUpdates = _checkUpdatesSwitch.IsOn;
            _reloadViews();
            _save();
        }
        private void CompatComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            switch (_compatComboBox.SelectedIndex)
            {
                case 0: //1809 and above
                    Debug.WriteLine("0");
                    _1809updateSettingsStackPanel.Visibility = Visibility.Visible;
                    _1803updateSettingsStackPanel.Visibility = Visibility.Visible;
                    _1709updateSettingsStackPanel.Visibility = Visibility.Visible;
                    App.AppInstallerFileSchemaNamespace = "http://schemas.microsoft.com/appx/appinstaller/2018";
                    break;
                case 1: //1803 and above
                    Debug.WriteLine("1");
                    _1809updateSettingsStackPanel.Visibility = Visibility.Collapsed;
                    _1803updateSettingsStackPanel.Visibility = Visibility.Visible;
                    _1709updateSettingsStackPanel.Visibility = Visibility.Visible;
                    _showPromptSwitch.IsOn = false;
                    _blockUpdateSwitch.IsOn = false;
                    App.AppInstallerFileSchemaNamespace = "http://schemas.microsoft.com/appx/appinstaller/2017/2";
                    break;
                case 2: //1709 and above
                    Debug.WriteLine("2");
                    _1809updateSettingsStackPanel.Visibility = Visibility.Collapsed;
                    _1803updateSettingsStackPanel.Visibility = Visibility.Collapsed;
                    _1709updateSettingsStackPanel.Visibility = Visibility.Visible;
                    _showPromptSwitch.IsOn = false;
                    _blockUpdateSwitch.IsOn = false;
                    _autoUpdateSwitch.IsOn = false;
                    _forceUpdateSwitch.IsOn = false;
                    App.AppInstallerFileSchemaNamespace = "http://schemas.microsoft.com/appx/appinstaller/2017";
                    break;
                default:
                    Debug.WriteLine("default");
                    break;
            }
        }

        private void Force_Update_Switch_Toggled(object sender, RoutedEventArgs e)
        {
            App.IsForceUpdate = _forceUpdateSwitch.IsOn;
            _reloadViews();
            _save();
        }

        private void Show_Prompt_Switch_Toggled(object sender, RoutedEventArgs e)
        {
            App.IsShowPrompt = _showPromptSwitch.IsOn;
            _reloadViews();
            _save();
        }

        private void Block_Update_Switch_Toggled(object sender, RoutedEventArgs e)
        {
            if (_blockUpdateSwitch.IsOn)
                _showPromptSwitch.IsOn = true;
            App.IsBlockUpdate = _blockUpdateSwitch.IsOn;
            _reloadViews();
            _save();
        }
        private void Auto_Update_Switch_Toggled(object sender, RoutedEventArgs e)
        {
            App.IsAutoUpdate = _autoUpdateSwitch.IsOn;
            _reloadViews();
            _save();

        }

    }
}
