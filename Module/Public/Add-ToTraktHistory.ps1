<#
.SYNOPSIS
    Add one of more items to a user's watch history.
#>
function Add-ToTraktHistory
{
    [CmdletBinding()]
    param
    (
        # The movies to add to the watch history
        [Parameter(Mandatory = $false)]
        [array]
        $Movies,

        # The shows to add to the watch history
        [Parameter(Mandatory = $false)]
        [array]
        $Shows,

        # The seasons to add to the watch history
        [Parameter(Mandatory = $false)]
        [array]
        $Seasons,

        # The episodes to add to the watch history
        [Parameter(Mandatory = $false)]
        [array]
        $Episodes,

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
        $AccessToken = $TraktSession.AccessToken
        $URI = 'https://api.trakt.tv/sync/history'
        $Headers = @{
            'Content-Type'      = 'application/json'
            'Authorization'     = "Bearer $AccessToken"
            'trakt-api-version' = '2'
            'trakt-api-key'     = $ClientID
        }
    }
    
    process
    {
        $Body = @{}
        if ($Movies)
        {
            $Body.movies = $Movies
        }
        if ($Shows)
        {
            $Body.shows = $Shows
        }
        if ($Seasons)
        {
            $Body.seasons = $Seasons
        }
        if ($Episodes)
        {
            $Body.episodes = $Episodes
        }
        $Body = ConvertTo-Json $Body -Depth 99

        try
        {
            $Response = Invoke-RestMethod -Uri $URI -Method Post -Headers $Headers -Body $Body
        }
        catch
        {
            throw "Failed to add items to Trakt history.`n$($_.Exception.Message)"
        }
    }
    
    end
    {
        # Do we want to return "not_found" items in a special way?
        if ($Response)
        {
            Return $Response
        }
        else
        {
            return $null
        }
    }
}