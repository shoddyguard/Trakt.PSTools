<#
.SYNOPSIS
    Gets season information for a given show.
#>
function Get-TraktSeason
{
    [CmdletBinding()]
    param
    (
        # The ID/Slug of the show to get the season for.
        [Parameter(Mandatory = $true)]
        [string]
        $ShowID,

        # The season number to get information for. (if none all seasons will be returned)
        [Parameter(Mandatory = $false)]
        [int]
        $SeasonNumber,

        # Your ClientID/Secret for connecting to Trakt
        [Parameter(Mandatory = $false)]
        [pscredential]
        $Credential
    )
    
    begin
    {
        if (!$Global:TraktSession)
        {
            if (!$Credential)
            {
                try
                {
                    $Credential = Get-TraktCredential
                }
                catch
                {
                    throw "Failed to get Trakt credentials.`n$($_.Exception.Message)"
                }
            }
            try
            {
                $TraktSession = Connect-Trakt -ClientID $Credential.UserName -ClientSecret (ConvertFrom-SecureString $Credential.Password -AsPlainText)
            }
            catch
            {
                throw "Failed to connect to Trakt.`n$($_.Exception.Message)"
            }        
        }
        else
        {
            $TraktSession = $Global:TraktSession
        }
        $ClientID = $TraktSession.ClientID
        $URI = "https://api.trakt.tv/shows/$ShowID/seasons"
        $Headers = @{
            'Content-Type'      = 'application/json'
            'trakt-api-version' = '2'
            'trakt-api-key'     = "$ClientID"
        }
        if ($SeasonNumber)
        {
            # SeasonNumber is an int so hopefully we don't to worry about removing leading zeros, however if Trakt changes the API
            # then we'll need to change this.
            $URI = $URI + "/$SeasonNumber"
        }
    }
    
    process
    {
        Write-Debug "URI: $URI"
        try
        {
            $Response = Invoke-RestMethod -Uri $URI -Headers $Headers -FollowRelLink
        }
        catch
        {
            Write-Error "Failed to get season information for $ShowID.`n$($_.Exception.Message)"
        }
    }
    
    end
    {
        if ($Response)
        {
            Return $Response
        }
        else
        {
            Return $null
        }
    }
}