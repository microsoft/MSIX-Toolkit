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
    [DataContract(Name = "AppInstaller")]
    public class AppInstaller
    {
        private String _filePath;
        private String _versionNumber;
        
        public AppInstaller()
        {
            _filePath = "";
            _versionNumber = "";
        }

        public AppInstaller(String filePath, String versionNumber)
        {
            _filePath = filePath;
            _versionNumber = versionNumber;
        }

        public String FilePath
        {
            get { return _filePath; } 
            set
            {
                _filePath = value;
            }
        }

        public String VersionNumber
        {
            get { return _versionNumber; }
            set
            {
                _versionNumber = value;
            }
        }
    }
}
