#Requires -Version 5.1

function Show-Banner {
    $duck1 = @"
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣴⣿⣿⣿⣿⣦⡀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⡏⠉⢻⣷⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢿⣿⣿⣿⣿⣾⣿⣿⣶⣶⣶⣦⣤⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⣿⣿⣿⣿⣿⣿⠏⠉⠉⠉⠁⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⣿⣿⣿⠿⠟⠀⠀⠀⠀⠀⠀⠀⠀
"@

    $duck2 = @"
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣀⣤⣤⣤⣤⣤⣶⣾⣷⣄⠀⠀⠀⠀⠀
⠀⠀⣶⣤⣤⣤⣤⣤⣤⣶⣶⣶⣿⣿⣿⣿⣿⣿⣿⣿⠛⢻⣿⣿⣿⡆⠀⠀⠀⠀
⠀⠀⢹⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠏⢀⣿⣿⣿⣿⡇⠀⠀⠀⠀
⠀⠀⠈⢿⣿⣿⣏⡈⠛⠿⠿⣿⣿⣿⠿⠿⠟⠋⣁⣴⣿⣿⣿⣿⣿⠃⠀⠀⠀⠀
⠀⠀⠀⠀⠙⠿⣿⣿⣶⣦⣤⣤⣤⣤⣤⣴⣶⣿⣿⣿⣿⣿⣿⡿⠏⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠈⠙⠛⠻⠿⠿⠿⢿⡿⠿⠿⠿⠟⠛⠉⠁⠀⠀⠀⠀⠀⠀⠀
"@

    $duck3 = @"
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢰⡄⢠⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣼⣧⣾⣶⣤⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠉⠉⠉⠉⠉⠉⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
"@

    Write-Host $duck1 -ForegroundColor Yellow
    Write-Host $duck2 -ForegroundColor White
    Write-Host $duck3 -ForegroundColor Yellow
    
    Write-Host ""
    Write-Host "                    Made by " -NoNewline
    Write-Host "iTake (@cheatinformer) " -NoNewline -ForegroundColor White
    Write-Host "@" -NoNewline -ForegroundColor Blue
    Write-Host " FM Forensics" -ForegroundColor Red
    Write-Host ""
    Write-Host "                    Doomsday Client Scanner v1.2 (USN Journal)" -ForegroundColor Cyan
    Write-Host ""
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Global debug flag
$script:DebugMode = $false
$script:CheckUSN = $true

# Cache for USN journal data
$script:RecentDeletions = @{}
$script:USNSearched = $false

function Get-NTFSDrives {
    $ntfsDrives = @()
    
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Z]:\\$' }
    
    foreach ($drive in $drives) {
        try {
            $driveLetter = $drive.Root.Substring(0, 2)
            
            # Check if drive is NTFS
            $volume = Get-Volume -DriveLetter $driveLetter[0] -ErrorAction SilentlyContinue
            
            if ($volume -and $volume.FileSystem -eq 'NTFS') {
                $ntfsDrives += $driveLetter[0]
            }
        }
        catch {
            # Skip drives that can't be accessed
            continue
        }
    }
    
    return $ntfsDrives
}

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class NtdllDecompressor {
    [DllImport("ntdll.dll")]
    public static extern uint RtlDecompressBufferEx(
        ushort CompressionFormat,
        byte[] UncompressedBuffer,
        int UncompressedBufferSize,
        byte[] CompressedBuffer,
        int CompressedBufferSize,
        out int FinalUncompressedSize,
        IntPtr WorkSpace
    );
    
    [DllImport("ntdll.dll")]
    public static extern uint RtlGetCompressionWorkSpaceSize(
        ushort CompressionFormat,
        out uint CompressBufferWorkSpaceSize,
        out uint CompressFragmentWorkSpaceSize
    );
    
    public static byte[] Decompress(byte[] compressed) {
        if (compressed.Length < 8) return null;
        if (compressed[0] != 0x4D || compressed[1] != 0x41 || compressed[2] != 0x4D) {
            return null;
        }
        
        int uncompSize = BitConverter.ToInt32(compressed, 4);
        
        uint wsComp, wsFrag;
        if (RtlGetCompressionWorkSpaceSize(4, out wsComp, out wsFrag) != 0) return null;
        
        IntPtr workspace = Marshal.AllocHGlobal((int)wsFrag);
        byte[] result = new byte[uncompSize];
        
        try {
            int finalSize;
            byte[] compData = new byte[compressed.Length - 8];
            Array.Copy(compressed, 8, compData, 0, compData.Length);
            
            uint status = RtlDecompressBufferEx(4, result, uncompSize, 
                compData, compData.Length, out finalSize, workspace);
            
            if (status != 0) return null;
            return result;
        }
        finally {
            Marshal.FreeHGlobal(workspace);
        }
    }
}
"@

