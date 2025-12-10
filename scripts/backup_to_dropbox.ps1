<#
.SYNOPSIS
  Backup the TrueForeclosure project to a Dropbox folder as a timestamped ZIP.

.DESCRIPTION
  Compresses the `C:\Projects\TrueForeclosure` folder into a timestamped
  ZIP file and moves it to the specified Dropbox destination. Keeps the most
  recent N backups and deletes older ones.

.EXAMPLE
  pwsh -File .\backup_to_dropbox.ps1
  Uses the defaults for source and destination.

.EXAMPLE
  pwsh -File .\backup_to_dropbox.ps1 -Source 'C:\Projects\TrueForeclosure' -Destination 'C:\Users\werkhardor\Dropbox\SmartCities\TrueForeclosure' -Keep 20

#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [string]
    $Source = 'C:\Projects\TrueForeclosure',

    [string]
    $Destination = 'C:\Users\werkhardor\Dropbox\SmartCities\TrueForeclosure',

    [int]
    $Keep = 30
)

function Write-Log {
    param($Message)
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Output "$ts - $Message"
}

try {
    if (-not (Test-Path -Path $Source)) {
        Write-Error "Source folder not found: $Source"
        exit 1
    }

    if (-not (Test-Path -Path $Destination)) {
        if ($PSCmdlet.ShouldProcess("Create folder", $Destination)) {
            New-Item -ItemType Directory -Path $Destination -Force | Out-Null
            Write-Log "Created destination folder: $Destination"
        } else {
            Write-Log "Would create destination folder: $Destination"
        }
    }

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $zipName = "TrueForeclosure_$timestamp.zip"
    $tempZip = Join-Path -Path $env:TEMP -ChildPath $zipName
    $destZip = Join-Path -Path $Destination -ChildPath $zipName

    # Create ZIP archive of the source folder
    if ($PSCmdlet.ShouldProcess("Compress", "$Source -> $tempZip")) {
        Write-Log "Compressing '$Source' to temporary archive '$tempZip'..."
        try {
            Compress-Archive -Path (Join-Path -Path $Source -ChildPath '*') -DestinationPath $tempZip -Force -ErrorAction Stop
            Write-Log "Temporary archive created: $tempZip"
        } catch {
            Write-Error "Failed to create archive: $_"
            if (Test-Path $tempZip) { Remove-Item $tempZip -Force }
            exit 1
        }
    } else {
        Write-Log "Would compress '$Source' to '$tempZip'"
    }

    # Move to final destination
    if (Test-Path -Path $tempZip) {
        if ($PSCmdlet.ShouldProcess("Move", "$tempZip -> $destZip")) {
            Move-Item -Path $tempZip -Destination $destZip -Force
            Write-Log "Moved backup to: $destZip"
        } else {
            Write-Log "Would move '$tempZip' to '$destZip'"
        }
    } else {
        Write-Error "Temporary archive not found: $tempZip"
        exit 1
    }

    # Retention: keep only the newest $Keep backups
    if ($Keep -gt 0) {
        $pattern = 'TrueForeclosure_*.zip'
        $files = Get-ChildItem -Path $Destination -Filter $pattern -File | Sort-Object LastWriteTime -Descending
        $toRemove = $files | Select-Object -Skip $Keep
        if ($toRemove -and $toRemove.Count -gt 0) {
            foreach ($f in $toRemove) {
                if ($PSCmdlet.ShouldProcess("Remove old backup", $f.FullName)) {
                    try {
                        Remove-Item -Path $f.FullName -Force -ErrorAction Stop
                        Write-Log "Removed old backup: $($f.Name)"
                    } catch {
                        Write-Error "Failed to remove $($f.FullName): $_"
                    }
                } else {
                    Write-Log "Would remove old backup: $($f.FullName)"
                }
            }
        } else {
            Write-Log "No old backups to remove (keeping $Keep most recent)."
        }
    }

    Write-Log "Backup completed: $destZip"
    exit 0

} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
