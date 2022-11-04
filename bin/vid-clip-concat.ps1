# * extract specified clips from source video files, creating a single concatenated output file.
#
# personally, I have two common uses for this script:
#
# - collecting dashcam incident footage from 2-minute revolving video clips
# - clipping and/or joining gameplay screen recording sessions
#
# ! [WIP] behaviour subject to change without notice..
#
# for the monent:
#
# - ".set" files are basic text, containing one line per "source rule"
# - each rule defined as "{file_path},{clip_start}-{clip_end},{extra_step}"
#   - '{file_path}' is relative to $VideosPath
#   - '{clip_start}-{clip_end}' is ONE FIELD with two video seeker positions of the clip to copy
#     - * to incude the whole file, leave this blank or pass in '-'
#     - * to cut from a set position _to the end_, set this as '{clip_start}-'
#     - * similarly, to cut _from the start_ up to a set position, set as '-{clip_end}'
#   - '{extra_step}' [WIP] think of this as a "post-process hook", but currently it serves one solitary purpose:
#     - to allow 'REPAIR' to be passed in, which moves the source file to a special folder.. :/

param(
  # ! this is the "video clip rules list" project file to work with.. so, yes, it's mandatory.
  [Parameter(Mandatory)] [Alias("l")] [string] $ListFile,

  # ? (optional) a resolvable path to use as the "root path" for any relative video clip rule file paths.
  # if not set, this script will use the current process working directory by default.
  # this has no effect on absolute video clip rule file paths.
  [Parameter()] [Alias("v")] [string] $Videos = ".",

  # ? (optional) a resolvable path to use as the "working directory" for working with the extracted video clip(s).
  # if not set, this defaults to a folder named after your project, within your host OS "TEMP" folder.
  [Parameter()] [Alias("t")] [string] $Temp = "$Env:TEMP",

  # ? (optional) a resolvable path to use as the "output folder" for the final concatenated video file(s).
  # if not set, this script will use the current working folder by default.
  [Parameter()] [Alias("o")] [string] $Output = ".",

  # ? (optional) setting this will prevent the creation of video project output subfolders.
  # unless explicitly set, the concatenated output video file will be named after its project.
  [Parameter()] [Alias("f")] [switch] $Flat = $False
)

Write-Debug "[ListFile] $ListFile"
Write-Debug "[Videos] $Videos"
Write-Debug "[Temp] $Temp"
Write-Debug "[Output] $Output"
Write-Debug "[Flat] $Flat"

# ! verify the current runtime environment..
try {
  $FfmpegVersion = (($(Invoke-Expression "ffmpeg -version" -ErrorAction Stop) -split "\n")[0] -split "\s")[2]
  Write-Verbose "[FfmpegVersion] $FfmpegVersion"

  $ListFilePath = Resolve-Path "$ListFile" -ErrorAction Stop
  Write-Verbose "[ListFilePath] resolved as: $ListFilePath"

  $VideosPath = Resolve-Path "$Videos" -ErrorAction Stop
  Write-Verbose "[VideosPath] ($(($PSBoundParameters.ContainsKey("Videos")) ? "custom!!" : "default..")) resolved as: $VideosPath"

  $TempPath = Resolve-Path "$Temp" -ErrorAction Stop
  Write-Verbose "[TempPath] ($(($PSBoundParameters.ContainsKey("Temp")) ? "custom!!" : "default..")) resolved as: $TempPath"

  $OutputPath = Resolve-Path "$Output" -ErrorAction Stop
  Write-Verbose "[OutputPath] ($(($PSBoundParameters.ContainsKey("Output")) ? "custom!!" : "default..")) resolved as: $OutputPath"
}
catch {
  Write-Error "oh dear.. $_"
  Write-Debug $_.ScriptStackTrace
  exit 1
}

Write-Debug "[FfmpegVersion] $FfmpegVersion"
Write-Debug "[ListFilePath] $ListFilePath"
Write-Debug "[VideosPath] $VideosPath"
Write-Debug "[TempPath] $TempPath"
Write-Debug "[OutputPath] $OutputPath"

try {
  $ProjectName = Split-Path $ListFilePath -LeafBase
  Write-Host ":: processing video project `"$ProjectName`".. ::"

  $ListFileRules = @(Get-Content "$ListFilePath")
  Write-Debug "ListFileRules: $ListFileRules"
  Write-Verbose "found $($ListFileRules.Count) entries"

  # write-warning $ListFilePath.Extension
  # write-warning $ListFilePath.Directory

  $ProjectWorkingDir = "$TempPath\$ProjectName"

  $RuleCounter = 0
  foreach ($Rule in $ListFileRules) {
    $RuleParts = @($Rule.Split(","))

    $ClipGroup = $RuleParts[0]
    $ClipPath = $RuleParts[1]
    $ClipRange = $RuleParts[2]

    $ClipGroupPartsPath = "$ProjectWorkingDir\$ClipGroup.parts"

    if (-not (test-path "$VideosPath\$ClipPath" -PathType Leaf)) {
      write-error "source file missing: $VideosPath\$ClipPath"
      continue
    }
    $RuleCounter += 1

    $ClipRangeParts = @($ClipRange.Split("-"))
    $ClipStart = 1 * $ClipRangeParts[0]
    $ClipEnd = 1 * $ClipRangeParts[1]

    $TrimCommand = "ffmpeg.exe -loglevel 16 -n -i `"$SourceDir\$ClipPath`" -c copy"
    if ($ClipStart -gt 0) {
      $TrimCommand = "$TrimCommand -ss $ClipStart"
    }
    if ($ClipEnd -gt 0) {
      $TrimCommand = "$TrimCommand -to $ClipEnd"
    }

    $PartName = "part-$RuleCounter.mov"
    $TrimCommand = "$TrimCommand '$PartName'"
    write-output "file $PartName" >> "$ClipGroupPartsPath"

    invoke-expression $TrimCommand
  }

  $ProjectOutputFolder = ($Flat -eq $true) ? "$RewrappedDir" : "$RewrappedDir\$ProjectName"
  if (-not (test-path "$ProjectOutputFolder" -PathType Container)) {
    new-item "$ProjectOutputFolder" -ItemType Container | out-null
  }

  $ProjectOutputFile = ($Flat -eq $true) ? "$ProjectName.mov" : "concatenated.mov"

  write-host ":: concatenating clip parts.. ::"
  foreach ($ClipGroupList in @(Get-ChildItem "$ProjectWorkingDir" -File -Filter *.parts)) {
    $ConcatCommand = "ffmpeg.exe -loglevel 16 -n -f concat -i `"$ClipGroupList`" -c copy `"$ProjectOutputFile`""

    invoke-expression $ConcatCommand
  }
}
catch {
  Write-Error "hmmm.. $_"
  Write-Debug $_.ScriptStackTrace
  exit 1
}
