<#
.SYNOPSIS
    Converts a Netflix watched item into an object we can work with.
.DESCRIPTION
    This helper function takes a Netflix watched item and converts it into an object we can work with.
    This is needed as there are a few TV shows/movies that have a non-standard format so we have special workarounds in place.
.EXAMPLE
    PS C:\> ConvertFrom-NetflixWatchHistory -InputObject "Squid Game: Season 1: Red Light, Green Light"

    This would return the following object:
    {
        "Type": "TV Show",
        "Title": "Squid Game",
        "SeasonNumber": "1",
        "EpisodeTitle": "Red Light, Green Light"
    }
.EXAMPLE
    PS C:\> ConvertFrom-NetflixWatchHistory -InputObject "The Legend of Korra: Book One: Air: Welcome to Republic City"

    This would return the following object:
    {
        "Type": "TV Show",
        "Title": "The Legend of Korra",
        "SeasonNumber": "1",
        "EpisodeTitle": "Welcome to Republic City"
    }
.EXAMPLE
    PS C:\> ConvertFrom-NetflixWatchHistory -InputObject "Batman Begins"

    This would return the following object:
    {
        "Type": "Movie",
        "Title": "Batman Begins"
    }
#>
function ConvertFrom-NetflixWatchHistory
{
    [CmdletBinding()]
    param
    (
        # The input object
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        $InputObject
    )
    
    begin
    {}
    
    process
    {
        Write-Verbose "Processing $InputObject"
        Switch -regex ($InputObject)
        {
            # Standard Season and Episode naming
            '(?<Title>.*): (Season (?<SeasonNumber>\d*)): (?<EpisodeTitle>.*)'
            {
                Write-Verbose 'Found standard season and episode naming'
                $Type = 'TV Show'
                $SeasonNumber = $matches.SeasonNumber
                # Extract the Show Name
                $Title = $matches.Title
                # Extract the Episode Name
                $EpisodeTitle = $matches.EpisodeTitle

                # Error handling for if the details are missing?
            }
            # Hacks for The Legend of Korra
            'The Legend of Korra: Book (?<BookNumber>.*): (?<BookName>.*): (?<EpisodeTitle>.*)'
            {
                Write-Verbose 'Applying special case for The Legend of Korra'
                $Type = 'TV Show'
                $Title = 'The Legend of Korra'
                $BookNumber = $Matches.BookNumber
                $EpisodeTitle = $Matches.EpisodeTitle

                switch ($BookNumber)
                {
                    'One'
                    {
                        $SeasonNumber = 1
                    }
                    'Two'
                    {
                        $SeasonNumber = 2
                    }
                    'Three'
                    {
                        $SeasonNumber = 3
                    }
                    'Four'
                    {
                        $SeasonNumber = 4
                    }
                    Default
                    {
                        Write-Error "Unhandled book number: $BookNumber"
                    }
                }
            }
            # Hacks for Avatar: The Last Airbender
            'Avatar: The Last Airbender: Book (?<BookNumber>\d*): (?<EpisodeTitle>.*)'
            {
                Write-Verbose 'Applying special case for Avatar: The Last Airbender'
                $Type = 'TV Show'
                $Title = 'Avatar: The Last Airbender'
                $SeasonNumber = $Matches.BookNumber
                $EpisodeTitle = $Matches.EpisodeTitle
            }
            default
            {
                # Assume it's a movie
                Write-Verbose 'Defaulting to movie'
                $Type = 'Movie'
                $Title = $InputObject
            }
        }
        if ($Type -eq 'TV Show')
        {
            if (!$Title -or !$SeasonNumber -or !$EpisodeTitle)
            {
                Write-Error "Unable to parse show name, season number, or episode name from $InputObject"
            }
            else
            {
                $Return = [PSCustomObject]@{
                    Type         = $Type
                    Title     = $Title
                    SeasonNumber = $SeasonNumber
                    EpisodeTitle  = $EpisodeTitle
                }
            }
        }
        else
        {
            $Return = [PSCustomObject]@{
                Type  = $Type
                Title = $InputObject
            }
        }
    }
    
    end
    {
        if ($Return)
        {
            Return $Return
        }
        else
        {
            Return $null
        }
    }
}