function Get-RecentDeletionsFromUSN {
    param(
        [string[]]$DriveLetters,
        [int]$MinutesBack = 30
    )
    
    if ($script:USNSearched) {
        return $script:RecentDeletions
    }
    
    $allRecentActivity = @{}
    
    foreach ($driveLetter in $DriveLetters) {
        try {
            Write-Host "[*] Scanning drive $driveLetter`: for recent file activity (last $MinutesBack minutes)..." -ForegroundColor Cyan
            
            $cutoffTime = (Get-Date).AddMinutes(-$MinutesBack)
            
            # Run fsutil to get USN journal
            $usnOutput = & fsutil usn readjournal "$driveLetter`:" 2>$null
            
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[!] Unable to read USN Journal on drive $driveLetter`: (may be disabled)" -ForegroundColor Yellow
                continue
            }
            
            $totalLines = $usnOutput.Count
            
            if ($totalLines -eq 0) {
                Write-Host "[!] No USN Journal data on drive $driveLetter`:" -ForegroundColor Yellow
                continue
            }
            
            $recentActivity = @{}
            $activityCount = 0
            $currentFile = ""
            $currentTime = $null
            $currentReason = ""
            $entriesProcessed = 0
            
            foreach ($line in $usnOutput) {
                # Skip empty lines
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                
                # Look for "File name" line (with variable spacing)
                if ($line -match 'File name\s+:\s*(.+)$') {
                    $currentFile = $Matches[1].Trim()
                }
                # Look for "Time stamp" line (with variable spacing)
                elseif ($line -match 'Time stamp\s+:\s*(.+)$') {
                    $timeStr = $Matches[1].Trim()
                    try {
                        $currentTime = [DateTime]::Parse($timeStr)
                    } catch {
                        $currentTime = $null
                    }
                }
                # Look for "Reason" line - accept ANY reason
                elseif ($line -match 'Reason\s+:\s*(.+)$') {
                    $entriesProcessed++
                    $currentReason = $Matches[1].Trim()
                    
                    # Check if this entry is within our time window (ANY reason)
                    if ($currentFile -and $currentTime -and $currentTime -gt $cutoffTime) {
                        # Store with drive letter prefix to avoid collisions
                        $fullKey = "$driveLetter`:\$currentFile"
                        
                        # If file appears multiple times, keep the most recent
                        if (-not $recentActivity.ContainsKey($fullKey) -or 
                            $recentActivity[$fullKey].Timestamp -lt $currentTime) {
                            
                            $recentActivity[$fullKey] = @{
                                Timestamp = $currentTime
                                Reason = $currentReason
                                Drive = $driveLetter
                            }
                            
                            $activityCount++
                        }
                    }
                    
                    # Reset for next entry
                    $currentFile = ""
                    $currentTime = $null
                    $currentReason = ""
                }
            }
            
            Write-Host "[+] Drive $driveLetter`: - Found $activityCount files with recent activity" -ForegroundColor Green
            
            # Merge into overall activity
            foreach ($key in $recentActivity.Keys) {
                $allRecentActivity[$key] = $recentActivity[$key]
            }
            
        }
        catch {
            Write-Host "[!] Error reading USN Journal on drive $driveLetter`: - $_" -ForegroundColor Yellow
            continue
        }
    }
    
    $script:RecentDeletions = $allRecentActivity
    $script:USNSearched = $true
    
    Write-Host ""
    Write-Host "[+] Total unique files with recent activity across all drives: $($allRecentActivity.Count)" -ForegroundColor Green
    Write-Host ""
    
    return $allRecentActivity
}

function Test-RecentlyDeleted {
    param(
        [string]$FilePath
    )
    
    # Try full path match first
    if ($script:RecentDeletions.ContainsKey($FilePath)) {
        return $script:RecentDeletions[$FilePath]
    }
    
    # Try just filename
    $fileName = [System.IO.Path]::GetFileName($FilePath)
    
    # Check if any key ends with this filename
    foreach ($key in $script:RecentDeletions.Keys) {
        if ($key -like "*\$fileName") {
            return $script:RecentDeletions[$key]
        }
    }
    
    return $null
}

function Get-PrefetchVersion {
    param([byte[]]$data)
    
    if ($data.Length -lt 8) { return 0 }
    
    # Check for SCCA signature at offset 4
    $sig = [System.Text.Encoding]::ASCII.GetString($data, 4, 4)
    if ($sig -ne "SCCA") { return 0 }
    
    # Version is at offset 0
    $version = [BitConverter]::ToUInt32($data, 0)
    return $version
}

