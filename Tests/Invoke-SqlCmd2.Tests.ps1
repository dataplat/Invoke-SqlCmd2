$PSVersion = $PSVersionTable.PSVersion.Major
if(-not $ENV:BHProjectName) {Set-BuildEnvironment}
$ModuleName = $ENV:BHProjectName

$PSDefaultParameterValues = @{
    'Mock:ModuleName'              = $ModuleName
    'Assert-MockCalled:ModuleName' = $ModuleName
}

# Verbose output for non-master builds on appveyor
# Handy for troubleshooting.
# Splat @Verbose against commands as needed (here or in pester tests)
$Verbose = @{}
if($ENV:BHBranchName -notlike "master" -or $env:BHCommitMessage -match "!verbose")
{
    $Verbose.add("Verbose",$True)
}

Import-Module $PSScriptRoot\..\$ModuleName -Force

Describe "$ModuleName PS$PSVersion" {
    Context 'Strict mode' {

        Set-StrictMode -Version latest

        It 'Module imports successfully' {
            $Module = Get-Module $ModuleName
            $Module.Name | Should be $ModuleName
            $Commands = $Module.ExportedCommands.Keys
            $Commands -contains 'Invoke-SqlCmd2' | Should Be $True
        }
    }
}

Describe "Invoke-SqlCmd2 PS$PSVersion" {
    Context 'Strict mode' {

        Set-StrictMode -Version latest

        It 'Invoke-SqlCmd2 command exports from module' {
            $Output = Get-Command Invoke-SqlCmd2
            $Output.Module | Should be 'Invoke-SqlCmd2'
        }

    }
}


