using AppInstallerFileBuilder;
using AppInstallerFileBuilder.Model;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Runtime.Serialization;
using System.Text;
using System.Threading.Tasks;
using System.Xml;
using Windows.Storage;
using Windows.UI.Xaml;
using Windows.UI.Xaml.Controls;
using Windows.UI.Xaml.Navigation;

namespace AppInstallerFileBuilder.Views
{

    /// </summary>
    public sealed partial class GenerateXMLView : Page
    {
        //private Button _generateButton;
        private TextBox _filePathTextBox;
        private TextBox _versionNumberTextBox;
        private String _appInstallerFilePath;
        private String _appInstallerFileVersion;

        private MainPackage _mainPackage;
        private TextBox _mainPackageUriPathTextBox;
        private TextBox _mainPackageNameTextBox;
        private TextBox _mainPackageVersionTextBox;
        private TextBox _mainPackagePublisherTextBox;

        public ObservableCollection<OptionalPackage> OptionalPackages { get; private set; } = new ObservableCollection<OptionalPackage>();
        public ObservableCollection<ModificationPackage> ModificationPackages { get; private set; } = new ObservableCollection<ModificationPackage>();
        public ObservableCollection<RelatedPackage> RelatedPackages { get; private set; } = new ObservableCollection<RelatedPackage>();
        public ObservableCollection<Dependency> Dependencies { get; private set; } = new ObservableCollection<Dependency>();

        /***************************************************************************
         * 
         * Constructor
         *
         ***************************************************************************/
        public GenerateXMLView()
        {
            this.InitializeComponent();
            //_generateButton = (Button)this.FindName("Generate_Button");
            _filePathTextBox = (TextBox)this.FindName("File_Path_Text_Box");
            _versionNumberTextBox = (TextBox)this.FindName("Version_Number_Text_Box");
            
            _mainPackage = new MainPackage(App.MainPackage.FilePath, App.MainPackage.Version, App.MainPackage.Publisher, App.MainPackage.Name, App.MainPackage.PackageType, App.MainPackage.ProcessorArchitecture, App.MainPackage.ResourceId, App.MainPackage.FullUriPath);
            _mainPackageUriPathTextBox = (TextBox)this.FindName("Main_File_Path_Text_Box");
            _mainPackageNameTextBox = (TextBox)this.FindName("Main_Name_Box");
            _mainPackageVersionTextBox = (TextBox)this.FindName("Main_Version_Box");
            _mainPackagePublisherTextBox = (TextBox)this.FindName("Main_Publisher_Box");

            this.OptionalPackages = App.OptionalPackages;
            this.ModificationPackages = App.ModificationPackages;
            this.RelatedPackages = App.RelatedPackages;
            this.Dependencies = App.Dependencies;

        }

