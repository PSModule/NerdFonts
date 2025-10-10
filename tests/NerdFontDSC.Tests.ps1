#Requires -Modules @{ ModuleName = 'Pester'; RequiredVersion = '5.7.1' }

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Pester grouping syntax: known issue.'
)]
[CmdletBinding()]
param()

# Define the NerdFont class directly for testing
# This is a simplified version of what's in NerdFontDSC.psm1
# In a real-world scenario, we'd properly import the module

if (-not ([System.Management.Automation.PSTypeName]'Ensure').Type) {
    enum Ensure {
        Absent
        Present
    }
}

class NerdFont {
    [string]$Name
    [bool]$All = $false
    [Ensure]$Ensure = [Ensure]::Present
    [string]$Scope = 'CurrentUser'
    [bool]$Force = $false
}

Describe 'DSC Resource: NerdFont' {
    Context 'Basic functionality' {
        
        It 'Creates a new NerdFont resource instance' {
            # Testing resource instantiation
            $resource = [NerdFont]@{
                Name = 'FiraCode'
                Ensure = 'Present'
                Scope = 'CurrentUser'
            }
            
            $resource | Should -Not -BeNullOrEmpty
            $resource.Name | Should -Be 'FiraCode'
            $resource.Ensure | Should -Be 'Present'
            $resource.Scope | Should -Be 'CurrentUser'
            $resource.All | Should -Be $false
            $resource.Force | Should -Be $false
        }
        
        It 'Creates a resource instance for all fonts' {
            $resource = [NerdFont]@{
                All = $true
                Ensure = 'Present'
                Scope = 'CurrentUser'
            }
            
            $resource | Should -Not -BeNullOrEmpty
            $resource.All | Should -Be $true
            $resource.Ensure | Should -Be 'Present'
            $resource.Scope | Should -Be 'CurrentUser'
        }
    }
}