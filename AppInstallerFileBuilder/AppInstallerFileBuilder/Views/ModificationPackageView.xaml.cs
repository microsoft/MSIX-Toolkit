using AppInstallerFileBuilder.Model;
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
    /// An empty page that can be used on its own or navigated to within a Frame.
    /// </summary>
    public sealed partial class ModificationPackagesView : Page, INotifyPropertyChanged
    {

        private ToggleSwitch _modificationPackagesSwitch;
        private RelativePanel _packageListView;
        private ListView _listView;
        private TextBlock _addNewPackageTextBlock;

        public ObservableCollection<ModificationPackage> ModificationPackages { get; private set; } = new ObservableCollection<ModificationPackage>();

        private bool _isModificationPackages;
        public bool IsModificationPackages
        {
            get
            {
                return this._isModificationPackages;
            }

            set
            {
                if (value != this._isModificationPackages)
                {
                    this._isModificationPackages = value;
                    NotifyPropertyChanged("IsModificationPackages");

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
        public ModificationPackagesView()
        {
            this.InitializeComponent();
            this.DataContext = this;
            this.NavigationCacheMode = NavigationCacheMode.Required;
            _modificationPackagesSwitch = (ToggleSwitch)this.FindName("Modification_Packages_Switch");
            _packageListView = (RelativePanel)this.FindName("Package_Relative_Panel");
            _listView = (ListView)this.FindName("List_View");
            _addNewPackageTextBlock = (TextBlock)this.FindName("Add_New_Package_Text_Block");
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
        }

        private void _save()
        {
            App.ModificationPackages = ModificationPackages;

            App.IsModificationPackages = _isModificationPackages;
        }

        private void Next_Button_Click(object sender, RoutedEventArgs e)
        {
            AppShell.Current.AppFrame.Navigate(AppShell.Current.navlist2[3].DestPage);
        }

        private void Back_Button_Click(object sender, RoutedEventArgs e)
        {
            AppShell.Current.AppFrame.Navigate(AppShell.Current.navlist2[1].DestPage);
        }
        private void Review_Button_Click(object sender, RoutedEventArgs e)
        {
            AppShell.Current.AppFrame.Navigate(AppShell.Current.navlist3[0].DestPage);
        }

        private void ToggleSwitch_Toggled(object sender, RoutedEventArgs e)
        {
            _reloadViews();
            _save();
        }

        private void Add_New_Package_Tapped(object sender, TappedRoutedEventArgs e)
        {
            ModificationPackages.Add(new ModificationPackage());
            _save();
        }

    }
}