## Dashcam Rewrapper

this utility is a self-contained PowerShell script, designed to assist with basic dashcam video clip processing.

### Standard Usage

the business logic contained herein is incredibly simple, boiling down to only two `ffmpeg` CLI commands:

* one to extract a configurable range from a target video clip
* one to concatenate a list of video clips into one

the arguments passed to these commands are compiled and executed as part of the following process:

* open a `<project_name>.csv` file. *eg: `2023-02-28 - I saw the batmobile.csv`*
* for each row:
  * parse `<source_clip>` from first field, relative to the current working directory. *eg: `LOCA0123.avi`*
  * parse `<time_range>` from second field, as `[start]-[end]`. *eg: `28-42`*
  * [FFMpeg] extract audio and video streams for `<time_range>` from `<source_clip>` into temporary "clip source" file
  * record "clip source" file path in a temporary "clip list" file
* [FFMpeg] concatenate all files listed in the "clip list" file into a `<project_name>.mov` video file

where the `<time_range>` field is parsed in the following way:

* `[start]` and `[end]` are numerical values, indicating the position in seconds from the beginning of the clip source video.
* the `-` is a divider, allowing the script to split the string into two values.
* if either/both values are omitted, the clip will default to the "start" or "end" of the clip source video, as appropriate.
  * no clip duration rule, or a blank string, or simply `-`: will copy the entire file
  * only a "start" value like `10-`: will include from `10s` to the `END` of the source file
  * only an "end" value like `-17`: will include from the `START` to `17s` into the source file

> **Project CSV File Examples**
>
> to export a 15 second clip from the middle of one longer clip:
>
> ```csv
> 54-69,LOCA0001.avi
> ```
>
> to export a 20 second clip spanning the split between two clips (assuming 3 min clips):
>
> ```csv
> 165-,LOCA0001.avi
> -15,LOCA0002.avi
> ```

### Runtime Customisation

various aspects of this script's runtime can be tweaked with CLI arguments. to simplify usage, certain sensible defaults do exist where applicable.

script CLI arguments are as follows:

* `-p, --Project` (required, no default): a resolvable path to a `csv` file with the aforementioned rules
* `-s, -Source` (default `.`): resolvable folder path in which to look for source video clip(s)
* `-o, -Output` (default `.`): resolvable folder path in which to write the final output project video clip
* `-t, -TEMP` (default `%TEMP%`): resolvable folder path in which to create runtime working directories - these are not removed automatically
