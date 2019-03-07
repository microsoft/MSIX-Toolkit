using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Windows.UI.Xaml;
using Windows.UI.Xaml.Data;

namespace AppInstallerFileBuilder.Converters
{
     public class PackageTypeVisibilityConverter : IValueConverter
    {
        public object Convert(object value, Type targetType, object parameter, string language)
        {
            if (value.ToString() == PackageType.MSIXBUNDLE.ToString())
            {
                return Visibility.Collapsed;
            }
            else
            {
                return Visibility.Visible;
            }
        }

        public object ConvertBack(object value, Type targetType, object parameter, string language)
        {
            throw new NotImplementedException();
        }
    }
}
