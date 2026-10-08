# Copyright (c) 2026 Orion. All Rights Reserved.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$EngineRoot)
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
& (Join-Path $projectRoot 'Plugins/OrionBrowser/Scripts/Package-OrionBrowserProject.ps1') -EngineRoot $EngineRoot -ProjectFile (Join-Path $projectRoot 'OrionBrowserTemplate.uproject') -ArchiveDirectory (Join-Path $projectRoot 'Builds/Development') -Configuration Development
exit $LASTEXITCODE
