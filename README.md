# macMOTD

## Status
After many months of being neglected, I believe we have an MVP (Minimum Viable Product) in version 1.1.0. It works for me, at least, on macOS Tahoe 26.2 (25C56).

### TLDR
Some simple properties in the Launch Daemon plist were causing it to be ignored by the OS, and I became under the impression that what would be required to move forward is a Privileged Helper. I have since learned that is not the case, which is good, because I wasn't about to take the time to digitally sign an executable that ran a script.

## Installation
- Clone the repo/download the source code zip/tarball
- As root/using `sudo`, execute `./mac-motd -i` to install macMOTD on your system (if you want to override the MOTD regeneration frequency/the log file path, see the output of `-h` and use the appropriate options alongside `-i`). Installation performs the following:

1. `mac-motd` will be installed to a system bin directory where it can be found globally.
2. All of the zsh scripts in `./update-motd.d` and its descendant directories will be copied to `/etc/update-motd.d`, and set to be executable by root.
3. A Launch Daemon plist is written to `/Library/LaunchDaemons`, which causes the now global `mac-motd` to be executed with the `-g` (generate) option every _n_ seconds (default is 600 = 10 mins).
4. When that command is executed, it will enumerate the scripts _that are executable and have a `.zsh` extension_ in `/etc/update-motd.d`, execute them in ascending alphanumeric sort order, and append their output to the MOTD that will appear in users' terminals.

## Uninstalling
See the output from `mac-motd -h` under `-u, --uninstall`. You may choose to:

- Leave all of the scripts in `/etc/update-motd.d` alone
- Rename them so they won't be executed, but still exist on disk
- Nuke them irreversibly

Regardless of which of these you choose, the Launch Daemon, global `mac-motd` script, and all other files generated/installed during installation and operation will be deleted.

## Helper Functions
There are some useful utility functions in `./update-motd.d/motd-helpers/motd-base.zsh` which are there to allow for easy printing of colored/stylized text in your MOTD. Additionally, there is an entire WIP of system utility functions that do things like obtain performance metrics, identify OS version, etc. in `./update-motd.d/motd-helpers/scratchpad.zsh`. Only some of these work fully, and I don't remember which, so godspeed. One day I will sit down and finish it. One day.
