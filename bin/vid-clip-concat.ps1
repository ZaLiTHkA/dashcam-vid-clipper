param(
  # ! this is the "video clip rules list" project file to work with.. so, yes, it's mandatory.
  [Parameter(Mandatory)] [Alias("p")] [string] $Project,

  # ? (optional) a resolvable path to use as the "working directory" for working with the extracted video clip(s).
  # if not set, this defaults to a folder named after your project, within your host OS "TEMP" folder.
  [Parameter()] [Alias("t")] [string] $Temp = "$Env:TEMP",

  # ? (optional) a resolvable path to use as the "root path" for any relative video clip rule file paths.
  # if not set, this script will use the current process working directory by default.
  # this has no effect on absolute video clip rule file paths.
  [Parameter()] [Alias("s")] [string] $Source = ".",

  # ? (optional) a resolvable path to use as the "output folder" for the final concatenated video file(s).
  # if not set, this script will use the current working folder by default.
  [Parameter()] [Alias("o")] [string] $Output = "."
)

# ! check runtime requirements..
try {
  $FfmpegVersion = (($(Invoke-Expression "ffmpeg -version" -ErrorAction Stop) -split "\n")[0] -split "\s")[2]
  Write-Debug "[FfmpegVersion] $FfmpegVersion"

  $ProjectPath = Resolve-Path "$Project" -ErrorAction Stop
  Write-Debug "[ProjectPath] resolved as: $ProjectPath"

  $TempPath = Resolve-Path "$Temp" -ErrorAction Stop
  Write-Debug "[TempPath] ($(($PSBoundParameters.ContainsKey("Temp")) ? "custom!!" : "default..")) resolved as: $TempPath"

  $VideosPath = Resolve-Path "$Source" -ErrorAction Stop
  Write-Debug "[VideosPath] ($(($PSBoundParameters.ContainsKey("Source")) ? "custom!!" : "default..")) resolved as: $VideosPath"

  $OutputPath = Resolve-Path "$Output" -ErrorAction Stop
  Write-Debug "[OutputPath] ($(($PSBoundParameters.ContainsKey("Output")) ? "custom!!" : "default..")) resolved as: $OutputPath"
}
catch {
  Write-Error "oh dear.. $_"
  Write-Debug $_.ScriptStackTrace
  exit 1
}

try {
  $ProjectName = Split-Path $ProjectPath -LeafBase
  Write-Host ":: processing video project `"$ProjectName`".. ::"

  $ProjectClips = @(Get-Content "$ProjectPath")
  Write-Verbose "project depends on $($ProjectClips.Count) source clips"
  Write-Debug "ProjectClips: $ProjectClips"

  $ProjectWorkingDir = "$TempPath\vid-clip-concat-$(Get-Date -Format "yyyy-MM-dd-HH-mm-ss")"
  $ProjectPartsFile = "$ProjectWorkingDir\project-clip.parts"

  if (-not (Test-Path "$ProjectWorkingDir" -PathType Container)) {
    [void](New-Item -Path "$ProjectWorkingDir" -ItemType Directory)
  }

  Push-Location "$ProjectWorkingDir"

  $ProjectClipCounter = 0
  foreach ($Clip in $ProjectClips) {
    $ClipParts = @($Clip.Split(","))

    $ClipSource = $ClipParts[0]
    $ClipRange = $ClipParts[1]

    if (-not (Test-Path "$VideosPath\$ClipSource" -PathType Leaf)) {
      write-error "source file missing: $VideosPath\$ClipSource"
      continue
    }
    $ProjectClipCounter += 1

    $ClipRangeParts = @($ClipRange.Split("-"))
    $ClipStart = 1 * $ClipRangeParts[0]
    $ClipEnd = 1 * $ClipRangeParts[1]

    $TrimCommand = "ffmpeg.exe -loglevel 16 -n -i `"$VideosPath\$ClipSource`" -c copy"
    if ($ClipStart -gt 0) {
      $TrimCommand = "$TrimCommand -ss $ClipStart"
    }
    if ($ClipEnd -gt 0) {
      $TrimCommand = "$TrimCommand -to $ClipEnd"
    }

    $PartName = "part-$ProjectClipCounter.mov"
    $TrimCommand = "$TrimCommand '$PartName'"
    Write-Output "file $PartName" >> "$ProjectPartsFile"

    Write-Debug "generated TrimCommand: $TrimCommand"
    Invoke-Expression $TrimCommand
  }

  Write-Host ":: concatenating clip parts.. ::"
  $ConcatCommand = "ffmpeg.exe -loglevel 16 -n -f concat -i `"$ProjectPartsFile`" -c copy `"$OutputPath\$ProjectName.mov`""

  Write-Debug "generated ConcatCommand: $ConcatCommand"
  Invoke-Expression $ConcatCommand

  Pop-Location
}
catch {
  Write-Error "hmmm.. $_"
  Write-Debug $_.ScriptStackTrace
  exit 1
}
