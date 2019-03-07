using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.Serialization;
using System.Text;
using System.Threading.Tasks;

namespace AppInstallerFileBuilder.Model
{
    [DataContract(Name = "ForceUpdateFromAnyVersion")]

    public class ForceUpdateFromAnyVersion
    {
        private bool _isForceUpdate;

        public ForceUpdateFromAnyVersion()
        {
            _isForceUpdate = true;

        }

        public ForceUpdateFromAnyVersion(bool isForceUpdate)
        {
            _isForceUpdate = isForceUpdate;
        }

        public bool IsForceUpdate
        {
            get { return _isForceUpdate; }
            set
            {
                _isForceUpdate = value;
            }
        }
    }
}
