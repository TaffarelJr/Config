"$PSScriptRoot\..\..\Modules\*.psm1" | Get-ChildItem | Import-Module -Force
Initialize-Environment

#-------------------------------------------------------------------------------
Start-ComponentGroup 'Source Control Tools'
#-------------------------------------------------------------------------------

. "$PSScriptRoot\Git.ps1"
