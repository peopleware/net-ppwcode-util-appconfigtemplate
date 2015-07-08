###############################################################################
###  Bootstrap script for PSAKE                                             ###
###############################################################################
###  Copyright 2015 by PeopleWare n.v..                                     ###
###############################################################################
###  Authors: Ruben Vandeginste                                             ###
###############################################################################
###                                                                         ###
###  A script to bootstrap the powershell session for psake.                ###
###                                                                         ###
###############################################################################

#region INPUT PARAMATERS

###############################################################################
### INPUT PARAMETERS                                                        ### 
###############################################################################

###############################################################################
# input parameters
#   target: Task to execute
#   repos:  NuGet repositories to be used when psake is not available yet
param([string]$target = '', [string[]]$repos = @())

#endregion


#region HELPERS

###############################################################################
### HELPERS                                                                 ### 
###############################################################################

###############################################################################
# Stolen from Psake, helper function to execute external commands and respect
# their exit code.
#
function Exec {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = 1)][scriptblock]$cmd,
        [Parameter(Position = 1, Mandatory = 0)][string]$errorMessage = 'Bad command.',
        [Parameter(Position = 2, Mandatory = 0)][int]$maxRetries = 0,
        [Parameter(Position = 3, Mandatory = 0)][string]$retryTriggerErrorPattern = $null
    )

    $tryCount = 1

    do
    {
        try
        {
            $global:lastexitcode = 0
            & $cmd
            if ($lastexitcode -ne 0)
            {
                throw ('Exec: ' + $errorMessage)
            }
            break
        }
        catch [Exception]
        {
            if ($tryCount -gt $maxRetries)
            {
                throw $_
            }
            
            if ($retryTriggerErrorPattern -ne $null)
            {
                $isMatch = [regex]::IsMatch($_.Exception.Message, $retryTriggerErrorPattern)
                
                if ($isMatch -eq $false)
                {
                    throw $_
                }
            }
            
            Write-Host "Try $tryCount failed, retrying again in 1 second..."
            
            $tryCount++
            
            [System.Threading.Thread]::Sleep([System.TimeSpan]::FromSeconds(1))
        }
    }
    while ($true)
}

#endregion


#region MAIN

###############################################################################
### MAIN                                                                    ### 
###############################################################################

###############################################################################
# Main script to bootstrap psake.
#
try 
{
    # execution policy for scripts
    Set-ExecutionPolicy RemoteSigned

    # find module, if not found, try to download it
    $modules = Get-Item  .\src\packages\psake.*\tools\psake.psm1
    if ($modules -eq $null)
    {
        Push-Location
        Set-Location 'src'
        
        $reposources = ''
        $repos | ForEach-Object { $reposources="$reposources -source $_" }
        Exec { Invoke-Expression "nuget restore $reposources -noninteractive -nocache -verbosity quiet" } 'NuGet not available, or not executing as expected.'
        
        Pop-Location

        $modules = Get-Item  .\src\packages\psake.*\tools\psake.psm1
        if ($modules -eq $null)
        {
            throw 'Cannot find or fetch psake module.'
        }
    }

    # take most recent module, if multiple found
    #   not completely correct, but 'good enough'
    $module = $modules | Sort-Object -Property FullName -Descending | Select-Object -First 1

    # import module, force a reload if already loaded
    Import-Module $module.FullName -Force
    
    # execute the target, if any given
    if ($target -ne '')
    {
        Invoke-psake $target
    }
}
catch 
{
    Write-Host 'Error executing psake.ps1' -ForegroundColor DarkYellow
    Write-Host
    # Re-Throw so that the calling code does not continue.
    throw $_
}

#endregion