        protected override void OnNavigatedTo(NavigationEventArgs e)
        {
            _mainPackageUriPathTextBox.Text = _mainPackage.FilePath;
            _mainPackageNameTextBox.Text = _mainPackage.Name;
            _mainPackageVersionTextBox.Text = _mainPackage.Version;
            _mainPackagePublisherTextBox.Text = _mainPackage.Publisher;

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

        private async void Generate_File_Button_Click(object sender, RoutedEventArgs e)
        {
            //Check that all required fields have been filled
            if (!_validateInput())
            {
                return;
            }

            var savePicker = new Windows.Storage.Pickers.FileSavePicker
            {
                SuggestedStartLocation =
                Windows.Storage.Pickers.PickerLocationId.Desktop
        };
            // Dropdown of file types the user can save the file as
            savePicker.FileTypeChoices.Add("APPINSTALLER file", new List<string>() { ".appinstaller" });
            // Default file name if the user does not type one in or select a file to replace
            
            Windows.Storage.StorageFile file = await savePicker.PickSaveFileAsync();

            try
            {
                var t = Task.Run(async () =>
                {
                    var fileStream = await file.OpenAsync(FileAccessMode.ReadWrite);

                    //Create file
                    //FileStream writer = new FileStream(file.Path, FileMode.OpenOrCreate);

                    AppInstaller appInstaller = new AppInstaller(App.AppInstallerFilePath, App.AppInstallerVersionNumber);

                    XmlWriterSettings settings = new XmlWriterSettings
                    {
                        Indent = true,
                        OmitXmlDeclaration = false,
                        NewLineOnAttributes = true,
                        Encoding = Encoding.UTF8,
                        NamespaceHandling = NamespaceHandling.OmitDuplicates
                    };
                    
                    var fs = fileStream.AsStreamForWrite();

                    
                    XmlWriter xdw = XmlWriter.Create(fs, settings);
                    
                    //DataContractSerializer appInstallerDCS = new DataContractSerializer(typeof(AppInstaller));

                    //AppInstaller Content
                    //appInstallerDCS.WriteStartObject(xdw, appInstaller);
                    xdw.WriteStartElement("","AppInstaller", App.AppInstallerFileSchemaNamespace);

                    //xdw.WriteAttributeString("xmlns", );
                    xdw.WriteAttributeString("Version", App.AppInstallerVersionNumber);
                    xdw.WriteAttributeString("Uri", App.AppInstallerFilePath);
                    
                    
                    //Main Package Content
                    if (App.MainPackage.PackageType == PackageType.MSIX)
                    {
                        //DataContractSerializer mainPackageDCS = new DataContractSerializer(typeof(MainPackage));

                        //mainPackageDCS.WriteStartObject(xdw, _mainPackage);

                        xdw.WriteStartElement("MainPackage");

                        xdw.WriteAttributeString("Name", _mainPackage.Name);
                        xdw.WriteAttributeString("Publisher", _mainPackage.Publisher);
                        xdw.WriteAttributeString("Version", _mainPackage.Version);
                        if (_mainPackage.ResourceId != "")
                        {
                            xdw.WriteAttributeString("ResourceId", _mainPackage.ResourceId);
                        }
                        if (_mainPackage.ProcessorArchitecture != "" && _mainPackage.PackageType != PackageType.MSIXBUNDLE)
                        {
                            xdw.WriteAttributeString("ProcessorArchitecture", _mainPackage.ProcessorArchitecture.ToString());
                        }
                        xdw.WriteAttributeString("Uri", _mainPackage.FilePath);
                        xdw.WriteEndElement();
                        //mainPackageDCS.WriteEndObject(xdw);
                    }
                    else if (App.MainPackage.PackageType == PackageType.MSIXBUNDLE)
                    {
                        //DataContractSerializer mainBundleDCS = new DataContractSerializer(typeof(MainBundle));
                        MainBundle mainBundle = new MainBundle(App.MainPackage.FilePath, App.MainPackage.Version, App.MainPackage.Publisher, App.MainPackage.Name);
                        //mainBundleDCS.WriteStartObject(xdw, mainBundle);
                        xdw.WriteStartElement("MainBundle");

                        xdw.WriteAttributeString("Name", mainBundle.Name);
                        xdw.WriteAttributeString("Publisher", mainBundle.Publisher);
                        xdw.WriteAttributeString("Version", mainBundle.Version);
                        xdw.WriteAttributeString("Uri", mainBundle.FilePath);
                        //mainBundleDCS.WriteEndObject(xdw);
                        xdw.WriteEndElement();
                    }

                    //Optional Packages Content
                    ObservableCollection<OptionalPackage> optionalPackages = App.OptionalPackages;
                    //DataContractSerializer optionalPackageDCS = new DataContractSerializer(typeof(OptionalPackage));

                    //Modification Packages Content
                    ObservableCollection<ModificationPackage> modificationPackages = App.ModificationPackages;

                    bool hasOptionalPackage = (optionalPackages.Count > 0 && App.IsOptionalPackages);
                    bool hasModificationPackage = (modificationPackages.Count > 0 && App.IsModificationPackages);

                    if (hasOptionalPackage || hasModificationPackage)
                    {
                        xdw.WriteStartElement("OptionalPackages");
                        //optionalPackageDCS.WriteStartObject(xdw, optionalPackages[0]);
                        if (hasOptionalPackage)
                        {
                            for (int i = 0; i < optionalPackages.Count; i++)
                            {
                                //Write package or bundle element
                                if (optionalPackages[i].PackageType == PackageType.MSIX)
                                {
                                    Package package = new Package(
                                        optionalPackages[i].FilePath,
                                        optionalPackages[i].Version,
                                        optionalPackages[i].Publisher,
                                        optionalPackages[i].Name,
                                        optionalPackages[i].PackageType,
                                        optionalPackages[i].ProcessorArchitecture
                                    );

                                    //DataContractSerializer packageDCS = new DataContractSerializer(typeof(Package));
                                    xdw.WriteStartElement("Package");
                                    //packageDCS.WriteStartObject(xdw, package);
                                    xdw.WriteAttributeString("Version", package.Version);
                                    xdw.WriteAttributeString("Uri", package.FilePath);
                                    xdw.WriteAttributeString("Publisher", package.Publisher);
                                    if (package.ProcessorArchitecture != "" && package.PackageType != PackageType.MSIXBUNDLE)
                                    {
                                        xdw.WriteAttributeString("ProcessorArchitecture", package.ProcessorArchitecture.ToString());
                                    }
                                    xdw.WriteAttributeString("Name", package.Name);
                                    //packageDCS.WriteEndObject(xdw);
                                    xdw.WriteEndElement();
                                }
                                else if (optionalPackages[i].PackageType == PackageType.MSIXBUNDLE)
                                {
                                    Bundle bundle = new Bundle(
                                         optionalPackages[i].FilePath,
                                        optionalPackages[i].Version,
                                        optionalPackages[i].Publisher,
                                        optionalPackages[i].Name,
                                        optionalPackages[i].PackageType
                                    );

                                    //DataContractSerializer bundleDCS = new DataContractSerializer(typeof(Bundle));
                                    //bundleDCS.WriteStartObject(xdw, bundle);
                                    xdw.WriteStartElement("Bundle");
                                    xdw.WriteAttributeString("Version", bundle.Version);
                                    xdw.WriteAttributeString("Uri", bundle.FilePath);
                                    xdw.WriteAttributeString("Publisher", bundle.Publisher);
                                    xdw.WriteAttributeString("Name", bundle.Name);
                                    //bundleDCS.WriteEndObject(xdw);
                                    xdw.WriteEndElement();
                                }
                            }
                        }

                        if (hasModificationPackage)
                        {
                            for (int i = 0; i < modificationPackages.Count; i++)
                            {
                                //Write package or bundle element
                                if (modificationPackages[i].PackageType == PackageType.MSIX)
                                {
                                    Package package = new Package(
                                        modificationPackages[i].FilePath,
                                        modificationPackages[i].Version,
                                        modificationPackages[i].Publisher,
                                        modificationPackages[i].Name,
                                        modificationPackages[i].PackageType,
                                        modificationPackages[i].ProcessorArchitecture
                                    );

                                    //DataContractSerializer packageDCS = new DataContractSerializer(typeof(Package));
                                    //packageDCS.WriteStartObject(xdw, package);
                                    xdw.WriteStartElement("Package");
                                    xdw.WriteAttributeString("Version", package.Version);
                                    xdw.WriteAttributeString("Uri", package.FilePath);
                                    xdw.WriteAttributeString("Publisher", package.Publisher);
                                    if (package.ProcessorArchitecture != "" && package.PackageType != PackageType.MSIXBUNDLE)
                                    {
                                        xdw.WriteAttributeString("ProcessorArchitecture", package.ProcessorArchitecture.ToString());
                                    }
                                    xdw.WriteAttributeString("Name", package.Name);
                                    //packageDCS.WriteEndObject(xdw);
                                    xdw.WriteEndElement();
                                }
                                else if (modificationPackages[i].PackageType == PackageType.MSIXBUNDLE)
                                {
                                    Bundle bundle = new Bundle(
                                         modificationPackages[i].FilePath,
                                        modificationPackages[i].Version,
                                        modificationPackages[i].Publisher,
                                       modificationPackages[i].Name,
                                        modificationPackages[i].PackageType
                                    );

                                    //DataContractSerializer bundleDCS = new DataContractSerializer(typeof(Bundle));
                                    //bundleDCS.WriteStartObject(xdw, bundle);
                                    xdw.WriteStartElement("Bundle");
                                    xdw.WriteAttributeString("Version", bundle.Version);
                                    xdw.WriteAttributeString("Uri", bundle.FilePath);
                                    xdw.WriteAttributeString("Publisher", bundle.Publisher);
                                    xdw.WriteAttributeString("Name", bundle.Name);
                                    //bundleDCS.WriteEndObject(xdw);
                                    xdw.WriteEndElement();
                                }
                            }
                        }                       
                        //optionalPackageDCS.WriteEndObject(xdw);
                        xdw.WriteEndElement();
                    }

                    //Related Packages Content
                    ObservableCollection<RelatedPackage> relatedPackages = App.RelatedPackages;
                    //DataContractSerializer relatedPackageDCS = new DataContractSerializer(typeof(RelatedPackage));
                    if (relatedPackages.Count > 0 && App.IsRelatedPackages)
                    {
                        //relatedPackageDCS.WriteStartObject(xdw, relatedPackages[0]);
                        xdw.WriteStartElement("RelatedPackages");
                        for (int i = 0; i < relatedPackages.Count; i++)
                        {
                            //Write package or bundle element
                            if (relatedPackages[i].PackageType == PackageType.MSIX)
                            {
                                Package package = new Package(
                                    relatedPackages[i].FilePath,
                                    relatedPackages[i].Version,
                                    relatedPackages[i].Publisher,
                                    relatedPackages[i].Name,
                                    relatedPackages[i].PackageType,
                                    relatedPackages[i].ProcessorArchitecture
                                );

                                //DataContractSerializer packageDCS = new DataContractSerializer(typeof(Package));
                                xdw.WriteStartElement("Package");
                                //packageDCS.WriteStartObject(xdw, package);
                                xdw.WriteAttributeString("Version", package.Version);
                                xdw.WriteAttributeString("Uri", package.FilePath);
                                xdw.WriteAttributeString("Publisher", package.Publisher);
                                if (package.ProcessorArchitecture != "" && package.PackageType != PackageType.MSIXBUNDLE)
                                {
                                    xdw.WriteAttributeString("ProcessorArchitecture", package.ProcessorArchitecture.ToString());
                                }
                                xdw.WriteAttributeString("Name", package.Name);
                                //packageDCS.WriteEndObject(xdw);
                                xdw.WriteEndElement();
                            }
                            else if (relatedPackages[i].PackageType == PackageType.MSIXBUNDLE)
                            {
                                Bundle bundle = new Bundle(
                                     relatedPackages[i].FilePath,
                                    relatedPackages[i].Version,
                                    relatedPackages[i].Publisher,
                                   relatedPackages[i].Name,
                                    relatedPackages[i].PackageType
                                );

                                //DataContractSerializer bundleDCS = new DataContractSerializer(typeof(Bundle));
                                //bundleDCS.WriteStartObject(xdw, bundle);
                                xdw.WriteStartElement("Bundle");
                                xdw.WriteAttributeString("Version", bundle.Version);
                                xdw.WriteAttributeString("Uri", bundle.FilePath);
                                xdw.WriteAttributeString("Publisher", bundle.Publisher);
                                xdw.WriteAttributeString("Name", bundle.Name);
                                //bundleDCS.WriteEndObject(xdw);
                                xdw.WriteEndElement();
                            }
                        }
                        //relatedPackageDCS.WriteEndObject(xdw);
                        xdw.WriteEndElement();
                    }


                    //Dependency Content

                    ObservableCollection<Dependency> dependencies = App.Dependencies;
                    //DataContractSerializer dependencyDCS = new DataContractSerializer(typeof(Dependency));
                    if (dependencies.Count > 0 && App.IsDependencies)
                    {
                        //dependencyDCS.WriteStartObject(xdw, dependencies[0]);
                        xdw.WriteStartElement("Dependencies");
                        for (int i = 0; i < dependencies.Count; i++)
                        {
                            //Write package or bundle element
                            if (dependencies[i].PackageType == PackageType.MSIX)
                            {
                                Package package = new Package(
                                    dependencies[i].FilePath,
                                    dependencies[i].Version,
                                    dependencies[i].Publisher,
                                    dependencies[i].Name,
                                    dependencies[i].PackageType,
                                    dependencies[i].ProcessorArchitecture
                                );

                                //DataContractSerializer packageDCS = new DataContractSerializer(typeof(Package));
                                //packageDCS.WriteStartObject(xdw, package);
                                xdw.WriteStartElement("Package");
                                xdw.WriteAttributeString("Version", package.Version);
                                xdw.WriteAttributeString("Uri", package.FilePath);
                                xdw.WriteAttributeString("Publisher", package.Publisher);
                                if (package.ProcessorArchitecture != "" && package.PackageType != PackageType.MSIXBUNDLE)
                                {
                                    xdw.WriteAttributeString("ProcessorArchitecture", package.ProcessorArchitecture.ToString());
                                }
                                xdw.WriteAttributeString("Name", package.Name);
                                //packageDCS.WriteEndObject(xdw);
                                xdw.WriteEndElement();
                            }
                            else if (dependencies[i].PackageType == PackageType.MSIXBUNDLE)
                            {
                                Bundle bundle = new Bundle(
                                    dependencies[i].FilePath,
                                    dependencies[i].Version,
                                    dependencies[i].Publisher,
                                    dependencies[i].Name,
                                    dependencies[i].PackageType
                                );

                                //DataContractSerializer bundleDCS = new DataContractSerializer(typeof(Bundle));
                                //bundleDCS.WriteStartObject(xdw, bundle);
                                xdw.WriteStartElement("Bundle");
                                xdw.WriteAttributeString("Version", bundle.Version);
                                xdw.WriteAttributeString("Uri", bundle.FilePath);
                                xdw.WriteAttributeString("Publisher", bundle.Publisher);
                                xdw.WriteAttributeString("Name", bundle.Name);
                                //bundleDCS.WriteEndObject(xdw);
                                xdw.WriteEndElement();
                            }
                        }
                        //dependencyDCS.WriteEndObject(xdw);
                        xdw.WriteEndElement();
                    }
                    

                    //Update Settings
                    UpdateSettings updateSettings = new UpdateSettings();
                    
                    //OnLaunch
                    OnLaunch onLaunch = new OnLaunch(App.IsCheckUpdates, App.HoursBetweenUpdates, App.IsShowPrompt, App.IsBlockUpdate);

                    //ForceUpdateFromAnyVersion
                    ForceUpdateFromAnyVersion forceUpdate = new ForceUpdateFromAnyVersion(App.IsForceUpdate);

                    //AutomaticBackgroundTask 
                    AutomaticBackgroundTask automaticBackgroundTask = new AutomaticBackgroundTask(App.IsAutoUpdate);

                    if (onLaunch.IsCheckUpdates)
                    {
                        //DataContractSerializer updateSettingsDCS = new DataContractSerializer(typeof(UpdateSettings));
                        //updateSettingsDCS.WriteStartObject(xdw, updateSettings);
                        xdw.WriteStartElement("UpdateSettings");

                        //DataContractSerializer onLaunchDCS = new DataContractSerializer(typeof(OnLaunch));
                        //onLaunchDCS.WriteStartObject(xdw, onLaunch);
                        xdw.WriteStartElement("OnLaunch");

                        //HoursBetweenUpdate checks is only available AFTER 1709
                        if(!App.AppInstallerFileSchemaNamespace.Equals("http://schemas.microsoft.com/appx/appinstaller/2017"))
                        {
                            xdw.WriteAttributeString("HoursBetweenUpdateChecks", onLaunch.HoursBetweenUpdateChecks.ToString());
                        }
                        
                        if (onLaunch.IsShowPrompt)
                            xdw.WriteAttributeString("ShowPrompt", onLaunch.IsShowPrompt.ToString().ToLower());
                        if (onLaunch.IsBlockUpdate)
                            xdw.WriteAttributeString("UpdateBlocksActivation", onLaunch.IsBlockUpdate.ToString().ToLower());
                        //onLaunchDCS.WriteEndObject(xdw);
                        xdw.WriteEndElement();

                        if (forceUpdate.IsForceUpdate)
                        {
                            //DataContractSerializer forceUpdateDCS = new DataContractSerializer(typeof(ForceUpdateFromAnyVersion));
                            //forceUpdateDCS.WriteStartObject(xdw, forceUpdate);
                            xdw.WriteStartElement("ForceUpdateFromAnyVersion");
                            xdw.WriteString(forceUpdate.IsForceUpdate.ToString().ToLower());
                            //forceUpdateDCS.WriteEndObject(xdw);
                            xdw.WriteEndElement();
                        }
                        
                        if (automaticBackgroundTask.IsAutoUpdate)
                        {
                            //DataContractSerializer autoUpdateDCS = new DataContractSerializer(typeof(AutomaticBackgroundTask));
                            //autoUpdateDCS.WriteStartObject(xdw, automaticBackgroundTask);
                            xdw.WriteStartElement("AutomaticBackgroundTask");
                            //autoUpdateDCS.WriteEndObject(xdw);
                            xdw.WriteEndElement();
                        }

                        //updateSettingsDCS.WriteEndObject(xdw);
                        xdw.WriteEndElement();
                    }
                    

                    //xdw.WriteEndElement();
                    //appInstallerDCS.WriteEndObject(xdw);
                    xdw.Dispose();
                });
                t.Wait();
            }
            catch (Exception exc)
            {
                Debug.WriteLine("The serialization operation failed: {0} StackTrace: {1}",
                exc.Message, exc.StackTrace);
            }

            //Display dialog
            _displaySuccessDialog(file);

        }

        private bool _validateInput()
        {
            if (App.AppInstallerFilePath == "" || App.AppInstallerVersionNumber == "")
            {
                _displayMissingAppInstallerInformationDialog();
                return false;
            }

            if (App.MainPackage.FilePath == "" || App.MainPackage.Name == "" || App.MainPackage.Publisher == "" || App.MainPackage.Version == "")
            {
                _displayMissingMainPackageInformationDialog();
                return false;
            }

            if (App.IsOptionalPackages == true)
            {
                for (int i = 0; i < App.OptionalPackages.Count; i++)
                {
                    if (App.OptionalPackages[i].FilePath == "" || App.OptionalPackages[i].Name == "" || App.OptionalPackages[i].Publisher == "" || App.OptionalPackages[i].Version == "")
                    {
                        _displayMissingOptionalPackageInformationDialog(); 
                        return false;
                    }
                }
            }

            if (App.IsRelatedPackages == true)
            {
                for (int i = 0; i < App.RelatedPackages.Count; i++)
                {
                    if (App.RelatedPackages[i].FilePath == "" || App.RelatedPackages[i].Name == "" || App.RelatedPackages[i].Publisher == "" || App.RelatedPackages[i].Version == "")
                    {
                        _displayMissingRelatedPackageInformationDialog();
                        return false;
                    }
                }
            }

            if (App.IsModificationPackages == true)
            {
                for (int i = 0; i < App.ModificationPackages.Count; i++)
                {
                    if (App.ModificationPackages[i].FilePath == "" || App.ModificationPackages[i].Name == "" || App.ModificationPackages[i].Publisher == "" || App.ModificationPackages[i].Version == "")
                    {
                        _displayMissingModificationPackageInformationDialog();
                        return false;
                    }
                }
            }

            if (App.IsDependencies == true)
            {
                for (int i = 0; i < App.Dependencies.Count; i++)
                {
                    if (App.Dependencies[i].FilePath == "" || App.Dependencies[i].Name == "" || App.Dependencies[i].Publisher == "" || App.Dependencies[i].Version == "")
                    {
                        _displayMissingDependencyInformationDialog();
                        return false;
                    }
                }
            }

            return true;
        }

        private void Back_Button_Click(object sender, RoutedEventArgs e)
        {
            AppShell.Current.AppFrame.Navigate(AppShell.Current.navlist[0].DestPage);
        }

        private async void _displaySuccessDialog(IStorageFile file)
        {
            ContentDialog successDialog = new ContentDialog
            {
                Title = "File Created Successfully",
                PrimaryButtonText = "Open AppInstaller File",
                Content ="The file was created in this location: " + file.Path,
                CloseButtonText = "Close",
            };

            ContentDialogResult result = await successDialog.ShowAsync();

            // Delete the file if the user clicked the primary button.
            /// Otherwise, do nothing.
            if (result == ContentDialogResult.Primary)
            {
                // Set the option to show the picker
                var options = new Windows.System.LauncherOptions();
                options.DisplayApplicationPicker = true;

                var success = await Windows.System.Launcher.LaunchFileAsync(file,options);
                if (success)
                {
                    Debug.WriteLine("success");
                }
                else
                {
                    Debug.WriteLine("failed");
                }
            }
            else
            {
                // The user clicked the CLoseButton, pressed ESC, Gamepad B, or the system back button.
                // Do nothing.
            }
        }


        private async void _displayMissingAppInstallerInformationDialog()
        {
            ContentDialog failDialog = new ContentDialog
            {
                Title = "Error: Incomplete AppInstaller Information",
                Content = "The file could not be created as a required field was left empty on the AppInstaller page. Please fill in all required fields on this page.",
                CloseButtonText = "Ok"
            };

            ContentDialogResult result = await failDialog.ShowAsync();
        }

        private async void _displayMissingMainPackageInformationDialog()
        {
            ContentDialog failDialog = new ContentDialog
            {
                Title = "Error: Incomplete Main Package Information",
                Content = "The file could not be created as a required field was left empty on the Main Package page. Please fill in all required fields on this page.",
                CloseButtonText = "Ok"
            };

            ContentDialogResult result = await failDialog.ShowAsync();
        }

        private async void _displayMissingOptionalPackageInformationDialog()
        {
            ContentDialog failDialog = new ContentDialog
            {
                Title = "Error: Incomplete Optional Package Information",
                Content = "The file could not be created as a required field was left empty on the Optional Package page. Please fill in all required fields on this page.",
                CloseButtonText = "Ok"
            };

            ContentDialogResult result = await failDialog.ShowAsync();
        }

        private async void _displayMissingDependencyInformationDialog()
        {
            ContentDialog failDialog = new ContentDialog
            {
                Title = "Error: Incomplete Dependency Information",
                Content = "The file could not be created as a required field was left empty on the Dependency page. Please fill in all required fields on this page.",
                CloseButtonText = "Ok"
            };

            ContentDialogResult result = await failDialog.ShowAsync();
        }

        private async void _displayMissingRelatedPackageInformationDialog()
        {
            ContentDialog failDialog = new ContentDialog
            {
                Title = "Error: Incomplete Related Package Information",
                Content = "The file could not be created as a required field was left empty on the Related Package page. Please fill in all required fields on this page.",
                CloseButtonText = "Ok"
            };

            ContentDialogResult result = await failDialog.ShowAsync();
        }

        private async void _displayMissingModificationPackageInformationDialog()
        {
            ContentDialog failDialog = new ContentDialog
            {
                Title = "Error: Incomplete Modification Package Information",
                Content = "The file could not be created as a required field was left empty on the Modification Package page. Please fill in all required fields on this page.",
                CloseButtonText = "Ok"
            };

            ContentDialogResult result = await failDialog.ShowAsync();
        }

        private void _save()
        {
            AppInstallerFileBuilder.App.AppInstallerFilePath = _appInstallerFilePath;
            AppInstallerFileBuilder.App.AppInstallerVersionNumber = _appInstallerFileVersion;
        }

        private void File_Path_Text_Box_TextChanged(object sender, TextChangedEventArgs e)
        {
            _appInstallerFilePath = _filePathTextBox.Text;
            _save();
        }
        private void Version_Text_Box_TextChanged(object sender, TextChangedEventArgs e)
        {
            _appInstallerFileVersion = _versionNumberTextBox.Text;
            _save();
        }
    }
}
