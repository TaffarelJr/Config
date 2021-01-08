# Boxstarter Script to apply standard configuration and install common applications.
# https://boxstarter.org/
#
# Install Boxstarter:
# 	. { iwr -useb https://boxstarter.org/bootstrapper.ps1 } | iex; get-boxstarter -Force
#
# Set: Set-ExecutionPolicy RemoteSigned
# Then: Install-BoxstarterPackage -PackageName <URL-TO-RAW-OR-GIST> -DisableReboots
#
# Pulled from samples by:
# - Microsoft https://github.com/Microsoft/windows-dev-box-setup-scripts
# - elithrar https://github.com/elithrar/dotfiles
# - ElJefeDSecurIT https://gist.github.com/ElJefeDSecurIT/014fcfb87a7372d64934995b5f09683e
# - jessfraz https://gist.github.com/jessfraz/7c319b046daa101a4aaef937a20ff41f
# - NickCraver https://gist.github.com/NickCraver/7ebf9efbfd0c3eab72e9

$unwantedApps = @(
    "*HiddenCity*"
    "*iHeartRadio*"
    "*McAfee*"
    "*Netflix*"
    "*Twitter*"
    "Adobe*"
    "Dell*"
    "Dolby*"
    "Facebook*"
    "Flipboard*"
    "Hulu*"
    "king.com*"
    "Microsoft.3DBuilder*"
    "Microsoft.Bing*"
    "Microsoft.FreshPaint*"
    "Microsoft.GetHelp*"
    "Microsoft.Getstarted*"
    "Microsoft.Messaging*"
    "Microsoft.Microsoft3DViewer*"
    "Microsoft.MicrosoftOfficeHub*"
    "Microsoft.MicrosoftSolitaireCollection*"
    "Microsoft.Minecraft*"
    "Microsoft.MixedReality.Portal*"
    "Microsoft.MSPaint*"
    "Microsoft.NetworkSpeedTest*"
    "Microsoft.Office.OneNote*"
    "Microsoft.Office.Sway*"
    "Microsoft.OneConnect*"
    "Microsoft.Print3D*"
    "Microsoft.SkypeApp*"
    "Microsoft.WindowsAlarms*"
    "Microsoft.WindowsFeedbackHub*"
    "Microsoft.WindowsMaps*"
    "Microsoft.WindowsPhone*"
    "Microsoft.WindowsSoundRecorder*"
    "Microsoft.XboxApp*"
    "Microsoft.XboxIdentityProvider*"
    "Microsoft.Zune*"
    "Pandora*"
    "Roblox*"
    "Spotify*"
)

$indexExtensions = @(
    ".accessor", ".application", ".appref-ms", ".asmx",
    ".cake", ".cd", ".cfg", ".cmproj", ".cmpuo", ".config", ".csdproj", ".csx",
    ".datasource", ".dbml", ".dependencies", ".disco", ".dotfuproj",
    ".gitattributes", ".gitignore", ".gitmodules",
    ".jshtm", ".json", ".jsx",
    ".lock", ".log",
    ".md", ".myapp",
    ".nuspec",
    ".proj", ".ps1", ".psm1",
    ".rdl", ".references", ".resx",
    ".settings", ".sln", ".stvproj", ".suo", ".svc",
    ".testrunconfig", ".text", ".tf", ".tfstate", ".tfvars",
    ".vb", ".vbdproj", ".vddproj", ".vdp", ".vdproj", ".vscontent", ".vsmdi", ".vssettings",
    ".wsdl",
    ".yaml", ".yml",
    ".xaml", ".xbap", ".xproj"
)

#----------------------------------------------------------------------------------------------------
# Pre
#----------------------------------------------------------------------------------------------------

Disable-UAC

#----------------------------------------------------------------------------------------------------
# Disable unneeded services
#----------------------------------------------------------------------------------------------------

Write-Host "Disable uneeded services"

# Security risk; Microsoft recommends removing immediately, to avoid ransomware attacks
# https://www.tenforums.com/tutorials/107605-enable-disable-smb1-file-sharing-protocol-windows.html
Disable-WindowsOptionalFeature -Online -FeatureName "SMB1Protocol" -NoRestart

