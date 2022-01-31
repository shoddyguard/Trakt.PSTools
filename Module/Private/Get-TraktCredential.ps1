<#
.SYNOPSIS
    Gets Trakt credentials
.DESCRIPTION
    Returns a credential object which keeps PowerShell happy.
.EXAMPLE
    PS C:\> Get-TraktCredential
    
    Would prompt the user to enter their Trakt credentials.
.OUTPUTS
    PSCredential object
#>
function Get-TraktCredential
{
    [CmdletBinding()]
    param ()
    begin {}
    process
    {
        While (!$ClientID)
        {
            $ClientID = Read-Host 'Please enter your Trakt ClientID'
        }
        While (!$ClientSecret)
        {
            $ClientSecret = Read-Host 'Please enter your Trakt ClientSecret' -MaskInput
        }
        $ClientSecretSecure = ConvertTo-SecureString -String $ClientSecret -AsPlainText -Force
        $Creds = New-Object System.Management.Automation.PSCredential -ArgumentList $ClientID, $ClientSecretSecure
    }
    end
    {
        if ($Creds)
        {
            Return $Creds
        }
        else
        {
            Return $null
        }
    }
}