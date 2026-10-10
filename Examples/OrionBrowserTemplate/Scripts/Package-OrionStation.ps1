# Copyright (c) 2026 Orion. All Rights Reserved.
[CmdletBinding()]
param(
	[Parameter(Mandatory=$true)][string]$EngineRoot,
	[ValidateSet('Development','Shipping')][string]$Configuration = 'Development'
)
$ErrorActionPreference = 'Stop'
$engine = (Resolve-Path -LiteralPath $EngineRoot).Path
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$projects = @(Get-ChildItem -LiteralPath $projectRoot -Filter '*.uproject' -File)
if ($projects.Count -ne 1) { throw 'The project directory must contain exactly one .uproject.' }
# A plugin copy in the project takes precedence over a Fab installation in the engine.
$pluginRoot = Join-Path $projectRoot 'Plugins/OrionBrowser'
if (!(Test-Path -LiteralPath (Join-Path $pluginRoot 'OrionBrowser.uplugin'))) {
	$marketplace = Join-Path $engine 'Engine/Plugins/Marketplace'
	$descriptors = @()
	if (Test-Path -LiteralPath $marketplace) { $descriptors = @(Get-ChildItem -LiteralPath $marketplace -Filter 'OrionBrowser.uplugin' -File -Recurse) }
	if ($descriptors.Count -ne 1) { throw 'OrionBrowser must be installed once, in project Plugins/OrionBrowser or in the engine Marketplace plugins.' }
	$pluginRoot = $descriptors[0].DirectoryName
}
$entry = Join-Path $pluginRoot 'Scripts/Package-OrionBrowserProject.ps1'
if (!(Test-Path -LiteralPath $entry)) { throw 'The installed OrionBrowser plugin has no Scripts/Package-OrionBrowserProject.ps1.' }
& $entry -EngineRoot $engine -ProjectFile $projects[0].FullName -ArchiveDirectory (Join-Path $projectRoot "Builds/$Configuration") -Configuration $Configuration
exit $LASTEXITCODE
