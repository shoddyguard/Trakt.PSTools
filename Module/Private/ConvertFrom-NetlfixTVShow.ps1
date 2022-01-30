<#
.SYNOPSIS
    Converts a Netflix TV Show into an object we can work with.
.DESCRIPTION
    This helper function takes a Netflix TV Show and converts it into an object we can work with.
    This is needed as there are a few TV shows that have a non-standard format so we have special workarounds in place.
.EXAMPLE
    PS C:\> ConvertFrom-NetflixTVShow -InputObject "Squid Game: Season 1: Red Light, Green Light"

    This would return the following object:
    {
        "ShowName": "Squid Game",
        "SeasonNumber": "1",
        "EpisodeName": "Red Light, Green Light"
    }
.EXAMPLE
    PS C:\> ConvertFrom-NetflixTVShow -InputObject "The Legend of Korra: Book One: Air: Welcome to Republic City"

    This would return the following object:
    {
        "ShowName": "The Legend of Korra",
        "SeasonNumber": "1",
        "EpisodeName": "Welcome to Republic City"
    }
#>
function ConvertFrom-NetflixTVShow
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
        Switch -regex ($InputObject)
        {
            # Standard Season and Episode naming
            '(?<ShowName>.*): (Season (?<SeasonNumber>\d*)): (?<EpisodeName>.*)'
            {
                $SeasonNumber = $matches.SeasonNumber
                # Extract the Show Name
                $ShowName = $matches.ShowName
                # Extract the Episode Name
                $EpisodeName = $matches.EpisodeName

                # Error handling for if the details are missing?
            }
            # Hacks for The Legend of Korra
            'The Legend of Korra: Book (?<BookNumber>.*): (?<BookName>.*): (?<EpisodeName>.*)'
            {
                $ShowName = 'The Legend of Korra'
                $BookNumber = $Matches.BookNumber
                $EpisodeName = $Matches.EpisodeName

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
                        throw "Unhandled book number: $BookNumber"
                    }
                }
            }
            # Hacks for Avatar: The Last Airbender
            'Avatar: The Last Airbender: Book (?<BookNumber>\d*): (?<EpisodeName>.*)'
            {
                Write-Verbose "Avatar"
                $ShowName = 'Avatar: The Last Airbender'
                $SeasonNumber = $Matches.BookNumber
                $EpisodeName = $Matches.EpisodeName
            }
            default
            {
                Write-Error "Unhandled input: $InputObject"
            }
        }
    }
    
    end
    {
        if (!$ShowName -or !$SeasonNumber -or !$EpisodeName)
        {
            Write-Error "Unable to parse show name, season number, or episode name from $InputObject"
            Return $null
        }
        else
        {
            $Return = [PSCustomObject]@{
                ShowName     = $ShowName
                SeasonNumber = $SeasonNumber
                EpisodeName  = $EpisodeName
            }
            Return $Return
        }
    }
}