Set-service -Name "lmhosts"  -StartupType "Disabled" # Don't need NetBIOS over TCP/IP
Set-service -Name "SNMPTRAP" -StartupType "Disabled" # Don't need SNMP
Set-service -Name "TapiSrv"  -StartupType "Disabled" # Don't need Telephony API

#----------------------------------------------------------------------------------------------------
# Prompt the user to pick a name for the computer
#----------------------------------------------------------------------------------------------------

Write-Host "Computer name is: $Env:COMPUTERNAME"
Write-Host "What would you like to rename it to?"
$computerName = Read-Host -Prompt "<press ENTER to skip>"
if ($computerName.Length -gt 0) { Rename-Computer -NewName $computerName }

#----------------------------------------------------------------------------------------------------
# Remove bloatware, so we don't update them
#----------------------------------------------------------------------------------------------------

Write-Host "Remove Windows Bloatware"
$ProgressPreference = "SilentlyContinue" # Need to hide the progress bar as otherwise it remains on the screen

foreach ($app in $unwantedApps) {
    Write-Host "    $app"
    Get-AppxPackage $app -AllUsers | Remove-AppxPackage
    Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like $app | Remove-AppxProvisionedPackage -Online
    Remove-Item "$Env:LOCALAPPDATA\Packages\$app" -Recurse -Force -ErrorAction 0
}

$ProgressPreference = "Continue"

