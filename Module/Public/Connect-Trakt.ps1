<#
.SYNOPSIS
    Connects to the Trakt API using the 'device' method.
#>
function Connect-Trakt
{
    [CmdletBinding()]
    param
    (
        # Your ClientID
        [Parameter(Mandatory = $true)]
        [string]
        $ClientID,

        # Your ClientSecret
        [Parameter(Mandatory = $true)]
        [string]
        $ClientSecret,

        # Whether or not to persist the credentials
        [Parameter(Mandatory = $false)]
        [switch]
        $Persist,

        # Forces a new connection even if the credentials are already cached
        [Parameter(Mandatory = $false)]
        [switch]
        $Force
    )
    
    begin
    {
        $TraktSessionPath = Join-Path -Path $Global:HOME -ChildPath '.trakt'
        try
        {
            $TraktSession = Get-Content -Path $TraktSessionPath -Raw | ConvertFrom-Json
        }
        catch
        {
            # Do nothing, we probably don't have a session.
        }
        if ($TraktSession)
        {
            Write-Verbose 'Found cached session.'
            $TimeNow = Get-Date
            $SessionExpiry = Get-Date $TraktSession.Expires
            if ($SessionExpiry -le $TimeNow -or $Force)
            {
                # Session has expired, so we need to get a new one.
                Write-Verbose 'Session has expired, creating new one'
                $TraktSession = $null
            }
        }
    }
    process
    {
        if (!$TraktSession -or $Force)
        {
            # First get the Device code
            $URI = 'https://api.trakt.tv/oauth/device/code'
            $Headers = @{
                'Content-Type' = 'application/json'
            }
            $Body = @{
                'client_id' = $ClientID
            }
            try
            {
                $Code = Invoke-RestMethod -Uri $URI -Method Post -Headers $Headers -Body ($Body | ConvertTo-Json)
            }
            catch
            {
                throw "Failed to get device code.`n$($_.Exception.Message)"
            }
            $Stopwatch = New-Object System.Diagnostics.Stopwatch
            Write-Host "You will now be redirected to $($Code.verification_url), please enter the code: $($Code.user_code)"
            Write-Host 'Press any key to continue...'
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
            Start-Process $Code.verification_url
            Write-Host "Waiting for the OK from Trakt...`n"
            While (!$Token -and ($Stopwatch.Elapsed.Seconds -lt $Code.expires_in))
            {
                Write-Verbose 'Polling for token...'
                $URI = 'https://api.trakt.tv/oauth/device/token'
                $Body = @{
                    'code'          = $Code.device_code
                    'client_id'     = $ClientID
                    'client_secret' = $ClientSecret
                }
                try
                {
                    $Token = Invoke-RestMethod -Uri $URI -Method Post -Headers $Headers -Body ($Body | ConvertTo-Json)
                }
                catch
                {
                    # Do nothing, probably haven't auth'd yet
                }
                # Make sure we honor the rate limit!
                Start-Sleep $Code.Interval
            }
            if ($Token)
            {
                $TokenExpiry = [DateTime]::Now.AddSeconds($Token.expires_in)
                $TraktSession = @{
                    AccessToken = $Token.access_token
                    Expires     = $TokenExpiry.ToString()
                    ClientID    = $ClientID
                }
                if ($Persist)
                {
                    try
                    {
                        New-Item -Path $TraktSessionPath -Force -Value ($TraktSession | ConvertTo-Json) | Out-Null
                    }
                    catch
                    {
                        Write-Error "Failed to persist session.`n$($_.Exception.Message)"
                    }
                }
            }
            else
            {
                throw 'Failed to get access token.'
            }
        }
    }
    
    end
    {
        if ($TraktSession)
        {
            Return $TraktSession
        }
        else
        {
            throw 'Failed to connect to Trakt.'
        }
    }
}