function Get-SystemIndexes {
    param([string]$FilePath)
    
    try {
        $data = [System.IO.File]::ReadAllBytes($FilePath)
        
        if ($script:DebugMode) {
            Write-Host "  [DEBUG] File: $([System.IO.Path]::GetFileName($FilePath))" -ForegroundColor Magenta
            Write-Host "  [DEBUG] Raw size: $($data.Length) bytes" -ForegroundColor Magenta
        }
        
        $isCompressed = ($data[0] -eq 0x4D -and $data[1] -eq 0x41 -and $data[2] -eq 0x4D)
        
        if ($script:DebugMode) {
            Write-Host "  [DEBUG] Compressed: $isCompressed" -ForegroundColor Magenta
        }
        
        if ($isCompressed) {
            $data = [NtdllDecompressor]::Decompress($data)
            if ($data -eq $null) {
                Write-Warning "Failed to decompress: $FilePath"
                return @()
            }
            
            if ($script:DebugMode) {
                Write-Host "  [DEBUG] Decompressed size: $($data.Length) bytes" -ForegroundColor Magenta
            }
        }
        
        # Validate minimum size
        if ($data.Length -lt 108) {
            Write-Warning "File too small after decompression: $FilePath"
            return @()
        }
        
        # Get prefetch version
        $version = Get-PrefetchVersion -data $data
        
        if ($script:DebugMode) {
            Write-Host "  [DEBUG] Prefetch version: $version" -ForegroundColor Magenta
        }
        
        $sig = [System.Text.Encoding]::ASCII.GetString($data, 4, 4)
        if ($sig -ne "SCCA") {
            Write-Warning "Invalid file signature: $FilePath (got: $sig)"
            return @()
        }
        
        # Handle different prefetch versions
        # Version 17 = XP/2003, 23 = Vista/7, 26 = Win8.1, 30 = Win10, 31 = Win11
        $stringsOffset = 0
        $stringsSize = 0
        
        switch ($version) {
            17 {
                # Windows XP/2003
                $stringsOffset = [BitConverter]::ToUInt32($data, 100)
                $stringsSize = [BitConverter]::ToUInt32($data, 104)
            }
            23 {
                # Windows Vista/7
                $stringsOffset = [BitConverter]::ToUInt32($data, 100)
                $stringsSize = [BitConverter]::ToUInt32($data, 104)
            }
            26 {
                # Windows 8.1
                $stringsOffset = [BitConverter]::ToUInt32($data, 100)
                $stringsSize = [BitConverter]::ToUInt32($data, 104)
            }
            30 {
                # Windows 10
                $stringsOffset = [BitConverter]::ToUInt32($data, 100)
                $stringsSize = [BitConverter]::ToUInt32($data, 104)
            }
            31 {
                # Windows 11
                $stringsOffset = [BitConverter]::ToUInt32($data, 100)
                $stringsSize = [BitConverter]::ToUInt32($data, 104)
            }
            default {
                Write-Warning "Unknown prefetch version $version for: $FilePath"
                # Try default offsets anyway
                $stringsOffset = [BitConverter]::ToUInt32($data, 100)
                $stringsSize = [BitConverter]::ToUInt32($data, 104)
            }
        }
        
        if ($script:DebugMode) {
            Write-Host "  [DEBUG] Strings offset: $stringsOffset" -ForegroundColor Magenta
            Write-Host "  [DEBUG] Strings size: $stringsSize" -ForegroundColor Magenta
        }
        
        # Validate offsets
        if ($stringsOffset -eq 0 -or $stringsSize -eq 0) {
            Write-Warning "Invalid string section offsets: $FilePath"
            return @()
        }
        
        if ($stringsOffset -ge $data.Length -or ($stringsOffset + $stringsSize) -gt $data.Length) {
            Write-Warning "String section out of bounds: $FilePath (offset: $stringsOffset, size: $stringsSize, data: $($data.Length))"
            return @()
        }
        
        $filenames = @()
        $pos = $stringsOffset
        $endPos = $stringsOffset + $stringsSize
        
        while ($pos -lt $endPos -and $pos -lt $data.Length - 2) {
            $nullPos = $pos
            while ($nullPos -lt $data.Length - 1) {
                if ($data[$nullPos] -eq 0 -and $data[$nullPos + 1] -eq 0) {
                    break
                }
                $nullPos += 2
            }
            
            if ($nullPos -gt $pos) {
                $strLen = $nullPos - $pos
                if ($strLen -gt 0 -and $strLen -lt 2048) {
                    try {
                        $filename = [System.Text.Encoding]::Unicode.GetString($data, $pos, $strLen)
                        if ($filename.Length -gt 0) {
                            $filenames += $filename
                        }
                    }
                    catch { }
                }
            }
            
            $pos = $nullPos + 2
            
            if ($filenames.Count -gt 1000) { break }
        }
        
        if ($script:DebugMode) {
            Write-Host "  [DEBUG] Extracted $($filenames.Count) filenames" -ForegroundColor Magenta
        }
        
        return $filenames
    }
    catch {
        Write-Warning "Error parsing $FilePath : $_"
        if ($script:DebugMode) {
            Write-Host "  [DEBUG] Exception: $($_.Exception.GetType().Name)" -ForegroundColor Red
            Write-Host "  [DEBUG] Message: $($_.Exception.Message)" -ForegroundColor Red
        }
        return @()
    }
}

