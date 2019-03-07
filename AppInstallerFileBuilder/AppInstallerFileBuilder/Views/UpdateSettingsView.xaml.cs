using System;
using System.Diagnostics;
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
using System.ComponentModel;

// The Blank Page item template is documented at https://go.microsoft.com/fwlink/?LinkId=234238

namespace AppInstallerFileBuilder.Views
{
	/// <summary>
	/// An empty page that can be used on its own or navigated to within a Frame.
	/// </summary>
	public sealed partial class UpdateSettingsView : Page, INotifyPropertyChanged
	{
        private ComboBox _updateFrequencyComboBox;
        private TextBlock _updateFrequencyTextBox;
        private ToggleSwitch _checkUpdatesSwitch;

        private int _hoursBetweenUpdates;
        private bool _isCheckUpdates;
        public bool IsCheckUpdates
        {
            get
            {
                return this._isCheckUpdates;
            }

            set
            {
                if (value != this._isCheckUpdates)
                {
                    this._isCheckUpdates = value;
                    NotifyPropertyChanged("IsCheckUpdates");
                }
            }

        }

        public event PropertyChangedEventHandler PropertyChanged;
        private void NotifyPropertyChanged(string v)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(v));
        }


        /***************************************************************************
       * 
       * Constructor
       *
       ***************************************************************************/

        public UpdateSettingsView()
		{
			this.InitializeComponent();
            this.DataContext = this;
            this.NavigationCacheMode = NavigationCacheMode.Required;
            _checkUpdatesSwitch = (ToggleSwitch)this.FindName("Check_For_Updates_Switch");
            _updateFrequencyComboBox = (ComboBox)this.FindName("Update_Frequency_Combo_Box");
            _updateFrequencyTextBox = (TextBlock)this.FindName("Update_Frequency_Text_Block");

            for (int i = 0; i <= 255; i++)
            {
                _updateFrequencyComboBox.Items.Add(i);
            }
        }

        /***************************************************************************
        * 
        * Lifecycle Methods
        *
        ***************************************************************************/

        protected override void OnNavigatedTo(NavigationEventArgs e)
        {
            _isCheckUpdates = App.IsCheckUpdates;
            _updateFrequencyComboBox.SelectedIndex = App.HoursBetweenUpdates;
            _hoursBetweenUpdates = App.HoursBetweenUpdates;

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
            if (!_isCheckUpdates)
            {
                _updateFrequencyComboBox.Visibility = Visibility.Collapsed;
                _updateFrequencyTextBox.Visibility = Visibility.Collapsed;
            }
            else
            {
                _updateFrequencyComboBox.Visibility = Visibility.Visible;
                _updateFrequencyTextBox.Visibility = Visibility.Visible;
            }
        }

        private void _save()
        {
            App.IsCheckUpdates = _isCheckUpdates;
            App.HoursBetweenUpdates = _hoursBetweenUpdates;
        }

        private void Next_Button_Click(object sender, RoutedEventArgs e)
        {
            AppShell.Current.AppFrame.Navigate(AppShell.Current.navlist2[0].DestPage);
        }

        private void Back_Button_Click(object sender, RoutedEventArgs e)
        {
            AppShell.Current.AppFrame.Navigate(AppShell.Current.navlist[1].DestPage);
        }

        private void ToggleSwitch_Toggled(object sender, RoutedEventArgs e)
        {
            _reloadViews();
            _save();
        }

        private void ComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            _hoursBetweenUpdates = _updateFrequencyComboBox.SelectedIndex;
            _save();
        }
    }
}
