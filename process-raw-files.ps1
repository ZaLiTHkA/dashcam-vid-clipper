# * process all "dashcam set rules" as read from `.\1-working\`
# ! [WIP] behaviour subject to change without notice..
#
# for the monent:
# - ".set" files are basic text, containing one line per "source rule"
# - each rule defined as "{file_path},{clip_start}-{clip_end},{extra_step}"
#   - '{file_path}' is relative to $SourceDir
#   - '{clip_start}-{clip_end}' is ONE FIELD with two video seeker positions of the clip to copy
#     - * to incude the whole file, leave this blank or pass in '-'
#     - * to cut from a set position _to the end_, set this as '{clip_start}-'
#     - * similarly, to cut _from the start_ up to a set position, set as '-{clip_end}'

try {
  # ! here we verify the current runtime environment..
  # basically, if nothing kills the block, then we're good to go..
  write-host ":: checking environment ::"

  # * this folder holds the incoming video files, as copied directly from the SD card..
  $SourceDir = resolve-path ".\0-sources"
  write-host "[env] SourceDir: $SourceDir"

  # * this folder holds "video sets" as text files with CSV-style "rules" for cutting clips from source video files..
  $WorkingDir = resolve-path ".\1-working"

  $DashSetFiles = @(get-childitem "$WorkingDir\*.set")
  $DashSetFileCount = $DashSetFiles.Count
  write-host "[env] WorkingDir: $WorkingDir, with $DashSetFileCount dashcam video sets"

  # * this folder holds the out of "rewrapping" the clips extracted from the source video files..
  $RewrappedDir = resolve-path ".\2-rewrapped"
  write-host "[env] RewrappedDir: $RewrappedDir"
} catch {
  write-error "hmm.. $_"
  # write-error $_.ScriptStackTrace
  exit 0
}

foreach ($file in $DashSetFiles) {
  $DashSetName = split-path $file -LeafBase
  try {
    $SetWorkingDir = "$WorkingDir\$DashSetName"

    $SetOutputDir = "$RewrappedDir\$DashSetName"
    if (-not (test-path "$SetOutputDir" -PathType Container)) {
      new-item "$SetOutputDir" -ItemType Container | out-null
    }

    $SetOutputFile = "$SetOutputDir\concatenated.mov"
    if (-not (test-path "$SetOutputFile" -PathType Leaf)) {
      write-host ":: $DashSetName ::"

      if (test-path "$SetWorkingDir" -PathType Container) {
        remove-item "$SetWorkingDir" -Force -Recurse
      }
      new-item "$SetWorkingDir" -ItemType Container | out-null
      push-location "$SetWorkingDir"

      $SetLocalPartsPath = "$SetWorkingDir\parts.local"
      if (test-path "$SetLocalPartsPath" -PathType Leaf) {
        remove-item "$SetLocalPartsPath" -Force
      }

      $count = 0
      write-host ":: checking set rules.. ::"
      foreach ($entry in @(get-content $file)) {
        $rule = @($entry.Split(","))

        $ClipSourceFile = $rule[0]
        write-host "proccessing file '$ClipSourceFile'.."

        if (-not (test-path "$SourceDir\$ClipSourceFile" -PathType Leaf)) {
          write-error "source file missing: $SourceDir\$ClipSourceFile"
          continue
        }

        $ClipRange = $rule[1]
        $ClipRangeParts = @("$ClipRange" -split "-")
        $ClipStart = 1 * $ClipRangeParts[0]
        $ClipEnd = 1 * $ClipRangeParts[1]

        $count += 1
        $PartName = "part-$count.mov"
        $TrimCommand = "ffmpeg.exe -loglevel 16 -n -i `"$SourceDir\$ClipSourceFile`" -c copy"

        if ($ClipStart -gt 0) {
          $TrimCommand += " -ss $ClipStart"
        }
        if ($ClipEnd -gt 0) {
          $TrimCommand += " -to $ClipEnd"
        }

        $TrimCommand += " '$PartName'"
        write-warning $TrimCommand
        invoke-expression $TrimCommand
        write-output "file $PartName" >> "$SetLocalPartsPath"
      }

      write-host ":: concatenating clip parts.. ::"
      $ConcatCommand = "ffmpeg.exe -loglevel 16 -n -f concat -i `"$SetLocalPartsPath`" -c copy `"$SetOutputFile`""
      write-warning $ConcatCommand
      invoke-expression $ConcatCommand
      pop-location
    }
  } catch {
    write-error "but.. $_"
  } finally {
    $HasSetWorkingDir = (test-path "$SetWorkingDir" -PathType Container)
    # write-host "HasSetWorkingDir: $HasSetWorkingDir"
    $HasSetOutputFile = (test-path "$SetOutputFile" -PathType Leaf)
    # write-host "HasSetOutputFile: $HasSetOutputFile"
    $SetOutputFileValid = ((get-item "$SetOutputFile").length -gt 0kb)
    # write-host "SetOutputFileValid: $SetOutputFileValid"
    if (@($HasSetWorkingDir, $HasSetOutputFile, $SetOutputFileValid) -notcontains $False) {
      write-host ":: cleaning up.. ::"
      remove-item "$SetWorkingDir" -Force -Recurse
    }
  }
}