function Test-FileInSizeRange {
    param(
        [string]$Path,
        [long]$MinBytes = 200KB,
        [long]$MaxBytes = 15MB
    )
    
    if (-not (Test-Path $Path -PathType Leaf)) {
        return $false
    }
    
    try {
        $size = (Get-Item $Path -ErrorAction Stop).Length
        return ($size -ge $MinBytes -and $size -le $MaxBytes)
    }
    catch {
        return $false
    }
}

$script:BytePatterns = @(
    @{
        Name = "Pattern #1"
        Bytes = "6161370E160609949E0029033EA7000A2C1D03548403011D1008A1FFF6033EA7000A2B1D03548403011D07A1FFF710FEAC150599001A2A160C14005C6588B800"
    },
    @{
        Name = "Pattern #2"
        Bytes = "0C1504851D85160A6161370E160609949E0029033EA7000A2C1D03548403011D1008A1FFF6033EA7000A2B1D03548403011D07A1FFF710FEAC150599001A2A16"
    },
    @{
        Name = "Pattern #3"
        Bytes = "5910071088544C2A2BB8004D3B033DA7000A2B1C03548402011C1008A1FFF61A9E000C1A110800A2000503AC04AC00000000000A0005004E000101FA000001D3"
    }
)

$script:ClassPatterns = @(
    "net/java/f",
    "net/java/g",
    "net/java/h",
    "net/java/i",
    "net/java/k",
    "net/java/l",
    "net/java/m",
    "net/java/r",
    "net/java/s",
    "net/java/t",
    "net/java/y"
)

function ConvertHex-ToBytes {
    param([string]$hexString)
    
    $bytes = New-Object byte[] ($hexString.Length / 2)
    for ($i = 0; $i -lt $hexString.Length; $i += 2) {
        $bytes[$i / 2] = [Convert]::ToByte($hexString.Substring($i, 2), 16)
    }
    return $bytes
}

function Search-BytePattern {
    param(
        [byte[]]$data,
        [byte[]]$pattern
    )
    
    $patternLength = $pattern.Length
    $dataLength = $data.Length
    
    for ($i = 0; $i -le ($dataLength - $patternLength); $i++) {
        $match = $true
        for ($j = 0; $j -lt $patternLength; $j++) {
            if ($data[$i + $j] -ne $pattern[$j]) {
                $match = $false
                break
            }
        }
        if ($match) {
            return $true
        }
    }
    return $false
}

function Search-ClassPattern {
    param(
        [byte[]]$data,
        [string]$className
    )
    
    $classBytes = [System.Text.Encoding]::ASCII.GetBytes($className)
    return Search-BytePattern -data $data -pattern $classBytes
}

function Test-ZipMagicBytes {
    param([string]$Path)
    
    try {
        $fileStream = [System.IO.File]::OpenRead($Path)
        $reader = New-Object System.IO.BinaryReader($fileStream)
        
        if ($fileStream.Length -lt 2) {
            $reader.Close()
            $fileStream.Close()
            return $false
        }
        
        $byte1 = $reader.ReadByte()
        $byte2 = $reader.ReadByte()
        
        $reader.Close()
        $fileStream.Close()
        
        return ($byte1 -eq 0x50 -and $byte2 -eq 0x4B)
        
    } catch {
        return $false
    }
}

function Find-SingleLetterClasses {
    param([string]$Path)
    
    $singleLetterClasses = @()
    
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        
        $jar = [System.IO.Compression.ZipFile]::OpenRead($Path)
        
        foreach ($entry in $jar.Entries) {
            if ($entry.FullName -like "*.class") {
                $className = $entry.FullName
                
                $parts = $className -split '/'
                $filename = $parts[-1]
                
                $classNameOnly = $filename -replace '\.class$', ''
                
                if ($classNameOnly -match '^[a-zA-Z]$') {
                    $fullPath = ($parts[0..($parts.Length-2)] -join '/') + '/' + $classNameOnly
                    $singleLetterClasses += $fullPath
                }
            }
        }
        
        $jar.Dispose()
        
    } catch {
    }
    
    return $singleLetterClasses
}

