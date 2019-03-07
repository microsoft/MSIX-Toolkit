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

// The Blank Page item template is documented at https://go.microsoft.com/fwlink/?LinkId=234238

namespace AppInstallerFileBuilder.Views
{
	/// <summary>
	/// An empty page that can be used on its own or navigated to within a Frame.
	/// </summary>
	public sealed partial class AppInstallerView : Page
	{
        //AppInstallerController _controller;
        private TextBox _filePathTextBox;
        private TextBox _versionNumberTextBox;
        private String _filePath;
        private String _versionNumber;

        /***************************************************************************
         * 
         * Constructor
         *
         ***************************************************************************/
        public AppInstallerView()
        {
            this.InitializeComponent();
            
            _filePathTextBox = (TextBox)this.FindName("File_Path_Text_Box");
            _versionNumberTextBox = (TextBox)this.FindName("Version_Number_Text_Box");
        }
        

        /***************************************************************************
         * 
         * Lifecycle Methods
         *
         ***************************************************************************/

        protected override void OnNavigatedTo(NavigationEventArgs e)
        {
            _filePath = AppInstallerFileBuilder.App.AppInstallerFilePath;
            _versionNumber = AppInstallerFileBuilder.App.AppInstallerVersionNumber;
            _filePathTextBox.Text = _filePath;
            _versionNumberTextBox.Text = _versionNumber;
            base.OnNavigatedTo(e);
            
        }

        protected override void OnNavigatedFrom(NavigationEventArgs e)
        {
            _save(); 
            base.OnNavigatedFrom(e);
        }

        public String getFilePathName()
        {
            return _filePath;
        }

        public String getVersionNumber()
        {
            return _versionNumber;
        }

        /***************************************************************************
         * 
         * Private Methods
         *
         ***************************************************************************/

        private void _save()
        {
            AppInstallerFileBuilder.App.AppInstallerFilePath = _filePath;
            AppInstallerFileBuilder.App.AppInstallerVersionNumber = _versionNumber;
        }

        private void File_Path_Text_Box_TextChanged(object sender, TextChangedEventArgs e)
        {
            _filePath = _filePathTextBox.Text;
            _save();
        }
        private void Version_Text_Box_TextChanged(object sender, TextChangedEventArgs e)
        {
            _versionNumber = _versionNumberTextBox.Text;
            _save();
        }

        private void Next_Button_Click(object sender, RoutedEventArgs e)
        {
            AppShell.Current.AppFrame.Navigate(AppShell.Current.navlist[1].DestPage);
        }
    }
}
