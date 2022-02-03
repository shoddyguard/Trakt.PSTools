<#
.SYNOPSIS
    Imports Netflix watch history to Trakt.tv
#>
function Import-NetflixHistory
{
    [CmdletBinding()]
    param
    (
        # The path to the Netflix history CSV
        [Parameter(Mandatory = $true)]
        [string]
        $HistoryFile,
        
        # The date to import the history from
        [Parameter(Mandatory = $false)]
        [DateTime]
        $StartDate,

        # The date to import the history to
        [Parameter(Mandatory = $false)]
        [DateTime]
        $EndDate,

        # Your ClientID/Secret for connecting to Trakt
        [Parameter(Mandatory = $false)]
        [pscredential]
        $Credential
    )
    
    begin
    {
        # Make sure we're connected to Trakt
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
        # By default Netflix exports the history to a CSV file which includes a header row. (title,date) 
        # so we shouldn't need to specify the header row.
        try
        {
            $NetflixHistory = Import-Csv -Path $HistoryFile
        }
        catch
        {
            throw "Failed to import Netflix history CSV.`n$($_.Exception.Message)"
        }
        if (!$NetflixHistory)
        {
            throw "Failed to import Netflix history CSV.`nHistory file is empty."
        }
        # Try to reduce down the history to just the rows we want so it's not as unruly as the full history!
        if ($StartDate)
        {
            $NetflixHistory = $NetflixHistory | Where-Object { (Get-Date $_.Date) -ge $StartDate }
        }
        if ($EndDate)
        {
            $NetflixHistory = $NetflixHistory | Where-Object { (Get-Date $_.Date) -le $EndDate }
        }
        Write-Verbose "Found $($NetflixHistory.Count) history entries to import"
        Write-Debug "`n$NetflixHistory"

        $TVShowsToImport = @()
        $MoviesToImport = @()
        $FilteredTVShows = @()
        $FilteredMovies = @()
        $FailedTVShows = @()
        # These will be used to filter out special characters from the title
        $AcceptedCharacters = '[^a-zA-Z]'
    }
    
    process
    {
        # First we need to find out what we need to import by going through each item and working out if it's
        # a TV show or a movie.
        foreach ($WatchedItem in $NetflixHistory)
        {
            $WatchDate = (Get-Date $WatchedItem.Date)

            # Try to convert the watched item into an object we can work with.
            try
            {
                $ConvertedItem = ConvertFrom-NetflixWatchHistory -InputObject $WatchedItem.title
            }
            catch
            {
                # Throw because we can't do anything with this item.
                throw "Failed to convert $($WatchedItem.Title).`n$($_.Exception.Message).`nNo changes will be made to Trakt."
            }


            if ($ConvertedItem.Type -eq 'TV Show')
            {
                $TVShowsToImport += [pscustomobject]@{
                    Title        = $ConvertedItem.Title
                    SeasonNumber = $ConvertedItem.SeasonNumber
                    EpisodeTitle = $ConvertedItem.EpisodeTitle
                    WatchDate    = $WatchDate
                }
            }
            else
            {
                $MoviesToImport += [pscustomobject]@{
                    Title     = $ConvertedItem.Title
                    WatchDate = $WatchDate
                }
            }
        }

        if ($TVShowsToImport)
        {
            # Debug helpers
            Write-Debug "TV Shows to import:`n$($TVShowsToImport)"
            if ($DebugPreference -ne 'SilentlyContinue')
            {
                $Global:DebugTVShowsToImport = $TVShowsToImport
            }

            # Filter the list of TV shows so we only process each show once.
            $TVShowTitles = $TVShowsToImport | Select-Object -ExpandProperty Title -Unique
            foreach ($Title in $TVShowTitles)
            {
                Write-Verbose "Processing $($Title)"
                # Work out if we've already parsed this show before
                if ($FilteredTVShows.Title -contains $Title)
                {
                    # If we have then we can just skip it and move on
                    Write-Verbose "Skipping $($Title) as we've already processed it"
                    continue
                }
                else
                {
                    # This is the first time we've seen this show so we need to process it
                    Write-Verbose "$($Title) appears to be a new show"
                    # Get the show ID from Trakt
                    $ShowID = $null
                    $WatchedEpisodes = @()
                    try
                    {
                        $ShowID = Search-Trakt -Query $Title -Type show -Fields 'title'
                        if ($ShowID.count -gt 1)
                        {
                            # If we've returned more than one show then try to grab the show with a score of 1000 (which should be an exact match)
                            $ShowID = $ShowID | Where-Object { $_.Score -eq 1000 }
                        }
                        if (!$ShowID)
                        {
                            # For now we'll raise an error if we can't find the show, perhaps in the future we'll prompt the user to select the correct show?
                            Write-Error "Failed to find show ID for $($TVShow.Title)"
                        }
                        else
                        {
                            # We'll use the slug as the show ID, so that cached results are easy to read.
                            $ShowID = $ShowID | 
                                Select-Object -ExpandProperty show | 
                                    Select-Object -ExpandProperty ids | 
                                        Select-Object -ExpandProperty slug

                            if (!$ShowID)
                            {
                                Write-Error "Failed to get ShowID slug for $($TVShow.Title)"
                            }
                        }
                    }
                    catch
                    {
                        Write-Warning "Failed to get Trakt ID for $($TVShow.Title).`n$($_.Exception.Message)`nThis will be skipped"
                        $FailedTVShows += $Title #TODO: work out if this is the format we want to use
                        continue
                    }
                    # Find all seasons we have for this show
                    # This helps us cut down on the amount of processing we need to do as we can batch process all seasons for a show
                    $Seasons = $TVShowsToImport | 
                        Where-Object { $_.Title -eq $Title } | 
                            Select-Object -ExpandProperty SeasonNumber -Unique

                    foreach ($Season in $Seasons)
                    {
                        # First get the season information from Trakt
                        try
                        {
                            $SeasonInfo = Get-TraktSeason -ShowID $ShowID -SeasonNumber $Season
                        }
                        catch
                        {
                            Write-Warning "Failed to get season information for $($TVShow.Title) season $($Season).`n$($_.Exception.Message)`nThis will be skipped"
                            $FailedTVShows += $Title #TODO: work out if this is the format we want to use
                            Continue
                        }

                        # Now grab all episodes for this season out of our list to import
                        $Episodes = $TVShowsToImport | 
                            Where-Object { $_.Title -eq $Title -and $_.SeasonNumber -eq $Season }
                        
                        if (!$Episodes)
                        {
                            Write-Warning "Failed to find episodes for $($TVShow.Title) season $($Season).`nThis will be skipped"
                            $FailedTVShows += $Title #TODO: work out if this is the format we want to use
                            continue
                        }

                        # Now we need to find the episodes that we've watched in this season and pull their information out of the season info
                        foreach ($Episode in $Episodes)
                        {
                            $EpisodeIDs = $null
                            # We convert the episode title from both NetFlix and Trakt to a lowercase string devoid of special characters so we can hopefully
                            # find the correct episode.
                            # The ordering is important here - the Netflix title usually tends to be longer, so it's safer being the left hand operand.
                            $EpisodeIDs = $SeasonInfo | 
                                Where-Object { ($Episode.EpisodeTitle -replace $AcceptedCharacters,'').ToLower() -match ($_.Title -replace $AcceptedCharacters,'').ToLower() } |
                                    Select-Object -ExpandProperty ids

                            if ($EpisodeIDs)
                            {
                                $WatchedEpisodes += [PSCustomObject]@{
                                    watched_at = $Episode.WatchDate
                                    ids        = $EpisodeIDs
                                }
                            }
                            else
                            {
                                Write-Error "Failed to find episode ID for $($Episode.EpisodeTitle) in $($TVShow.Title) season $($Episode.SeasonNumber)"
                            }
                        }
                    }

                    $FilteredTVShows += [PSCustomObject]@{
                        Title    = $Title
                        Episodes = $WatchedEpisodes
                    }
                }    
                
            }

            # Debug helpers
            Write-Debug "Filtered TV Shows:`n$($FilteredTVShows.Count)"
            if ($DebugPreference -ne 'SilentlyContinue')
            {
                $Global:DebugFilteredTVShows = $FilteredTVShows
            }
        }
        if ($MoviesToImport)
        {
            # Debug helpers
            Write-Debug "Movies to import:`n$($MoviesToImport.count)"
            if ($DebugPreference -ne 'SilentlyContinue')
            {
                $Global:DebugMoviesToImport = $MoviesToImport
            }

            # We may have watched the same movie multiple times, so first get a list of unique titles
            $MovieTitles = $MoviesToImport | Select-Object -ExpandProperty Title -Unique

            foreach ($Movie in $MovieTitles)
            {
                # Get the movie ID from Trakt
                $MovieID = $null
                try
                {
                    $MovieID = Search-Trakt -Query $Movie -Type movie -Fields 'title'
                    if ($MovieID.count -gt 1)
                    {
                        # If we have more than one movie then try to grab the movie with a score of 1000 (which should be an exact match)
                        $MovieID = $MovieID | Where-Object { $_.Score -eq 1000 }
                    }
                    if (!$MovieID)
                    {
                        # Just raise an error for now, in the future it'd be good to prompt the user to select the correct movie
                        Write-Warning "Failed to find movie ID for $($Movie.Title)"
                        $FailedMovies += $Movie #TODO: work out if this is the format we want to use
                        continue
                    }
                    else
                    {
                        $MovieID = $MovieID | 
                            Select-Object -ExpandProperty movie | 
                                Select-Object -ExpandProperty ids | 
                                    Select-Object -ExpandProperty slug

                        if (!$MovieID)
                        {
                            Write-Warning "Failed to filter MovieID for $($Movie.Title)"
                            $FailedMovies += $Movie #TODO: work out if this is the format we want to use
                            continue
                        }
                    }
                }
                catch
                {
                    Write-Warning "Failed to get Trakt ID for $($Movie.Title).`n$($_.Exception.Message)`nThis will be skipped"
                    $FailedMovies += $Movie #TODO: work out if this is the format we want to use
                    continue
                }

                # Get all occurrences of this movie
                $MovieWatches = $MoviesToImport | Where-Object { $_.Title -eq $Movie }
                $FilteredMovies += [PSCustomObject]@{
                    Title   = $Movie
                    id      = $MovieID
                    Watches = $MovieWatches.WatchDate
                }
            }
            # Debug helpers
            Write-Debug "Filtered Movies:`n$($FilteredMovies.Count)"
            if ($DebugPreference -ne 'SilentlyContinue')
            {
                $Global:DebugFilteredMovies = $FilteredMovies
            }
        }
    }
    
    end
    {

    }
}