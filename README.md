Invoke-SqlCmd2
==============

Invoke-SqlCmd2 is a compact function to query SQL Server without other dependencies.  It was originally written by Chad Miller, with numerous community contributions along the way.

Several key benefits to using Invoke-SqlCmd2:

* Lightweight.  No installation needed; just copy or download the file, copy the text, `Install-Module`, etc.
* Simple parameterized queries.  This was a source of exasperation in [2005](https://blog.codinghorror.com/give-me-parameterized-sql-or-give-me-death/).  Over a decade later, Invoke-SqlCmd is still missing this.
* [Abstraction](https://powershell.org/2015/08/16/abstraction-and-configuration-data/).  Consider using and contributing to this, over writing your own .NET System.Data.SqlClient wrapper, or leaving a bunch of less friendly .NET code in your project

Pull requests and other contributions would be welcome!

## Instructions

```powershell
# One time setup
    # Download the repository
    # Unblock the zip
    # Extract the Invoke-SqlCmd2 folder to a module path (e.g. $env:USERPROFILE\Documents\WindowsPowerShell\Modules\)

    # Simple alternative, if you have PowerShell 5, or the PowerShellGet module:
        Install-Module Invoke-SqlCmd2

# Import the module.
    Import-Module Invoke-SqlCmd2    #Alternatively, Import-Module \\Path\To\Invoke-SqlCmd2

# Get help
    Get-Help Invoke-SqlCmd2 -Full
```

## Features

Props to Chad Miller and the other contributors for a fantastic function.  We've added a few features with much help from others:

* Added pipeline support, with the option to append a ServerInstance column to keep track of your results:
  * ![Add ServerInstance column](/Media/ISCAppendServerInstance.png)
* Added the option to pass in a PSCredential instead of a plaintext password
  * ![Use PSCredential](/Media/ISCCreds.png)
* Added PSObject output type to allow comparisons without odd [System.DBNull]::Value behavior:
  * Previously, many PowerShell comparisons resulted in errors:
    * ![GT Comparison Errors](/Media/ISCCompareGT.png)
  * With PSObject output, comparisons behave as expected:
    * ![GT Comparison Fix](/Media/ISCCompareGTFix.png)
  * Previously, testing for nonnull / null values did not work as expected:
    * ![NotNull Fails](/Media/ISCCompareNotNull.png)
  * With PSObject output, null values are excluded as expected
    * ![NotNull Fails Fix](/Media/ISCCompareNotNullFix.png)
  * Speed comparison between DataRow and PSObject output with 1854 rows, 84 columns:
    * ![Speed PSObject v Datarow](/Media/ISCPSObjectVsDatarow.png)

### That DBNull behavior is strange!  Why doesn't it behave as expected?

I agree.  PowerShell does a lot of work under the covers to provide behavior a non-developer might expect.  From my perspective, PowerShell should handle [System.DBNull]::Value like it does Null.  Please vote up [this Microsoft Connect suggestion](https://connect.microsoft.com/PowerShell/feedback/details/830412/provide-expected-comparison-handling-for-dbnull) if you agree!

Major thanks to [Dave Wyatt](http://powershell.org/wp/forums/topic/dealing-with-dbnull/) for providing the C# code that produces the PSObject output type as a workaround for this.

### Why is Invoke-Sqlcmd2 here?

* @RamblingCookieMonster copied the code [here](https://github.com/RamblingCookieMonster/PowerShell) to avoid the automated tweets for Poshcode.org submissions.  He makes many small changes and didn't want to spam twitter : )
* Since then, a number of contributions have come in.  Separating this out into it's own repository simplifies and enables improved collaboration
* Leaving this out of a larger module may be helpful for folks who simply want a lightweight function.  Modules can depend on this or hard code a point-in-time copy as needed
