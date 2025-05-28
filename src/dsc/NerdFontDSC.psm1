using namespace System.Collections.Generic

<#
    .SYNOPSIS
        DSC resource for managing NerdFonts installation.
    
    .DESCRIPTION
        This DSC resource manages the installation of NerdFonts.
        It can install one or more NerdFonts or all NerdFonts.

    .EXAMPLE
        # Install a specific NerdFont
        NerdFont 'InstallHackFont' {
            Name = 'Hack'
            Ensure = 'Present'
            Scope = 'CurrentUser'
        }

    .EXAMPLE
        # Install all NerdFonts for all users
        NerdFont 'InstallAllNerdFonts' {
            All = $true
            Ensure = 'Present'
            Scope = 'AllUsers'
        }
#>
[DscResource()]
class NerdFont {
    [DscProperty(Key)]
    [string]$Name

    [DscProperty()]
    [bool]$All = $false

    [DscProperty()]
    [Ensure]$Ensure = 'Present'

    [DscProperty()]
    [ValidateSet('CurrentUser', 'AllUsers')]
    [string]$Scope = 'CurrentUser'

    [DscProperty()]
    [bool]$Force = $false

    # Returns the current state of the resource
    [NerdFont] Get() {
        $currentState = [NerdFont]::new()
        $currentState.Name = $this.Name
        $currentState.All = $this.All
        $currentState.Scope = $this.Scope
        $currentState.Force = $this.Force

        # If All is specified, we need to check if all fonts are installed
        if ($this.All) {
            Write-Verbose "Checking if all NerdFonts are installed"
            # Get all available NerdFonts
            $allFonts = Get-NerdFont
            
            # Check if all NerdFonts are installed by sampling a few key fonts
            # This is a simplification - in a real-world scenario, we might want to check all fonts
            $sampleFonts = @('FiraCode', 'Hack', 'JetBrainsMono')
            $installedCount = 0
            
            foreach ($fontName in $sampleFonts) {
                if (Get-Font -Name "$fontName*") {
                    $installedCount++
                }
            }
            
            # If all sampled fonts are installed, we consider all fonts installed
            if ($installedCount -eq $sampleFonts.Count) {
                $currentState.Ensure = 'Present'
            } else {
                $currentState.Ensure = 'Absent'
            }
        } else {
            # Check if the specific font is installed
            Write-Verbose "Checking if NerdFont $($this.Name) is installed"
            if (Get-Font -Name "$($this.Name)*") {
                $currentState.Ensure = 'Present'
            } else {
                $currentState.Ensure = 'Absent'
            }
        }

        return $currentState
    }

    # Tests if the current state matches the desired state
    [bool] Test() {
        $currentState = $this.Get()
        
        # Compare current state with desired state
        if ($currentState.Ensure -eq $this.Ensure) {
            Write-Verbose "NerdFont resource is in desired state."
            return $true
        } else {
            Write-Verbose "NerdFont resource is not in desired state."
            Write-Verbose "Current State: $($currentState.Ensure), Desired State: $($this.Ensure)"
            return $false
        }
    }

    # Sets the resource to the desired state
    [void] Set() {
        if ($this.Test()) {
            Write-Verbose "Resource is already in the desired state."
            return
        }

        # Determine the action needed
        if ($this.Ensure -eq 'Present') {
            Write-Verbose "Installing NerdFont."
            
            $params = @{
                Scope = $this.Scope
                Force = $this.Force
            }

            if ($this.All) {
                Write-Verbose "Installing all NerdFonts."
                $params.Add('All', $true)
            } else {
                Write-Verbose "Installing NerdFont $($this.Name)."
                $params.Add('Name', $this.Name)
            }

            # Install the font(s)
            Install-NerdFont @params
        } else {
            Write-Verbose "Uninstalling NerdFont is not supported."
            Write-Warning "Uninstalling NerdFont is not supported by the underlying module. Use your OS font management tools to remove fonts."
        }
    }
}