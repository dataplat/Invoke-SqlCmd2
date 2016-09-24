# Invoke-SqlCmd2 Changes

## v1.6.2

* Author: Shiyang Qiu
* Fixed the non SQL error handling and added Finally Block to close connection.
* Fixed the .DESCRIPTION.

## v1.6.1

* Author: Shiyang Qiu
* Fixed the verbose option and SQL error handling conflict 
* Fixed SQLConnection handling so that it is not closed (we now only close connections we create)

## v1.6.0

* Author: Warren Frame
* Added SQLConnection parameter and handling.  Is there a more efficient way to handle the parameter sets?
* Added ErrorAction SilentlyContinue handling to Fill method
* Added help for sqlparameter parameter.
* Updated OutputType attribute, comment based help, parameter attributes (thanks supersobbie), removed username/password params
* Added AppendServerInstance switch.

## v1.5.3

* Author: Warren Frame
* Replaced DBNullToNull param with PSObject Output option.
* Added credential support.
* Added pipeline support for ServerInstance.
* Moved [to GitHub](https://github.com/RamblingCookieMonster/PowerShell)

## v1.5.2

* Author: Warren Frame, Dave Wyatt
* Added DBNullToNull switch and code from Dave Wyatt.
* Added parameters to comment based help (need someone with SQL expertise to verify these)

## v1.5.1

* Author: Warren Frame
* Added ParameterSets
* set Query and InputFile to mandatory

## v1.5

* Author: Joel Bennett
* Add SingleValue output option

## v1.4.1

* Author: Paul Bryson <atamido _at_ gmail.com>
* Added fix to check for null values in parameterized queries and replace with [DBNull]

## v1.4

* Author: Justin Dearing <zippy1981 _at_ gmail.com>
* Added the ability to pass parameters to the query.

## v1.3

* Author: Chad Miller
* Added As parameter to control DataSet, DataTable or array of DataRow Output type

## v1.2

* Author: Chad Miller
* Added inputfile, SQL auth support, connectiontimeout and output message handling. Updated help documentation

## v1.1

* Author: Chad Miller
* Fixed Issue with connection closing

## v1.0

* Author: Chad Miller
* Initial release