function Test-DoomsdayClient {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    $result = [PSCustomObject]@{
        IsDetected = $false
        Confidence = "NONE"
        BytePatternMatches = @()
        ClassNameMatches = @()
        SingleLetterClasses = @()
        IsRenamedJar = $false
        Error = $null
    }
    
    if (-not (Test-Path $Path -PathType Leaf)) {
        $result.Error = "File not found"
        return $result
    }
    
    try {
        $fileExtension = [System.IO.Path]::GetExtension($Path).ToLower()
        
        $hasPKHeader = Test-ZipMagicBytes -Path $Path
        
        if ($hasPKHeader -and $fileExtension -ne ".jar") {
            $result.IsRenamedJar = $true
            $result.IsDetected = $true
            $result.Confidence = "HIGH"
        }
        
        if (-not $hasPKHeader) {
            $result.Error = "File is not a JAR/ZIP file (missing PK header)"
            return $result
        }
        
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        
        $jar = [System.IO.Compression.ZipFile]::OpenRead($Path)
        
        $classFiles = $jar.Entries | Where-Object { $_.FullName -like "*.class" }
        $classCount = $classFiles.Count
        
        if ($classCount -gt 30) {
            $jar.Dispose()
            $result.Error = "Skipped: Too many classes ($classCount) - likely legitimate library"
            return $result
        }
        
        if ($classCount -eq 0) {
            $jar.Dispose()
            $result.Error = "No .class files found in JAR"
            return $result
        }
        
        $allBytes = @()
        
        foreach ($entry in $classFiles) {
            $stream = $entry.Open()
            $reader = New-Object System.IO.BinaryReader($stream)
            $bytes = $reader.ReadBytes([int]$entry.Length)
            $allBytes += $bytes
            $reader.Close()
            $stream.Close()
        }
        
        $jar.Dispose()
        
        foreach ($pattern in $script:BytePatterns) {
            $patternBytes = ConvertHex-ToBytes -hexString $pattern.Bytes
            
            if (Search-BytePattern -data $allBytes -pattern $patternBytes) {
                $result.BytePatternMatches += $pattern.Name
            }
        }
        
        foreach ($className in $script:ClassPatterns) {
            if (Search-ClassPattern -data $allBytes -className $className) {
                $result.ClassNameMatches += $className
            }
        }
        
        $result.SingleLetterClasses = Find-SingleLetterClasses -Path $Path
        
        $byteMatchCount = $result.BytePatternMatches.Count
        $classMatchCount = $result.ClassNameMatches.Count
        $singleLetterCount = $result.SingleLetterClasses.Count
        
        if ($byteMatchCount -ge 2) {
            $result.IsDetected = $true
            $result.Confidence = "HIGH"
        }
        elseif ($byteMatchCount -eq 1 -and ($classMatchCount -ge 5 -or $singleLetterCount -ge 5)) {
            $result.IsDetected = $true
            $result.Confidence = "MEDIUM"
        }
        elseif ($byteMatchCount -eq 1) {
            $result.IsDetected = $true
            $result.Confidence = "LOW"
        }
        elseif ($singleLetterCount -ge 8 -and $classMatchCount -ge 3) {
            $result.IsDetected = $true
            $result.Confidence = "MEDIUM"
        }
        elseif ($singleLetterCount -ge 5 -or $classMatchCount -ge 5) {
            $result.IsDetected = $true
            $result.Confidence = "LOW"
        }
        
        if ($result.IsRenamedJar -and $result.Confidence -eq "NONE") {
            $result.Confidence = "MEDIUM"
        }
        
    } catch {
        $result.Error = $_.Exception.Message
    }
    
    return $result
}

