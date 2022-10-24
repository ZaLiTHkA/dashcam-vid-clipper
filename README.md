## Dashcam Rewrapper

this utility is a self-contained PowerShell script, designed to assist with basic dashcam video file processing.

### Introductions

in short, this will perform the following steps:

* parse contents of a `.set` file
  * _this contains rules that control the "sources" for one or more clips to process._
* extract configured clips from the source file(s) to a working directory
* concatenate all configured clips into a single output file
* move the now-processed `.set` file into a "done" folder

> **note**: some other special functionality has crept in out of pure necessity.. this will be cleaned up and standardised before long.

### Requirements

at present, this expects your dashcam video files to be stored with a very specific folder structure.. looking from the root of your "dashcams" folder:

* `0-sources` - holds all of your "raw" dashcam video files in any structure you want.
* `1-working` - holds your custom `.set` rule files, and is used as a temporary working directory for the internal actions.
* `2-rewrapped` - holds the concatenated output file from the processed `.set` file.
* `X-BACKUP` - holds a few special folders:
  * `needs-repair` - (WIP) holds "raw" dashcam video files that have been marked as "needs repair" for any reason.
  * `set-files` - holds `.set` files that have been successfully processed.

also, this tool expects the `ffmpeg` binary to be available in your current environment. please install the latest `ffmpeg` utility and ensure it is added to your system `PATH` variable first.

### Usage

the script is designed to be executed from the root of your chosen dashcam processing folder, but the script file itself may exist anywhere on your system.

> **note**: this process is a little clunky at the moment, but I am working on a "install/uninstall" process, which should simplify this a great deal..

#### Creating Video Set Rule Files

each output project is based on a single `.set` file, which is used in the following ways:

* the `.set` file name is used without as the "output project" folder name
* each line in the `.set` file holds a rule that will result in a separate video clip being extracted
* each video clip rule defines the source file, and an optional "start" and "end" position to clip
* all extracted video clips will be concatenated into a single file, matching the defined clip order

video clip duration parsing is done with the second rule field, interpretted as `{clip_start}-{clip_end}`, where:

* `{clip_start}` and `{clip_end}` are numerical values, indicating the position in seconds from the beginning of the clip source video.
* the `-` is a divider, allowing the script to split the string into two values.
* if either/both values are omitted, the clip will default to the "start" or "end" of the clip source video, as appropriate.
  * no clip duration rule, or a blank string, or simply `-`: will copy the entire file
  * only a "start" value like `10-`: will include from `10s` to the `END` of the source file
  * only an "end" value like `-17`: will include from the `START` to `17s` into the source file

##### Example

here we will be working with the following 3 dashcam source files, which are typically 2 to 3 minutes long:

* `LOCA0002.avi` - the video file you "locked" on your dashcam..
* `MOVA0001.avi` - standard loop recording clips, take note of the "default file sort order", placing `M` _after_ `L`.
* `MOVA0003.avi`

from these source files, we will then extract the following outputs:

* `2022-10-30 - OMG check this idiot.set` - which will contain a short piece of `LOCA0002.avi`.
* `2022-10-30 - Crazy drive home.set` - which will contain all three source files, concatenated in the correct order.

our first `2022-10-30 - OMG check this idiot.set` file should contain:

```
LOCA0002.avi,34-49
```

this will perform the following steps:

* extract from `34s` up to `49s` from `0-sources\LOCA0002.avi`, saving this to `1-working\2022-10-30 - OMG check this idiot\part-1.mov`
* concatenate `[part-1.mov]` into `2-rewrapped\2022-10-30 - OMG check this idiot\concatenated.mov`

whereas our second `2022-10-30 - Crazy drive home.set` file should contain:

```
MOVA0001.avi,15-
LOCA0002.avi
MOVA0003.avi,-96
```

* extract from `15s` up to `END` from `0-sources\MOVA0001.avi`, saving this to `1-working\2022-10-30 - Crazy drive home\part-1.mov`
* extract from `START` up to `END` from `0-sources\LOCA0002.avi`, saving this to `1-working\2022-10-30 - Crazy drive home\part-2.mov`
* extract from `START` up to `96s` from `0-sources\MOVA0003.avi`, saving this to `1-working\2022-10-30 - Crazy drive home\part-3.mov`
* concatenate `[part-1.mov,part-2.mov,part-3.mov]` into `2-rewrapped\2022-10-30 - Crazy drive home\concatenated.mov`

#### Processing Video Set Rule Files

currently, the best way to run this tool is:

* create and populate a `{project name}.set` file.
  * _where `{project name}` will determine the rewrapped output folder name._
* open a PowerShell terminal at the root of your dashcam processing folder.
* execute the `rewrapper.ps1` script file from wherever it is stored.
  * _such as `C:\Users\ZaLiTHkA\workspace\dashcam-rewrapper\rewrapper.ps1`._

### Some Background

this started out
