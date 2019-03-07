using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using Windows.Foundation;
using Windows.UI.Xaml.Automation;
using Windows.UI.Core;
using Windows.UI.Xaml;
using Windows.UI.Xaml.Controls;
using Windows.UI.Xaml.Input;
using Windows.UI.Xaml.Navigation;
using AppInstallerFileBuilder.Controls;
using AppInstallerFileBuilder.Views;
using Windows.ApplicationModel.Core;
using Windows.UI.ViewManagement;


namespace AppInstallerFileBuilder
{
    /// <summary>
    /// The "chrome" layer of the app that provides top-level navigation with
    /// proper keyboarding navigation.
    /// </summary>
    public sealed partial class AppShell : Page
    {
        private bool isPaddingAdded = false;
        private TextBlock _appVersion;

        // Declare the top level nav items
        public List<NavMenuItem> navlist = new List<NavMenuItem>(
            new[]
            {
                //new NavMenuItem()
                //{
                //    Label = "AppInstaller File",
                //    DestPage = typeof(AppInstallerView)
                //}
                //,
				new NavMenuItem()
				{
					Label = "Main Package *",
					DestPage = typeof(MainPackageView)
				}
                //,
                //new NavMenuItem()
                //{
                //    Label = "Update Settings",
                //    DestPage = typeof(UpdateSettingsView)
                //}
                ,
            });

        public List<NavMenuItem> navlist2 = new List<NavMenuItem>(
            new[]
            {
                 new NavMenuItem()
                {
                    Label = "Optional Packages",
                    DestPage = typeof(OptionalPackagesView)
                },
                //new NavMenuItem()
                //{
                //    Label = "Related Packages",
                //    DestPage = typeof(RelatedPackagesView)
                //},
                // new NavMenuItem()
                //{
                //    Label = "Modification Packages",
                //    DestPage = typeof(ModificationPackagesView)
                //},
                //new NavMenuItem()
                //{
                //    Label = "Dependencies",
                //    DestPage = typeof(DependenciesView)
                //},
            });

        public List<NavMenuItem> navlist3 = new List<NavMenuItem>(
            new[]
            {
                new NavMenuItem()
                {
                    Label = "Summary",
                    DestPage = typeof(GenerateXMLView)
                },
            });

       
        public static AppShell Current = null;

        /// <summary>
        /// Initializes a new instance of the AppShell, sets the static 'Current' reference,
        /// adds callbacks for Back requests and changes in the SplitView's DisplayMode, and
        /// provide the nav menu list with the data to display.
        /// </summary>
        public AppShell()
        {
            this.InitializeComponent();
            _appVersion = (TextBlock)this.FindName("appVersion");

            this.Loaded += (sender, args) =>
            {
                Current = this;

                this.CheckTogglePaneButtonSizeChanged();

                var titleBar = CoreApplication.GetCurrentView().TitleBar;

                ApplicationViewTitleBar formattableTitleBar = ApplicationView.GetForCurrentView().TitleBar;
                formattableTitleBar.ButtonBackgroundColor = Windows.UI.Colors.Transparent;
                CoreApplicationViewTitleBar coreTitleBar = CoreApplication.GetCurrentView().TitleBar;
                coreTitleBar.ExtendViewIntoTitleBar = true;
                ApplicationView.PreferredLaunchViewSize = new Size(1000, 750);
                ApplicationView.PreferredLaunchWindowingMode = ApplicationViewWindowingMode.PreferredLaunchViewSize;

                titleBar.IsVisibleChanged += TitleBar_IsVisibleChanged;
            };

            this.RootSplitView.RegisterPropertyChangedCallback(
                SplitView.DisplayModeProperty,
                (s, a) =>
                {
                    // Ensure that we update the reported size of the TogglePaneButton when the SplitView's
                    // DisplayMode changes.
                    this.CheckTogglePaneButtonSizeChanged();
                });

            SystemNavigationManager.GetForCurrentView().AppViewBackButtonVisibility = AppViewBackButtonVisibility.Collapsed;
            
            
            NavMenuList.ItemsSource = navlist;
            NavMenuList2.ItemsSource = navlist2;
            NavMenuList3.ItemsSource = navlist3;

        }

        public Frame AppFrame { get { return this.frame; } }