Describe "Invoke-SqlCmd2 with System.Data mocked on PS$PSVersion" {

    # Prevent SQL from actually ... running
    Mock New-Object {
        switch ($TypeName) {
            # A SqlConnection that never connects
            "System.Data.SqlClient.SQLConnection" {
                [PSCustomObject]@{
                    PSTypeName                       = $_
                    ConnectionString                 = @($ArgumentList)[0]
                    FireInfoMessageEventOnUserErrors = $true
                } | Add-Member Open -MemberType ScriptMethod { } -Passthru |
                    Add-Member Close -MemberType ScriptMethod { } -Passthru |
                    Add-Member Dispose -MemberType ScriptMethod { } -Passthru |
                    Add-Member add_InfoMessage -MemberType ScriptMethod -Passthru {
                    $this | Add-Member InfoMessageHandler -MemberType NoteProperty $Args[0]
                } |
                Add-Member remove_InfoMessage -MemberType ScriptMethod { } -Passthru
            }
            # A SqlCommand that doesn't complain about that connection
            "System.Data.SqlClient.SqlCommand" {
                $cmd = [System.Data.SqlClient.SqlCommand]::new($ArgumentList[0])
                $cmd | Add-Member -NotePropertyName Connection -NotePropertyValue $ArgumentList[1] -Force -Passthru
            }
            # A phoney data adapter that always returns one row
            "System.Data.SqlClient.SqlDataAdapter" {
                [PSCustomObject]@{
                    PSTypeName    = $_
                    SelectCommand = $ArgumentList[0]
                } | Add-Member Dispose -MemberType ScriptMethod { } -Passthru |
                    Add-Member Fill -MemberType ScriptMethod {
                        $table = $args[0].Tables.Add("results")
                        $null = $Table.Columns.Add("Id", [int])
                        $null = $Table.Columns.Add("First", [string])
                        $null = $Table.Columns.Add("Last", [string])
                        $null = $Table.Columns.Add("Superpower", [string])
                        $table.Rows.Add(1, "Joel", "Bennett", [DBNull]::Value)
                } -PassThru
            }
            default {
                # We do not need to support the -Property parameter
                if (!$ArgumentList) {
                    $ArgumentList = @()
                }
                ($TypeName -as [Type])::New.Invoke($ArgumentList)
            }
        }
    }

    Context "Running simple queries" {
        $TestQuery = "SELECT Top 5 FROM [Users]"

        $result = Invoke-SqlCmd2 -Query $TestQuery -ServerInstance localhost

        It "Returns DataRow by default" {
            $result | Should -BeOfType [Data.DataRow]
        }

        It "Creates a SqlCommand with the query" {
            Assert-MockCalled New-Object -ParameterFilter {
                $TypeName -eq "System.Data.SqlClient.SqlCommand" -and $ArgumentList[0] -eq $TestQuery
            }
        }

        It "Creates a SqlDataAdapter with the query" {
            Assert-MockCalled New-Object -ParameterFilter {
                $TypeName -eq "System.Data.SqlClient.SqlDataAdapter" -and $ArgumentList[0].CommandText -eq $TestQuery
            }
        }

        It "Returns the result of the Fill command on the dataset" {
            $Result["First"] | Should -eq "Joel"
            $Result["Last"] | Should -eq "Bennett"
        }
    }

    Context "Running parameterized queries" {
        # $Command is the command we -Named
        $TestQuery = "SELECT Top 5 FROM [Users] Where First = @FirstName"
        # Which is great, because it's a private command, but I don't need to run my tests InModuleScope
        $result = Invoke-SqlCmd2 -Query $TestQuery -SqlParameters @{ FirstName = 'Joel' } -ServerInstance localhost

        It "Populates the Parameters on the SqlCommand" {
            Assert-MockCalled New-Object -ParameterFilter {
                $TypeName -eq "System.Data.SqlClient.SqlDataAdapter" -and $ArgumentList[0].CommandText -eq $TestQuery -and $ArgumentList[0].Parameters.Count -eq 1 -and $ArgumentList[0].Parameters[0].Value -eq 'Joel'
            }
        }

        # These are the same tests from the simple query
        It "Returns DataRow by default" {
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [Data.DataRow]
        }

        It "Creates a SqlCommand with the query" {
            Assert-MockCalled New-Object -ParameterFilter {
                $TypeName -eq "System.Data.SqlClient.SqlCommand" -and $ArgumentList[0] -eq $TestQuery
            }
        }

        It "Returns the result of the Fill command on the dataset" {
            $Result["First"] | Should -eq "Joel"
            $Result["Last"] | Should -eq "Bennett"
        }
    }

    Context "Returning PSObject, with multiple servers" {
        $TestQuery = "SELECT Top 5 FROM [Users]"

        # Which is great, because it's a private command, but I don't need to run my tests InModuleScope
        $result = Invoke-SqlCmd2 -Query $TestQuery -ServerInstance host1, host2 -As PSObject -AppendServerInstance

        It "Initializes DBNullScrubber" {
            "DBNullScrubber" -as [Type] | Should -Not -BeNullOrEmpty
        }
        It "Returns PSCustomObject" {
            $result | Should -BeOfType [PSCustomObject]
        }

        It "Returns the results as objects" {
            $Result.First | Should -eq "Joel", "Joel"
            $Result.Last | Should -eq "Bennett", "Bennett"
        }
        It "Returns results from multiple instances" {
            $Result.ServerInstance | Should -eq "host1", "host2"
        }
        It "Converts DBNull to `$null" {
            $result.Superpower[0] | Should -BeNull
            $result.Superpower[1] | Should -BeNull
            $result.Superpower | Should -Not -Be ([DBNull]::Value)
        }

        It "Creates a SqlCommand with the query" {
            Assert-MockCalled New-Object -ParameterFilter {
                $TypeName -eq "System.Data.SqlClient.SqlCommand" -and $ArgumentList[0] -eq $TestQuery
            }
        }

        It "Creates a SqlDataAdapter with the query" {
            Assert-MockCalled New-Object -ParameterFilter {
                $TypeName -eq "System.Data.SqlClient.SqlDataAdapter" -and $ArgumentList[0].CommandText -eq $TestQuery
            }
        }
    }

    Context "Handling SQL Errors" {
        Mock New-Object -ParameterFilter { $TypeName -eq "System.Data.SqlClient.SqlDataAdapter" } {
            [PSCustomObject]@{
                PSTypeName    = $_
                SelectCommand = $ArgumentList[0]
            } | Add-Member Fill -MemberType ScriptMethod {
                throw (
                    New-MockObject System.Data.SqlClient.SqlException |
                    Add-Member -NotePropertyName Message -NotePropertyValue "Error Getting Data" -Passthru -Force)
            } -PassThru
        }

        Mock Write-Debug { }
        Mock Write-Verbose { }

        $TestQuery = "SELECT Top 5 FROM [Users]"
        # $Command is the command we -Named
        # Which is great, because it's a private command, but I don't need to run my tests InModuleScope
        It "Logs exception to debug stream and rethrows" {
            {
                Invoke-SqlCmd2 -Query $TestQuery -ServerInstance localhost
            } | Should -Throw

            Assert-MockCalled Write-Debug -ParameterFilter {
                $Message -match "^Capture.*Error"
            }
        }

        It "Creates a SqlCommand with the query" {
            Assert-MockCalled New-Object -ParameterFilter {
                $TypeName -eq "System.Data.SqlClient.SqlCommand" -and $ArgumentList[0] -eq $TestQuery
            }
        }

        It "Creates a SqlDataAdapter with the query" {
            Assert-MockCalled New-Object -ParameterFilter {
                $TypeName -eq "System.Data.SqlClient.SqlDataAdapter" -and $ArgumentList[0].CommandText -eq $TestQuery
            }
        }
    }

    Context "ConnectionString Parameters" {
        $TestQuery = "SELECT Top 5 FROM [Users]"

        It "Accepts Credentials, Encryption, and App Names" {
            $credential = [PSCredential]::new("sa", (ConvertTo-SecureString 'S3cr3ts' -AsPlainText -Force))
            Invoke-SqlCmd2 -Query $TestQuery -ServerInstance localhost -Credential $credential -Encrypt -ApplicationName "QMODHelper"
        }

        It "Puts the parameters in the Connection String" {
            Assert-MockCalled New-Object -ParameterFilter {
                if ($TypeName -eq "System.Data.SqlClient.SqlCommand") {
                    $ArgumentList[1].ConnectionString -match "Data Source=localhost" -and
                    $ArgumentList[1].ConnectionString -match "Password=S3cr3ts" -and
                    $ArgumentList[1].ConnectionString -match "Encrypt=True" -and
                    $ArgumentList[1].ConnectionString -match "Application Name=QMODHelper"
                }
            }
        }
    }

    Context "Output -As Works" {
        $TestQuery = "SELECT Top 5 FROM [Users]"

        It "Returns a DataTable on demand" {
            Invoke-SqlCmd2 -Query $TestQuery -ServerInstance localhost -As DataTable |
            Should -BeOfType [Data.DataTable]
        }
        It "Returns a DataSet on demand" {
            Invoke-SqlCmd2 -Query $TestQuery -ServerInstance localhost -As DataSet |
            Should -BeOfType [Data.DataSet]
        }

        It "Returns a SingleValue on demand" {
            Invoke-SqlCmd2 -Query $TestQuery -ServerInstance localhost -As SingleValue |
            Should -Be 1
        }
    }
}
