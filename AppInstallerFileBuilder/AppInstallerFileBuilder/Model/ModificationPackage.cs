using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Collections;
using System.Runtime.Serialization;
using System.Xml;
using System.ComponentModel;

namespace AppInstallerFileBuilder.Model
{
    [DataContract(Name = "ModificationPackages")]
    public class ModificationPackage : INotifyPropertyChanged
    {
        public event PropertyChangedEventHandler PropertyChanged;
        private void NotifyPropertyChanged(string v)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(v));
        }

        [DataMember(Name = "Uri")]
        private String _filePath;

        [DataMember(Name = "PackageType")]
        private PackageType _packageType;

        [DataMember(Name = "Version")]
        private String _version;

        [DataMember(Name = "Publisher")]
        private String _publisher;

        [DataMember(Name = "Name")]
        private String _name;

        [DataMember(Name = "ProcessorArchitecture")]
        private String _processorArchitecture;

        [DataMember(Name = "FullUriPath")]
        private String _uriPath;

        public ModificationPackage()
        {
            _filePath = "";
            _version = "";
            _packageType = PackageType.MSIX;
            _publisher = "";
            _name = "";
            _processorArchitecture = "";
            _uriPath = "";
        }

        public ModificationPackage(String filePath, String version, String publisher, String name, PackageType packageType, String processorArchitecture, String uriPath)
        {
            _filePath = filePath;
            _version = version;
            _publisher = publisher;
            _packageType = packageType;
            _name = name;
            _processorArchitecture = processorArchitecture;
            _uriPath = uriPath;
        }

        public String FilePath
        {
            get { return _filePath; }
            set
            {
                if (value != _filePath)
                {
                    _filePath = value;
                    NotifyPropertyChanged("FilePath");
                }
            }
        }

        public String Version
        {
            get { return _version; }
            set
            {
                if (value != _version)
                {
                    _version = value;
                    NotifyPropertyChanged("Version");
                }
            }
        }

        public String Publisher
        {
            get { return _publisher; }
            set
            {
                if (value != _publisher)
                {
                    _publisher = value;
                    NotifyPropertyChanged("Publisher");
                }
            }
        }

        public String Name
        {
            get { return _name; }
            set
            {
                if (value != _name)
                {
                    _name = value;
                    NotifyPropertyChanged("Name");
                }
            }
        }

        public PackageType PackageType
        {
            get { return _packageType; }
            set
            {
                _packageType = value;
            }
        }

        public String PackageTypeAsString
        {
            get
            {
                return _packageType.ToString();
            }
        }

        public String ProcessorArchitecture
        {
            get { return _processorArchitecture; }
            set
            {
                if (value != _processorArchitecture)
                {
                    _processorArchitecture = value;
                    NotifyPropertyChanged("ProcessorArchitecture");
                }
            }
        }

        public String FullUriPath
        {
            get { return _uriPath; }
            set
            {
                if (value != _uriPath)
                {
                    _uriPath = value;
                    NotifyPropertyChanged("FullUriPath");
                }
            }
        }

        public IList<PackageType> PackageTypes
        {
            get
            {
                // Will result in a list like {"Appx", "AppxBundle", "msix" or "msixbundle"}
                return Enum.GetValues(typeof(PackageType)).Cast<PackageType>().ToList<PackageType>();
            }
        }

        public IList<ProcessorArchitecture> ProcessorTypes
        {
            get
            {
                // Will result in a list like {"Arm", "x64"}
                return Enum.GetValues(typeof(ProcessorArchitecture)).Cast<ProcessorArchitecture>().ToList<ProcessorArchitecture>();
            }
        }
    }
}
