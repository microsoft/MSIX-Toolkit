using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Collections;
using System.Runtime.Serialization;
using System.Xml;

namespace AppInstallerFileBuilder.Model
{
    [DataContract(Name = "MainBundle")]
    public class MainBundle
    {
        [DataMember(Name = "Uri")]
        private String _filePath;

        [DataMember(Name = "Version")]
        private String _version;

        [DataMember(Name = "Publisher")]
        private String _publisher;

        [DataMember(Name = "Name")]
        private String _name;

        public MainBundle()
        {
            _filePath = "";
            _version = "";
            _publisher = "";
            _name = "";
        }

        public MainBundle(String filePath, String version, String publisher, String name)
        {
            _filePath = filePath;
            _version = version;
            _publisher = publisher;
            _name = name;
        }

        public String FilePath
        {
            get { return _filePath; }
            set
            {
                _filePath = value;
            }
        }

        public String Version
        {
            get { return _version; }
            set
            {
                _version = value;
            }
        }

        public String Publisher
        {
            get { return _publisher; }
            set
            {
                _publisher = value;
            }
        }

        public String Name
        {
            get { return _name; }
            set
            {
                _name = value;
            }
        }
    }
}