function Start-DoomsdayScan {
    param(
        [switch]$Debug
    )
    
    $script:DebugMode = $Debug
    
    Show-Banner
    
    if (-not (Test-Administrator)) {
        Write-Host ""
        Write-Host "ERROR: " -ForegroundColor Red -NoNewline
        Write-Host "Administrator privileges required!"
        Write-Host ""
        Write-Host "Please launch CMD or PowerShell as admin!" -ForegroundColor Yellow
        Write-Host ""
        return
    }
    
    # Detect Windows version
    $osVersion = [System.Environment]::OSVersion.Version
    Write-Host "[*] Windows Version: $($osVersion.Major).$($osVersion.Minor) Build $($osVersion.Build)" -ForegroundColor Cyan
    
    if ($osVersion.Major -eq 10) {
        if ($osVersion.Build -ge 22000) {
            Write-Host "[*] Detected: Windows 11" -ForegroundColor Green
        } else {
            Write-Host "[*] Detected: Windows 10" -ForegroundColor Green
        }
    }
    Write-Host ""
    
    Write-Host "[*] Extracting file indexes..." -ForegroundColor Cyan
    Write-Host ""
    
    $systemPath = "C:\Windows\" + "Pre" + "fetch"
    
    if (-not (Test-Path $systemPath)) {
        Write-Host "[!] Prefetch directory not found: $systemPath" -ForegroundColor Red
        return
    }
    
    $javaFiles = Get-ChildItem -Path $systemPath -Filter "JAVA*.EXE-*.pf" -ErrorAction SilentlyContinue
    
    if ($javaFiles.Count -eq 0) {
        Write-Host "[!] No JAVA prefetch files found in $systemPath" -ForegroundColor Yellow
        Write-Host "[*] This could mean:" -ForegroundColor Yellow
        Write-Host "    - Java has never been run on this system" -ForegroundColor Gray
        Write-Host "    - Prefetch files have been cleared" -ForegroundColor Gray
        Write-Host "    - Prefetch is disabled" -ForegroundColor Gray
        return
    }
    
    Write-Host "[+] Found $($javaFiles.Count) JAVA prefetch file(s)" -ForegroundColor Green
    Write-Host ""
    
    $allJarPaths = @()
    $fileMetadata = @{}
    $processedFiles = 0
    $successfulParsing = 0
    
    foreach ($sysFile in $javaFiles) {
        $processedFiles++
        Write-Progress -Activity "Extracting Indexes" `
                      -Status "Processing file $processedFiles of $($javaFiles.Count)" `
                      -PercentComplete (($processedFiles / $javaFiles.Count) * 100)
        
        if ($script:DebugMode) {
            Write-Host ""
            Write-Host "[DEBUG] ======================================" -ForegroundColor Magenta
        }
        
        $indexes = Get-SystemIndexes -FilePath $sysFile.FullName
        
        if ($indexes.Count -eq 0) {
            if ($script:DebugMode) {
                Write-Host "  [DEBUG] No indexes extracted from $($sysFile.Name)" -ForegroundColor Yellow
            }
            continue
        }
        
        $successfulParsing++
        
        if ($script:DebugMode) {
            Write-Host "  [DEBUG] Successfully extracted $($indexes.Count) paths" -ForegroundColor Green
        }
        
        $indexNum = 0
        foreach ($index in $indexes) {
            $indexNum++
            
            # Strip volume GUID if present, assume C: drive initially
            if ($index -match '\\VOLUME\{[^\}]+\}\\(.*)$') {
                $relativePath = $Matches[1]
                $assumedPath = "C:\$relativePath"
                $allJarPaths += $assumedPath
                
                if (-not $fileMetadata.ContainsKey($assumedPath)) {
                    $fileMetadata[$assumedPath] = @{
                        SourceFile = $sysFile.Name
                        IndexNumber = $indexNum
                        OriginalPath = $index
                    }
                }
            }
            else {
                # No volume GUID, use path as-is
                $allJarPaths += $index
                
                if (-not $fileMetadata.ContainsKey($index)) {
                    $fileMetadata[$index] = @{
                        SourceFile = $sysFile.Name
                        IndexNumber = $indexNum
                        OriginalPath = $index
                    }
                }
            }
        }
    }
    
    Write-Progress -Activity "Extracting Indexes" -Completed
    
    Write-Host ""
    Write-Host "[+] Prefetch files successfully parsed: $successfulParsing / $processedFiles" -ForegroundColor Green
    Write-Host "[+] Total file paths extracted: $($allJarPaths.Count)" -ForegroundColor Green
    
    if ($allJarPaths.Count -eq 0) {
        Write-Host ""
        Write-Host "[!] No file paths could be extracted from prefetch files" -ForegroundColor Yellow
        Write-Host "[*] Possible issues:" -ForegroundColor Yellow
        Write-Host "    - Prefetch parsing failed (incompatible format)" -ForegroundColor Gray
        Write-Host "    - No Java applications with file references" -ForegroundColor Gray
        Write-Host ""
        Write-Host "[*] Try running with -Debug flag for more information:" -ForegroundColor Cyan
        Write-Host "    .\doomsday-scanner-usn.ps1 -Debug" -ForegroundColor White
        return
    }
    
    $uniquePaths = $allJarPaths | Select-Object -Unique
    Write-Host "[+] Unique files to scan: $($uniquePaths.Count)" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "[*] Checking file existence across all drives..." -ForegroundColor Cyan
    Write-Host ""
    
    $existingPaths = @{}  # Store path -> actual location
    $trulyMissingPaths = @()
    $checkCount = 0
    $outsideRangeCount = 0
    $resolvedToDifferentDrive = 0
    
    # Get all available drives
    $allDrives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Z]:\\$' } | ForEach-Object { $_.Root.Substring(0, 1) }
    
    foreach ($path in $uniquePaths) {
        $checkCount++
        
        $foundPath = $null
        
        # First, check if file exists at the given path (usually C:)
        if (Test-Path $path -PathType Leaf) {
            $foundPath = $path
        }
        else {
            # File doesn't exist at assumed location
            # Try to find it on other drives
            if ($path -match '^[A-Z]:\\(.*)$') {
                $relativePath = $Matches[1]
                
                # Try each drive
                foreach ($drive in $allDrives) {
                    $testPath = "$drive`:\$relativePath"
                    
                    if (Test-Path $testPath -PathType Leaf) {
                        $foundPath = $testPath
                        $resolvedToDifferentDrive++
                        
                        if ($script:DebugMode) {
                            Write-Host "  [DEBUG] Found on different drive: $testPath (assumed $path)" -ForegroundColor Cyan
                        }
                        break
                    }
                }
            }
        }
        
        if ($foundPath) {
            # File exists somewhere
            $fileSize = (Get-Item $foundPath -ErrorAction SilentlyContinue).Length
            
            if ($fileSize -ge 200KB -and $fileSize -le 15MB) {
                $existingPaths[$path] = $foundPath
            } else {
                $outsideRangeCount++
                if ($script:DebugMode) {
                    $sizeMB = [math]::Round($fileSize / 1MB, 2)
                    Write-Host "  [DEBUG] Skipped (size: $sizeMB MB): $foundPath" -ForegroundColor Gray
                }
            }
        }
        else {
            # File doesn't exist on ANY drive - truly missing
            $trulyMissingPaths += $path
        }
    }
    
    $missingCount = $trulyMissingPaths.Count
    
    Write-Host ""
    Write-Host "[+] Total paths checked: $checkCount" -ForegroundColor Cyan
    Write-Host "[+] Files found and in size range (200KB-15MB): $($existingPaths.Count)" -ForegroundColor Green
    if ($resolvedToDifferentDrive -gt 0) {
        Write-Host "[+] Files resolved to different drives: $resolvedToDifferentDrive" -ForegroundColor Cyan
    }
    Write-Host "[!] Files outside size range: $outsideRangeCount" -ForegroundColor Gray
    Write-Host "[!] Files truly missing (not on any drive): $missingCount" -ForegroundColor Yellow
    Write-Host ""
    
    # Show truly missing files (filter out temp files, focus on JARs/EXEs)
    if ($missingCount -gt 0) {
        Write-Host "[*] Truly missing files (deleted from all drives):" -ForegroundColor Cyan
        Write-Host ""
        
        $displayedCount = 0
        foreach ($missingPath in $trulyMissingPaths) {
            # Skip temp files and Java cleanup
            # Only skip JNA####.DLL patterns, not ALL .DLLs
            if ($missingPath -match '\\TEMP\\|\\TMP\\|HSPERFDATA|\.TMP$|JNA\d+\.DLL') {
                continue
            }
            
            # Show JAR, EXE, and DLL files
            if ($missingPath -notmatch '\.(JAR|EXE|DLL)$') {
                continue
            }
            
            $displayedCount++
            Write-Host "  [DELETED] " -ForegroundColor Yellow -NoNewline
            Write-Host $missingPath -ForegroundColor White
            Write-Host "      Source: " -NoNewline
            Write-Host "$($fileMetadata[$missingPath].SourceFile)" -ForegroundColor Cyan
        }
        
        if ($displayedCount -eq 0) {
            Write-Host "  No suspicious deletions found (only temp files deleted)" -ForegroundColor Green
        }
        
        Write-Host ""
    }
    
    if ($existingPaths.Count -eq 0) {
        Write-Host "[!] No files exist to scan" -ForegroundColor Yellow
        Write-Host "[*] All extracted paths point to files that either:" -ForegroundColor Yellow
        Write-Host "    - No longer exist (deleted)" -ForegroundColor Gray
        Write-Host "    - Are outside the 200KB-15MB size range" -ForegroundColor Gray
        return
    }
    
    Write-Host "[*] Scanning files for Doomsday Client..." -ForegroundColor Cyan
    Write-Host ""
    
    $detections = @()
    $scanned = 0
    $skipped = 0
    
    foreach ($assumedPath in $existingPaths.Keys) {
        $actualPath = $existingPaths[$assumedPath]
        $scanned++
        
        $filename = [System.IO.Path]::GetFileName($actualPath)
        
        Write-Progress -Activity "Scanning for Doomsday Client" `
                      -Status "[$scanned/$($existingPaths.Count)]" `
                      -PercentComplete (($scanned / $existingPaths.Count) * 100)
        
        Write-Host "`r[$scanned/$($existingPaths.Count)]" -NoNewline -ForegroundColor Cyan
        
        try {
            $result = Test-DoomsdayClient -Path $actualPath
            
            if ($result.Error -and $result.Error -like "Skipped:*") {
                $skipped++
            }
            
            if ($result.IsDetected) {
                Write-Host "`r                              `r" -NoNewline
                
                $detections += [PSCustomObject]@{
                    Path = $actualPath
                    SourceFile = $fileMetadata[$assumedPath].SourceFile
                    IndexNumber = $fileMetadata[$assumedPath].IndexNumber
                    Confidence = $result.Confidence
                    IsRenamedJar = $result.IsRenamedJar
                    BytePatterns = $result.BytePatternMatches.Count
                    ClassMatches = $result.ClassNameMatches.Count
                    SingleLetterClasses = $result.SingleLetterClasses.Count
                }
                
                Write-Host "[!] DETECTION: " -ForegroundColor Red -NoNewline
                Write-Host $actualPath
                Write-Host "    Confidence: " -NoNewline
                
                switch ($result.Confidence) {
                    "HIGH"   { Write-Host "HIGH" -ForegroundColor Red }
                    "MEDIUM" { Write-Host "MEDIUM" -ForegroundColor Yellow }
                    "LOW"    { Write-Host "LOW" -ForegroundColor Gray }
                }
                
                if ($result.IsRenamedJar) {
                    Write-Host "    Renamed JAR detected!" -ForegroundColor Red
                }
                if ($result.BytePatternMatches.Count -gt 0) {
                    Write-Host "    Byte patterns: $($result.BytePatternMatches.Count)" -ForegroundColor Red
                }
                Write-Host ""
            }
        }
        catch {
            Write-Host "`r                              `r" -NoNewline
            Write-Host "Error scanning $filename : $_" -ForegroundColor Red
        }
    }
    
    Write-Host "`r                              `r" -NoNewline
    
    Write-Progress -Activity "Scanning for Doomsday Client" -Completed
    Write-Host ""
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "SCAN COMPLETE" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Total indexes extracted: $($allJarPaths.Count)"
    Write-Host "Files in size range: $($uniquePaths.Count)"
    Write-Host "Files exist: $($existingPaths.Count)"
    Write-Host "Files scanned: $scanned"
    Write-Host "Files skipped (>30 classes): $skipped" -ForegroundColor Gray
    
    Write-Host "Doomsday Client detections: " -NoNewline
    
    if ($detections.Count -gt 0) {
        Write-Host $detections.Count -ForegroundColor Red
        
        Write-Host ""
        Write-Host "Detections by confidence:" -ForegroundColor Yellow
        $high = ($detections | Where-Object { $_.Confidence -eq "HIGH" }).Count
        $medium = ($detections | Where-Object { $_.Confidence -eq "MEDIUM" }).Count
        $low = ($detections | Where-Object { $_.Confidence -eq "LOW" }).Count
        
        if ($high -gt 0) { Write-Host "  HIGH: $high" -ForegroundColor Red }
        if ($medium -gt 0) { Write-Host "  MEDIUM: $medium" -ForegroundColor Yellow }
        if ($low -gt 0) { Write-Host "  LOW: $low" -ForegroundColor Gray }
        
        Write-Host ""
        Write-Host "DOOMSDAY CLIENT DETECTED ON THIS SYSTEM!" -ForegroundColor Red
        
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "DETECTION DETAILS" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        Write-Host ""
        
        $detectionNum = 1
        foreach ($detection in $detections) {
            Write-Host "[$detectionNum] " -NoNewline -ForegroundColor Red
            Write-Host $detection.Path -ForegroundColor White
            Write-Host "    Source File: " -NoNewline
            Write-Host $detection.SourceFile -ForegroundColor Cyan
            Write-Host "    Index Number: " -NoNewline
            Write-Host "#$($detection.IndexNumber)" -ForegroundColor Cyan
            Write-Host "    Confidence: " -NoNewline
            
            switch ($detection.Confidence) {
                "HIGH"   { Write-Host "HIGH" -ForegroundColor Red }
                "MEDIUM" { Write-Host "MEDIUM" -ForegroundColor Yellow }
                "LOW"    { Write-Host "LOW" -ForegroundColor Gray }
            }
            
            if ($detection.IsRenamedJar) {
                Write-Host "    Renamed JAR: " -NoNewline
                Write-Host "YES" -ForegroundColor Red
            }
            
            if ($detection.BytePatterns -gt 0) {
                Write-Host "    Byte Patterns: " -NoNewline
                Write-Host $detection.BytePatterns -ForegroundColor Red
            }
            
            if ($detection.ClassMatches -gt 0) {
                Write-Host "    Class Matches: " -NoNewline
                Write-Host $detection.ClassMatches -ForegroundColor Yellow
            }
            
            if ($detection.SingleLetterClasses -gt 0) {
                Write-Host "    Single-Letter Classes: " -NoNewline
                Write-Host $detection.SingleLetterClasses -ForegroundColor Yellow
            }
            
            Write-Host ""
            $detectionNum++
        }
        
    } else {
        Write-Host "0" -ForegroundColor Green
        Write-Host ""
        Write-Host "No Doomsday Client detected!" -ForegroundColor Green
    }
    
    Write-Host ""
    
    if ($script:DebugMode) {
        Write-Host "[DEBUG MODE] Scan completed with debugging enabled" -ForegroundColor Magenta
    }
}

# Run the scan
# To enable debug mode, use: Start-DoomsdayScan -Debug
Start-DoomsdayScan