# ? grab the folder path to the script file location..
# $ProcessDir = split-path $MyInvocation.MyCommand.Path -Parent
# write-host "ProcessDir: $ProcessDir"

# ? ensure our script is executed in the correct working directory
# push-location $ProcessDir

try {
  $SourceDir = resolve-path ".\0-dashcam-source"
  $WorkingDir = resolve-path ".\1-working"
  $OutputDir = resolve-path ".\2-rewrapped"

  $DashcamSessions = get-childitem "$SourceDir\*"

  foreach ($SetSourcePath in $DashcamSessions) {
    $SetName = split-path $SetSourcePath -LeafBase
    write-host ":: START :: $SetName ::"

    $SetIsDir = test-path $SetSourcePath -PathType Container

    if ($SetIsDir -eq $False) {
      write-warning "!! this needs to be restructured as a 'session set'.."
    }

    $SetHasPartsFile = test-path "$SetSourcePath\parts" -PathType Leaf
    if ($SetHasPartsFile -eq $False) {
      write-error "!! this 'session set' has no parts file.."
    }

    $SessionFinalOutputPath = "$OutputDir\$SetName"
    $SessionFinalOutputFile = "$SessionFinalOutputPath\concatenated.mov"

    $SetNeedsProcessing = -not (test-path "$SessionFinalOutputFile" -PathType Leaf)
    if ($SetNeedsProcessing -eq $False) {
      write-error "!! this 'session set' has already been processed.."
    }

    $SetNameValid = $SetSourcePath -match '\\\d{4}-\d{2}-\d{2}\s-\s'

    if ($SetNameValid) {
      if (@($SetHasPartsFile, $SetNeedsProcessing) -notcontains $False) {
        $SetWorkingDir = "$WorkingDir\$SetName"

        # ! create a temporary working directory for this session set
        if (test-path "$SetWorkingDir" -PathType Container) {
          remove-item "$SetWorkingDir" -Force -Recurse
        }
        new-item "$SetWorkingDir" -ItemType Container | out-null
        $SetLocalPartsPath = ".\parts.local"

        push-location $SetWorkingDir

        if ($SetIsDir -eq $False) {
          # * NOTE: $SetFiles is an array of FileInfo objects
          # my dashcam always saves files as AVI..
          # $SetFiles = @(get-childitem "$SetSourcePath" -Filter '.avi')

          # ! now cut the configured parts out of the source session file(s)
          write-host "splitting raw dashcam files into defined parts.."

          $SetIndexContent = get-content "$SetSourcePath\parts"
          $PartCount = 0
          foreach ($line in $SetIndexContent) {
            $rule = $line.Split(",")

            if ($rule.Count -ne 3) {
              write-warning "file parsing rule should have 3 elements, even if the 2nd or 3rd are empty: $rule"
            } else {
              $ClipBaseName = $rule[0]
              $ClipStart = $rule[1]
              $ClipEnd = $rule[2]
              $PartName = "part-$PartCount.mov"

              $TrimCommand = "ffmpeg.exe -loglevel 16 -n -i `"$SetSourcePath\$ClipBaseName.avi`" -c copy"
              # if excluded, clip "start" will NOT be trimmed
              if ($ClipStart) { $TrimCommand += " -ss $ClipStart" }
              # if excluded, clip "end" will NOT be trimmed
              if ($ClipEnd) { $TrimCommand += " -to $ClipEnd" }

              $TrimCommand += " '$PartName'"
              write-host "trimming '$PartName'"
              write-warning $TrimCommand
              # invoke-expression $TrimCommand
              write-output "file $PartName" >> "$SetLocalPartsPath"

              $PartCount += 1
            }
          }
        }

        # ! then concatenate the rewrapped files
        if (test-path "$SetLocalPartsPath" -PathType Leaf) {
          write-host "concatenating dashcam part files into one.."

          if (-not (test-path "$SessionFinalOutputPath" -PathType Container)) {
            new-item "$SessionFinalOutputPath" -ItemType Container | out-null
          }

          $ConcatParts = get-content "$SetLocalPartsPath"
          write-host "concatenating '$ConcatParts'"

          $ConcatCommand = "ffmpeg.exe -loglevel 16 -n -f concat -i `"$SetLocalPartsPath`" -c copy `"$SessionFinalOutputFile`""
          write-warning $ConcatCommand
          # invoke-expression $ConcatCommand
        }

        pop-location
      }

      # ! final cleanup
      if (test-path "$SessionFinalOutputFile" -PathType Leaf) {
        if ((get-item "$SessionFinalOutputFile").length -gt 0kb) {
          write-warning "cleaning up files..."
          # remove-item $SetWorkingDir -Force -Recurse
          # remove-item $SetSourcePath -Force -Recurse
        }
      }
    }

    write-host ":: FINISH :: $SetName ::"
  }
} catch {
  write-error "hmm.. something died uncomfortably: $_"
  write-error $_.ScriptStackTrace
} finally {
  pop-location
}