        /// <summary>
        /// Invoked when window title bar visibility changes, such as after loading or in tablet mode
        /// Ensures correct padding at window top, between title bar and app content
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="args"></param>
        private void TitleBar_IsVisibleChanged(CoreApplicationViewTitleBar sender, object args)
        {
            
            if (!this.isPaddingAdded && sender.IsVisible)
            {
                //add extra padding between window title bar and app content
                double extraPadding = (Double)AppInstallerFileBuilder.App.Current.Resources["DesktopWindowTopPadding"];
                this.isPaddingAdded = true;

                Thickness margin = NavMenuList.Margin;
                NavMenuList.Margin = new Thickness(margin.Left, margin.Top + extraPadding, margin.Right, margin.Bottom);
                margin = AppFrame.Margin;
                AppFrame.Margin = new Thickness(margin.Left, margin.Top + extraPadding, margin.Right, margin.Bottom);
               // margin = TogglePaneButton.Margin;
               // TogglePaneButton.Margin = new Thickness(margin.Left, margin.Top + extraPadding, margin.Right, margin.Bottom);
            }
        }

        /// <summary>
        /// Default keyboard focus movement for any unhandled keyboarding
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void AppShell_KeyDown(object sender, KeyRoutedEventArgs e)
        {
            FocusNavigationDirection direction = FocusNavigationDirection.None;
            switch (e.Key)
            {
                case Windows.System.VirtualKey.Left:
                case Windows.System.VirtualKey.GamepadDPadLeft:
                case Windows.System.VirtualKey.GamepadLeftThumbstickLeft:
                case Windows.System.VirtualKey.NavigationLeft:
                    direction = FocusNavigationDirection.Left;
                    break;
                case Windows.System.VirtualKey.Right:
                case Windows.System.VirtualKey.GamepadDPadRight:
                case Windows.System.VirtualKey.GamepadLeftThumbstickRight:
                case Windows.System.VirtualKey.NavigationRight:
                    direction = FocusNavigationDirection.Right;
                    break;

                case Windows.System.VirtualKey.Up:
                case Windows.System.VirtualKey.GamepadDPadUp:
                case Windows.System.VirtualKey.GamepadLeftThumbstickUp:
                case Windows.System.VirtualKey.NavigationUp:
                    direction = FocusNavigationDirection.Up;
                    break;

                case Windows.System.VirtualKey.Down:
                case Windows.System.VirtualKey.GamepadDPadDown:
                case Windows.System.VirtualKey.GamepadLeftThumbstickDown:
                case Windows.System.VirtualKey.NavigationDown:
                    direction = FocusNavigationDirection.Down;
                    break;
            }

            if (direction != FocusNavigationDirection.None)
            {
                var control = FocusManager.FindNextFocusableElement(direction) as Control;
                if (control != null)
                {
                    control.Focus(FocusState.Keyboard);
                    e.Handled = true;
                }
            }
        }

        #region BackRequested Handlers

        private void SystemNavigationManager_BackRequested(object sender, BackRequestedEventArgs e)
        {
            bool handled = e.Handled;
            this.BackRequested(ref handled);
            e.Handled = handled;
        }

        private void BackRequested(ref bool handled)
        {
            // Get a hold of the current frame so that we can inspect the app back stack.

            if (this.AppFrame == null)
                return;

            // Check to see if this is the top-most page on the app back stack.
            if (this.AppFrame.CanGoBack && !handled)
            {
                // If not, set the event to handled and go back to the previous page in the app.
                handled = true;
                this.AppFrame.GoBack();
            }
        }

        #endregion

        #region Navigation

        /// <summary>
        /// Navigate to the Page for the selected <paramref name="listViewItem"/>.
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="listViewItem"></param>
        private void NavMenuList_ItemInvoked(object sender, ListViewItem listViewItem)
        {
            foreach (var i in navlist)
            {
                i.IsSelected = false;
            }
            foreach (var i in navlist2)
            {
                i.IsSelected = false;
            }
            foreach (var i in navlist3)
            {
                i.IsSelected = false;
            }

            var item = (NavMenuItem)((NavMenuListView)sender).ItemFromContainer(listViewItem);

            if (item != null)
            {
                item.IsSelected = true;
                if (item.DestPage != null &&
                    item.DestPage != this.AppFrame.CurrentSourcePageType)
                {
                    this.AppFrame.Navigate(item.DestPage, item.Arguments);
                }
            }
        }

