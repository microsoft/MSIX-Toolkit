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
    [DataContract(Name = "OnLaunch")]
    public class OnLaunch
    {
        private bool _isCheckUpdates;

        [DataMember(Name = "HoursBetweenUpdateChecks")]
        private int _hoursBetweenUpdateChecks;

        [DataMember(Name = "UpdateBlocksActivation")]
        private bool _isBlockUpdate;

        [DataMember(Name = "ShowPrompt")]
        private bool _isShowPrompt;


        public OnLaunch()
        {
            _isCheckUpdates = true;
            _isShowPrompt = true;
            _isBlockUpdate = true;
            _hoursBetweenUpdateChecks = 0;
        }

        public OnLaunch(bool isCheckUpdates, int hourseBetweenUpdateChecks, bool isShowPrompt, bool isBlockUpdate)
        {
            _hoursBetweenUpdateChecks = hourseBetweenUpdateChecks;
            _isCheckUpdates = isCheckUpdates;
            _isBlockUpdate = isBlockUpdate;
            _isShowPrompt = isShowPrompt;
        }

        public int HoursBetweenUpdateChecks
        {
            get { return _hoursBetweenUpdateChecks; }
            set
            {
                _hoursBetweenUpdateChecks = value;
            }
        }

        public bool IsCheckUpdates
        {
            get { return _isCheckUpdates; }
            set
            {
                _isCheckUpdates = value;
            }
        }
        public bool IsShowPrompt
        {
            get { return _isShowPrompt; }
            set
            {
                _isShowPrompt = value;
            }
        }
        public bool IsBlockUpdate
        {
            get { return _isBlockUpdate; }
            set
            {
                _isBlockUpdate = value;
            }
        }
    }
}
