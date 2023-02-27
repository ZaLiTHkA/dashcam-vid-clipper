param(
  # this is the "video clip rules list" project file to work with.. so, yes, it's mandatory.
  [Parameter(ValueFromRemainingArguments, Position = 0)] [Alias("p")] [string] $Project,

  # a resolvable path to use as the "working directory" for working with the extracted video clip(s).
  [Parameter()] [Alias("t")] [string] $Temp = "$Env:TEMP",

  # a resolvable path to use as the "root path" for any relative video clip rule file paths.
  [Parameter()] [Alias("s")] [string] $Source = ".\sources",

  # a resolvable path to use as the "output folder" for the final concatenated video file(s).
  [Parameter()] [Alias("o")] [string] $Output = ".\outputs"
)

# ! first set up our environment..
try {
  $FfmpegVersion = (($(Invoke-Expression "ffmpeg -version" -ErrorAction Stop) -split "\n")[0] -split "\s")[2]
  Write-Debug "[FfmpegVersion] $FfmpegVersion"

  $ProjectPath = Resolve-Path "$Project" -ErrorAction Stop
  Write-Debug "[ProjectPath] resolved as: $ProjectPath"
  $ProjectName = Split-Path $ProjectPath -LeafBase

  $WorkingDir = Resolve-Path "$ProjectPath" | Split-Path
  Write-Debug "WorkingDir: $WorkingDir"

  $TempPath = Resolve-Path "$Temp" -ErrorAction Stop
  $TempDir = "$TempPath\Video-Clipper__$(Get-Date -Format "yyyy-MM-dd-HH-mm-ss")__$($ProjectName)"
  if (-not (Test-Path "$TempDir" -PathType Container)) {
    [void](New-Item -Path "$TempDir" -ItemType Directory)
  }
  $ProjectPartsList = "$TempDir\project-clip.parts"
  Write-Debug "[TempDir] ($(($PSBoundParameters.ContainsKey("Temp")) ? "custom!!" : "default..")) resolved as: $TempDir"

  $SourcePath = Resolve-Path "$Source" -ErrorAction Stop
  Write-Debug "[SourcePath] ($(($PSBoundParameters.ContainsKey("Source")) ? "custom!!" : "default..")) resolved as: $SourcePath"

  $OutputPath = Resolve-Path "$Output" -ErrorAction Stop
  Write-Debug "[OutputPath] ($(($PSBoundParameters.ContainsKey("Output")) ? "custom!!" : "default..")) resolved as: $OutputPath"
}
catch {
  Write-Error "oh dear.. $_"
  Write-Debug $_.ScriptStackTrace
  exit 1
}

# ! process project..
try {
  Write-Host ":: processing video project '$ProjectName'.. ::"

  $ProjectClips = @(Get-Content "$ProjectPath")
  Write-Verbose "project depends on $($ProjectClips.Count) source clips"
  Write-Debug "ProjectClips: $ProjectClips"

  if ($ProjectClips.Count -ne 0) {
    $ProjectClipCounter = 0
    foreach ($Clip in $ProjectClips) {
      $ProjectClipCounter += 1

      $ClipParts = @($Clip.Split(","))
      $ClipSource = Resolve-Path $ClipParts[0] -ErrorAction SilentlyContinue
      if (-not $ClipSource) {
        Write-Debug "[ClipSource] not absolute path.. trying relative to provided source."
        $ClipSource = Resolve-Path "$SourcePath`\$($ClipParts[0])" -ErrorAction Stop
      }
      Write-Debug "[ClipSource] resolved as: $ClipSource"
      $ClipRange = $ClipParts[1]

      if (-not ($ClipRange)) {
        $ClipRange = "-"
      }

      $ClipRangeParts = @($ClipRange.Split("-"))
      $ClipStart = 1 * $ClipRangeParts[0]
      $ClipEnd = 1 * $ClipRangeParts[1]

      $TrimCommand = "ffmpeg.exe -loglevel 16 -n -i '$ClipSource' -c copy"
      if ($ClipStart -gt 0) {
        $TrimCommand = "$TrimCommand -ss $ClipStart"
      }
      if ($ClipEnd -gt 0) {
        $TrimCommand = "$TrimCommand -to $ClipEnd"
      }

      $PartName = "$TempDir\part-$ProjectClipCounter.mov"
      Write-Output "file '$PartName'" >> "$ProjectPartsList"
      $TrimCommand = "$TrimCommand '$PartName'"

      Write-Verbose "generated TrimCommand: $TrimCommand"
      Invoke-Expression $TrimCommand
    }
  }
  else {
    Write-Host "no source clips found in project.."
  }

  if (Test-Path "$ProjectPartsList" -PathType Leaf) {
    Write-Host ":: concatenating clip parts.. ::"
    $ConcatCommand = "ffmpeg.exe -loglevel 16 -n -f concat -safe 0 -i '$ProjectPartsList' -c copy '$OutputPath\$ProjectName.mov'"

    Write-Verbose "generated ConcatCommand: $ConcatCommand"
    Invoke-Expression $ConcatCommand
  }
  else {
    Write-Verbose "but there was nothing to concatenate.."
  }
}
catch {
  Write-Error "hmmm.. $_"
  Write-Debug $_.ScriptStackTrace
  exit 1
}
