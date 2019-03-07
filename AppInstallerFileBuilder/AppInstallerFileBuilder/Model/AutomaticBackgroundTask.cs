using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.Serialization;
using System.Text;
using System.Threading.Tasks;

namespace AppInstallerFileBuilder.Model
{
    [DataContract(Name = "AutomaticBackgroundTask")]

    public class AutomaticBackgroundTask
    {
        private bool _isAutoUpdate;

        public AutomaticBackgroundTask()
        {
            _isAutoUpdate = true;

        }

        public AutomaticBackgroundTask(bool isAutoUpdate)
        {
            _isAutoUpdate = isAutoUpdate;
        }

        public bool IsAutoUpdate
        {
            get { return _isAutoUpdate; }
            set
            {
                _isAutoUpdate = value;
            }
        }
    }
}