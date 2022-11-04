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
#   - '{extra_step}' [WIP] think of this as a "post-process hook", but currently it serves one solitary purpose:
#     - to allow 'REPAIR' to be passed in, which moves the source file to a special folder.. :/

$IS_DRY_RUN = (@(($args -contains "--exec"),($args -contains "-x") -notcontains $True))
if ($IS_DRY_RUN) {
  write-warning "going --dry-run style.. no changes will be made."
}

try {
  # ! here we verify the current runtime environment..
  # basically, if nothing kills the block, then we're good to go..

  $BackupDir = resolve-path ".\X-BACKUP" -ErrorAction Stop

  # * this folder holds the incoming video files, as copied directly from the SD card..
  $SourceDir = resolve-path ".\0-sources" -ErrorAction Stop
  $SourceNeedsRepairDir = "$BackupDir\needs-repair"

  # * this folder holds "video sets" as text files with CSV-style "rules" for cutting clips from source video files..
  $WorkingDir = resolve-path ".\1-working" -ErrorAction Stop
  $SetFilesDoneDir = "$BackupDir\set-files"

  # * this folder holds the out of "rewrapping" the clips extracted from the source video files..
  $RewrappedDir = resolve-path ".\2-rewrapped" -ErrorAction Stop
} catch {
  write-error "hmm.. $_"
  # write-error $_.ScriptStackTrace
  exit 0
}

foreach ($SetFile in @(get-childitem "$WorkingDir\*.set")) {
  # ! NOTE: here the try/catch is _inside_ the loop, because each set should have a chance at being used..
  # ..regardless, ultimately there will be much refactoring.
  try {
    # write-warning $SetFile.Name
    # write-warning $SetFile.BaseName
    # write-warning $SetFile.Extension
    # write-warning $SetFile.Directory

    $DashSetName = $SetFile.BaseName
    $SetFileName = $SetFile.Name
    $SetWorkingDir = "$WorkingDir\$DashSetName"
    $SetOutputDir = "$RewrappedDir\$DashSetName"
    $SetOutputFile = "$SetOutputDir\concatenated.mov"
    $SetLocalPartsPath = "$SetWorkingDir\parts.local"

    if (-not (test-path "$SetOutputDir" -PathType Container)) {
      new-item "$SetOutputDir" -ItemType Container | out-null
    }

    if (-not (test-path "$SetOutputFile" -PathType Leaf)) {
      if (test-path "$SetWorkingDir" -PathType Container) {
        remove-item "$SetWorkingDir" -Force -Recurse
      }
      new-item "$SetWorkingDir" -ItemType Container | out-null
      push-location "$SetWorkingDir"

      if (test-path "$SetLocalPartsPath" -PathType Leaf) {
        remove-item "$SetLocalPartsPath" -Force
      }

      write-host ":: processing rules for '$DashSetName'.. ::"

      $ClipCounter = 0
      foreach ($SetRule in @(get-content $SetFile)) {
        $SetRuleParts = @($SetRule.Split(","))

        $ClipPath = $SetRuleParts[0]
        if (-not (test-path "$SourceDir\$ClipPath" -PathType Leaf)) {
          write-error "source file missing: $SourceDir\$ClipPath"
          continue
        }
        $ClipCounter += 1

        $ClipRange = $SetRuleParts[1]
        $ClipRangeParts = @($ClipRange.Split("-"))
        $ClipStart = 1 * $ClipRangeParts[0]
        $ClipEnd = 1 * $ClipRangeParts[1]

        $TrimCommand = "ffmpeg.exe -loglevel 16 -n -i `"$SourceDir\$ClipPath`" -c copy"

        if ($ClipStart -gt 0) {
          $TrimCommand += " -ss $ClipStart"
        }
        if ($ClipEnd -gt 0) {
          $TrimCommand += " -to $ClipEnd"
        }

        $PartName = "part-$ClipCounter.mov"
        $TrimCommand += " '$PartName'"
        write-output "file $PartName" >> "$SetLocalPartsPath"

        if (-not $IS_DRY_RUN) {
          invoke-expression $TrimCommand
        } else {
          write-warning "[--dry-run] $TrimCommand"
        }

        # ! this is simply going to slot in after the current process, for now.. but this must be integrated more carefully before being commited..
        $SourceClipExtraStep = $SetRuleParts[2]
        if ("$SourceClipExtraStep" -eq "REPAIR") {
          if (-not $IS_DRY_RUN) {
            write-warning "moving source clip to 'needs repair' folder.."
            move-item -Path "$SourceDir\$ClipPath" -Destination "$SourceNeedsRepairDir\$ClipPath"
          } else {
            write-warning "[--dry-run] NOT moving source clip to 'needs repair' folder.."
          }
        }
      }

      write-host ":: concatenating clip parts.. ::"
      $ConcatCommand = "ffmpeg.exe -loglevel 16 -n -f concat -i `"$SetLocalPartsPath`" -c copy `"$SetOutputFile`""

      if (-not $IS_DRY_RUN) {
        invoke-expression $ConcatCommand
      } else {
        write-warning "[--dry-run] $ConcatCommand"
      }

      # ! we can leave the set working directory now..
      pop-location

      # ! obligatory EOF cleanup..
      write-host ":: runtime clean up.. ::"

      if ((test-path "$SetOutputFile" -PathType Leaf)) {
        # move the current set rules file..
        move-item -Path "$WorkingDir\$SetFileName" -Destination "$SetFilesDoneDir\$SetFileName"
      }

      if ((test-path "$SetWorkingDir" -PathType Container)) {
        # clear set process working directory
        remove-item "$SetWorkingDir" -Force -Recurse
      }
    }
  } catch {
    write-error "wait, what?? $_"
  }
}