        /// <summary>
        /// Ensures the nav menu reflects reality when navigation is triggered outside of
        /// the nav menu buttons.
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void OnNavigatingToPage(object sender, NavigatingCancelEventArgs e)
        {
            _appVersion.Text = string.Format("Version: {0}.{1}.{2}.{3}",
                                    Windows.ApplicationModel.Package.Current.Id.Version.Major,
                                    Windows.ApplicationModel.Package.Current.Id.Version.Minor,
                                    Windows.ApplicationModel.Package.Current.Id.Version.Build,
                                    Windows.ApplicationModel.Package.Current.Id.Version.Revision);
           if (e.NavigationMode == NavigationMode.New)
            {
                //Updates nav menu if invoked from back/next buttons.
                {
                    List<NavMenuItem> newList = new List<NavMenuItem>
                    {
                        navlist[0],
                        navlist2[0],
                        //navlist2[1],
                        //navlist2[2],
                        //navlist2[3],
                        navlist3[0]
                    };

                    var item = (from p in (newList) where p.DestPage == e.SourcePageType select p).SingleOrDefault();

                    //Set blue tab indicator for selected page
                    //foreach (var i in this.navlist)
                    //{
                    //    i.IsSelected = false;
                    //}
                    //foreach (var i in this.navlist2)
                    //{
                    //    i.IsSelected = false;
                    //}
                    //foreach (var i in this.navlist3)
                    //{
                    //    i.IsSelected = false;
                    //}
                    if (item != null)
                    {
                        item.IsSelected = true;
                    }

                    //Set the selected container.
                    var container = (ListViewItem)NavMenuList.ContainerFromItem(item); 
                    Debug.WriteLine("" + container);

                }
            }
        }

        #endregion

        public Rect TogglePaneButtonRect
        {
            get;
            private set;
        }

        /// <summary>
        /// An event to notify listeners when the hamburger button may occlude other content in the app.
        /// The custom "PageHeader" user control is using this.
        /// </summary>
        public event TypedEventHandler<AppShell, Rect> TogglePaneButtonRectChanged;

        /// <summary>
        /// Public method to allow pages to open SplitView's pane.
        /// Used for custom app shortcuts like navigating left from page's left-most item
        /// </summary>
        public void OpenNavePane()
        {
            
        }

        /// <summary>
        /// Hides divider when nav pane is closed.
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="args"></param>
        private void RootSplitView_PaneClosed(SplitView sender, object args)
        {
           
        }

        /// <summary>
        /// Callback when the SplitView's Pane is toggled closed.  When the Pane is not visible
        /// then the floating hamburger may be occluding other content in the app unless it is aware.
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void TogglePaneButton_Unchecked(object sender, RoutedEventArgs e)
        {
            this.CheckTogglePaneButtonSizeChanged();
        }

        /// <summary>
        /// Callback when the SplitView's Pane is toggled opened.
        /// Restores divider's visibility and ensures that margins around the floating hamburger are correctly set.
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void TogglePaneButton_Checked(object sender, RoutedEventArgs e)
        {
            this.CheckTogglePaneButtonSizeChanged();

        }
        
        /// <summary>
        /// Check for the conditions where the navigation pane does not occupy the space under the floating
        /// hamburger button and trigger the event.
        /// </summary>
        private void CheckTogglePaneButtonSizeChanged()
        {
            if (this.RootSplitView.DisplayMode == SplitViewDisplayMode.Inline ||
                this.RootSplitView.DisplayMode == SplitViewDisplayMode.Overlay)
            {
              //  var transform = this.TogglePaneButton.TransformToVisual(this);
              //  var rect = transform.TransformBounds(new Rect(0, 0, this.TogglePaneButton.ActualWidth, this.TogglePaneButton.ActualHeight));
              //  this.TogglePaneButtonRect = rect;
            }
            else
            {
                this.TogglePaneButtonRect = new Rect();
            }

            var handler = this.TogglePaneButtonRectChanged;
            if (handler != null)
            {
                // handler(this, this.TogglePaneButtonRect);
                handler.DynamicInvoke(this, this.TogglePaneButtonRect);
            }
        }

        /// <summary>
        /// Enable accessibility on each nav menu item by setting the AutomationProperties.Name on each container
        /// using the associated Label of each item.
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="args"></param>
        private void NavMenuItemContainerContentChanging(ListViewBase sender, ContainerContentChangingEventArgs args)
        {
            if (!args.InRecycleQueue && args.Item != null && args.Item is NavMenuItem)
            {
                args.ItemContainer.SetValue(AutomationProperties.NameProperty, ((NavMenuItem)args.Item).Label);
            }
            else
            {
                args.ItemContainer.ClearValue(AutomationProperties.NameProperty);
            }
        }
    }
}
