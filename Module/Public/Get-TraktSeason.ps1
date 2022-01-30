<#
.SYNOPSIS
    Gets season information for a given show.
#>
function Get-TraktSeason
{
    [CmdletBinding()]
    param
    (
        # Trakt ID, Trakt slug, or IMDB ID (e.g "game-of-thrones")
        [Parameter(Mandatory = $true)]
        [string]
        $ShowID,

        # The season number to get information for.
        [Parameter(Mandatory = $true)]
        [int]
        $SeasonNumber,

        # Your ClientID/Secret for connecting to Trakt
        [Parameter(Mandatory = $false)]
        [pscredential]
        $Credential,

        # If set will force a refresh of the data from Trakt even if it's available in the cache.
        [Parameter(Mandatory = $false)]
        [switch]
        $Force
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
        # SeasonNumber is an int so hopefully we don't to worry about removing leading zeros, however if Trakt changes the API
        # then we'll need to change this.
        $URI = "https://api.trakt.tv/shows/$ShowID/seasons/$SeasonNumber"
        $Headers = @{
            'Content-Type'      = 'application/json'
            'trakt-api-version' = '2'
            'trakt-api-key'     = "$ClientID"
        }
        $CachePath = Join-Path $Global:TraktPSToolsCachePath -ChildPath 'Seasons.json'
        if (!(Test-Path $CachePath))
        {
            try
            {
                New-Item $CachePath -ItemType File -Force | Out-Null
            }
            catch
            {
                Write-Error "Failed to create cache file.`n$($_.Exception.Message)"
            }
        }
        try
        {
            $CachedData = Get-Content $CachePath -Force -Raw | ConvertFrom-Json -Depth 100 -NoEnumerate # We need no enumeration as we're potentially only getting a single object
        }
        catch
        {
            # Do nothing - it's likely we have no cached data.
        }
    }
    
    process
    {
        # Firstly query our cached data (if we have any).
        if ($CachedData)
        {
            # First check if we even have the show in our cache.
            $CachedShow = $CachedData | Where-Object { $_.id -eq $ShowID }
            if ($CachedShow)
            {
                Write-Verbose "Found $ShowID in cache."
                # We have the show in our cache, so check if we have the season in our cache.
                # We have to do this in a roundabout way as for some reason Where-Object doesn't work with the nested
                # structure of the data we get back from Trakt. 🤷‍♀️
                $CachedSeasonCheck = Get-Member -InputObject $CachedShow.Seasons | Where-Object { $_.Name -eq $SeasonNumber }
            }
            # If we've got a season in our cache, return it.
            if ($CachedSeasonCheck)
            {
                # If we're forcing a refresh, then we don't want to return the cached data but we still need to know
                # if we have the season in our cache so we can update it.
                if (!$Force)
                {
                    Write-Verbose "Returning cached season data for $ShowID season $SeasonNumber"
                    $Result = $CachedShow.Seasons.$SeasonNumber
                }
            }
        }
        if (!$Result)
        {
            Write-Verbose "Querying Trakt for season data for $ShowID season $SeasonNumber"
            try
            {
                $Result = Invoke-RestMethod -Uri $URI -Headers $Headers -FollowRelLink
            }
            catch
            {
                Write-Error "Failed to get season information for $ShowID.`n$($_.Exception.Message)"
            }
            if ($Result)
            {
                Write-Verbose "Got season information for $ShowID season $SeasonNumber"
                Write-Verbose 'Attempting to cache season data...'
                # Cache the data we've just retrieved.
                if ($CachedShow)
                {
                    # Find it's index in of the array of shows.
                    $IndexOfShow = $CachedData.IndexOf($CachedShow)

                    # We've already got the show in our cache, so just update/add the season.
                    if ($CachedSeasonCheck)
                    {
                        # We've already got the season so update it.
                        $CachedData[$IndexOfShow].Seasons.$SeasonNumber = $Result
                    }
                    else
                    {
                        # We don't have the season in our cache so add it.
                        $CachedData[$IndexOfShow].Seasons | Add-Member -MemberType NoteProperty -Name $SeasonNumber -Value $Result
                    }
                }
                else
                {
                    # We don't have the show in our cache so add it.
                    if (!$CachedData)
                    {
                        # If the cache is empty, then we need to create it. (and in the right format)
                        $CachedData = @(
                            [PSCustomObject]@{
                                id      = $ShowID
                                Seasons = [PSCustomObject]@{
                                    $SeasonNumber = $Result
                                }
                            }
                        )
                    }
                    else
                    {
                        # Otherwise just add the show.
                        $CachedData += [PSCustomObject]@{
                            id      = $ShowID
                            Seasons = [PSCustomObject]@{
                                $SeasonNumber = $Result
                            }
                        }
                    }
                }
                Write-Debug ($CachedData | Out-String)
                # Write the data to the cache file.
                try
                {
                    Set-Content $CachePath -Value ($CachedData | ConvertTo-Json -Depth 100 -AsArray)
                }
                catch
                {
                    Write-Error "Failed to write cache file.`n$($_.Exception.Message)"
                }
            }
        }
    }
    
    end
    {
        if ($Result)
        {
            Return $Result
        }
        else
        {
            Return $null
        }
    }
}