Write-Host "Remove McAfee Security App, if installed"
$mcafee = Get-ChildItem "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall" | `
    ForEach-Object { Get-ItemProperty $_.PSPath } | `
    Where-Object { $_ -match "McAfee Security" } | `
    Select-Object UninstallString
if ($mcafee) {
    $mcafee = $mcafee.UninstallString -Replace "C:\Program Files\McAfee\MSC\mcuihost.exe", ""
    Write-Output "Uninstalling McAfee..."
    start-process "C:\Program Files\McAfee\MSC\mcuihost.exe" -arg "$mcafee" -Wait
}

#----------------------------------------------------------------------------------------------------
# Install Windows Updates, so everything's current
#----------------------------------------------------------------------------------------------------

Install-WindowsUpdate -AcceptEula

# Runs asynchronously (not blocking)
Write-Host "Update Windows Store applications"
(Get-WmiObject -Namespace "root\cimv2\mdm\dmmap" -Class "MDM_EnterpriseModernAppManagement_AppManagement01").UpdateScanMethod()

#----------------------------------------------------------------------------------------------------
# Configure Windows Explorer
#----------------------------------------------------------------------------------------------------

Write-Host "Configure Windows Explorer"
Push-Location -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\"; & {
    Push-Location -Path ".\Advanced\"; & {
        Set-ItemProperty -Path "." -Name "HideDrivesWithNoMedia"      -Type "DWord" -Value "0" # Show empty drives
        Set-ItemProperty -Path "." -Name "HideMergeConflicts"         -Type "DWord" -Value "0" # Show folder merge conflicts
        Set-ItemProperty -Path "." -Name "SeparateProcess"            -Type "DWord" -Value "1" # Launch folder windows in a separate process
        Set-ItemProperty -Path "." -Name "PersistBrowsers"            -Type "DWord" -Value "1" # Restore previous folder windows at logon
        Set-ItemProperty -Path "." -Name "ShowEncryptCompressedColor" -Type "DWord" -Value "1" # Show encrypted or compressed NTFS files in color
        Set-ItemProperty -Path "." -Name "NavPaneShowAllFolders"      -Type "DWord" -Value "1" # Show all folders
    }; Pop-Location
    Push-Location -Path ".\Search\"; & {
        Set-ItemProperty -Path ".\Preferences\"                          -Name "ArchivedFiles" -Type "DWord" -Value "1" # Include compressed files (ZIP, CAB...)
        Set-ItemProperty -Path ".\PrimaryProperties\UnindexedLocations\" -Name "SearchOnly"    -Type "DWord" -Value "0" # Always search file names and contents
    }; Pop-Location
}; Pop-Location

Set-WindowsExplorerOptions `
    -DisableOpenFileExplorerToQuickAccess `
    -EnableShowRecentFilesInQuickAccess `
    -EnableShowFrequentFoldersInQuickAccess `
    -EnableShowFullPathInTitleBar `
    -EnableShowHiddenFilesFoldersDrives `
    -EnableShowFileExtensions `
    -DisableShowProtectedOSFiles `
    -EnableExpandToOpenFolder `
    -EnableShowRibbon `
    -EnableSnapAssist

Disable-BingSearch

#----------------------------------------------------------------------------------------------------
# Disable Xbox Gamebar
#----------------------------------------------------------------------------------------------------

Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Type "DWord" -Value "0"
Set-ItemProperty -Path "HKCU:\System\GameConfigStore"                            -Name "GameDVR_Enabled"   -Type "DWord" -Value "0"

Disable-GameBarTips

#----------------------------------------------------------------------------------------------------
# Configure Windows Search file extensions
#----------------------------------------------------------------------------------------------------

Write-Host "Configure Windows Search file extensions"
New-PSDrive -Name "HKCR" -PSProvider "Registry" -Root "HKEY_CLASSES_ROOT" | out-null

Push-Location -Path "HKCR:\"; & {
    foreach ($extension in $indexExtensions) {
        Write-Host "    $extension"
        $regPath = "HKCR:\$extension\PersistentHandler\"
        New-Item $regPath -Force | Out-Null
        Push-Location -Path $regPath; & {
            Set-ItemProperty -Path "." -Name "(Default)"                 -Type "String" -Value "{5E941D80-BF96-11CD-B579-08002B30BFEB}"
            Set-ItemProperty -Path "." -Name "OriginalPersistentHandler" -Type "String" -Value "{00000000-0000-0000-0000-000000000000}"
        }; Pop-Location
    }
}; Pop-Location

#----------------------------------------------------------------------------------------------------
# Unlock Group Policy settings (Windows 10 Pro only)
#----------------------------------------------------------------------------------------------------

Push-Location -Path "HKLM:\SOFTWARE\Policies\Microsoft\"; & {
    # Microsoft OneDrive
    $regPath = ".\Windows\OneDrive\"
    if (Test-Path $regPath) {
        Write-Host "Unlock Microsoft OneDrive"
        Push-Location -Path $regPath; & {
            Set-ItemProperty -Path "." -Name "DisableFileSync"     -Type "DWord" -Value "0" # Enable file sync
            Set-ItemProperty -Path "." -Name "DisableFileSyncNGSC" -Type "DWord" -Value "0" # Enable file sync (next-gen)
        }; Pop-Location
    }

    # Windows Store
    $regPath = ".\WindowsStore\"
    if (Test-Path $regPath) {
        Write-Host "Unlock Windows Store"
        Push-Location -Path $regPath; & {
            Set-ItemProperty -Path "." -Name "DisableStoreApps"        -Type "DWord" -Value "0" # Enable Store apps
            Set-ItemProperty -Path "." -Name "RemoveWindowsStore"      -Type "DWord" -Value "0" # Do not remove Windows Store
            Set-ItemProperty -Path "." -Name "RequirePrivateStoreOnly" -Type "DWord" -Value "0" # Do not require private Store only
        }; Pop-Location
    }
}; Pop-Location

#----------------------------------------------------------------------------------------------------
# Move library folders to OneDrive
#----------------------------------------------------------------------------------------------------

Write-Host "Move library directories"
Move-LibraryDirectory -libraryName "Desktop"     -newPath "$Env:OneDrive\Desktop"
Move-LibraryDirectory -libraryName "Downloads"   -newPath "$Env:OneDrive\Downloads"
Move-LibraryDirectory -libraryName "My Music"    -newPath "$Env:OneDrive\Music"
Move-LibraryDirectory -libraryName "My Pictures" -newPath "$Env:OneDrive\Pictures"
Move-LibraryDirectory -libraryName "My Video"    -newPath "$Env:OneDrive\Videos"
Move-LibraryDirectory -libraryName "Personal"    -newPath "$Env:OneDrive\Documents"

#----------------------------------------------------------------------------------------------------
# Post
#----------------------------------------------------------------------------------------------------

Enable-UAC
Enable-MicrosoftUpdate
Install-WindowsUpdate -acceptEula
