<#
.SYNOPSIS
    Searches Trakt for a given movie or show and returns the results. 
#>
function Search-Trakt
{
    [CmdletBinding()]
    param
    (
        # The query to search for
        [Parameter(Mandatory = $true)]
        [string]
        $Query,

        # The search type (e.g. movie, show, episode)
        [Parameter(Mandatory = $false)]
        [array]
        [ValidateSet('movie', 'show', 'episode')]
        $Type = @('movie', 'show', 'episode'),

        # An optional list of fields to limit the search to
        [Parameter(Mandatory = $false)]
        [array]
        $Fields,

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
        $Headers = @{
            'Content-Type'      = 'application/json'
            'trakt-api-version' = '2'
            'trakt-api-key'     = $ClientID
        }
        $URI = "https://api.trakt.tv/search/$($Type -join ',')?query=$Query"
        if ($Fields)
        {
            if (!$Type)
            {
                Write-Warning "No search type specified, 'Fields' parameter will be ignored."
            }
            else
            {
                $URI = $URI + "&fields=$($Fields -join ',')"
            }
        }
    }
    
    process
    {
        try
        {
            $Results = Invoke-RestMethod -Uri $URI -Method Get -FollowRelLink -Headers $Headers
        }
        catch
        {
            Write-Error "Failed to query Trakt.`n$($_.Exception.Message)"
        }
    }
    
    end
    {
        if ($Results)
        {
            Return $Results
        }
        else
        {
            Return $null
        }
    }
}