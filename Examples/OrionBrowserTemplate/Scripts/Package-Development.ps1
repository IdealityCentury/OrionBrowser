# Copyright (c) 2026 Orion. All Rights Reserved.
[CmdletBinding()]
param(
	[Parameter(Mandatory=$true)][string]$EngineRoot
)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'Package-OrionStation.ps1') -EngineRoot $EngineRoot -Configuration Development
exit $LASTEXITCODE
