# * process all "dashcam set rules" as read from `.\1-working\`
# ! [WIP] behaviour subject to change without notice..
#
# for the monent:
# - ".set" files are basic text, containing one line per "source rule"
# - each rule defined as "file_path,clip_start,clip_end"
#   - 'file_path' is relative to $SourceDir
#   - 'clip_start' is the number of seconds from the source file start
#   - 'clip_end' is the number of seconds from the source file start

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

      new-item "$SetWorkingDir" -ItemType Container | out-null
      push-location "$SetWorkingDir"

      $SetLocalPartsPath = "$SetWorkingDir\parts.local"
      if (test-path "$SetLocalPartsPath" -PathType Leaf) {
        remove-item "$SetLocalPartsPath" -Force
      }

      $count = 0
      foreach ($entry in @(get-content $file)) {
        write-host ":: checking set rules.. ::"
        $rule = @($entry.Split(","))

        $ClipSourceFile = $rule[0]
        $ClipStart = 1 * $rule[1]
        $ClipEnd = 1 * $rule[2]
        $ClipStartString = ($ClipStart -ne 0) ? "${ClipStart}s" : "start"
        $ClipEndString = ($ClipEnd -ne 0) ? "${ClipEnd}s" : "end"

        write-host "testing file '$SourceDir\$ClipSourceFile'.."
        if (-not (test-path "$SourceDir\$ClipSourceFile" -PathType Leaf)) {
          write-error "missing source file: $SourceDir\$ClipSourceFile"
          continue
        }

        if (($ClipEnd -ne 0) -eq ($ClipEnd -lt $ClipStart)) {
          write-error "clip end time '$ClipEnd' is before clip start time '$ClipStart'"
          continue
        }

        write-host ":: clipping parts from source files ::"
        $count += 1
        $PartName = "part-$count.mov"
        $TrimCommand = "ffmpeg.exe -loglevel 16 -n -i `"$SourceDir\$ClipSourceFile`" -c copy"
        if ($ClipStart -gt 0) { $TrimCommand += " -ss $ClipStart" }
        if ($ClipEnd -gt 0) { $TrimCommand += " -to $ClipEnd" }
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
