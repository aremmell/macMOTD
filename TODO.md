# macMOTD: Future Brainstorming

## System info & stats

- [ ] Logged-in users count (`who | wc -l`, plus list if > 1)
- [ ] Uptime / load averages (`uptime` covers both)
- [ ] Disk usage (`df -h /` for boot volume, optionally per-mount)
- [ ] Memory pressure (`vm_stat` parsed, or `memory_pressure`)
- [ ] CPU load (already covered by uptime)
- [ ] Battery percentage and charging state (`pmset -g batt`)
- [ ] Thermal / CPU throttling state (`sudo powermetrics`, gated to laptops)
- [ ] APFS local snapshot count and oldest age (`tmutil listlocalsnapshots /`)

## Network

- [ ] Wi-Fi IP address
- [ ] Ethernet IP address (when connected)
- [ ] External IP (cached, slow path)
- [ ] Weather (`curl -s "wttr.in/Boise?format=3"` for one-liner)

## Updates & maintenance

- [ ] Homebrew: count of upgradable packages (`brew outdated | wc -l`)
- [ ] macOS: pending system updates (`softwareupdate -l`)
- [ ] Apple system status (parse the JSON endpoint, flag non-green services)
- [ ] Failed login / sudo attempts overnight (grep `system.log` or `last`)

## Development

- [ ] Per-repo git state across configured paths: branch, dirty count,
      unpushed commits (`git -C $path status --porcelain`,
      `git -C $path log @{u}..`)
- [ ] Calendar: next meeting (`icalBuddy` from Homebrew)

## Personal / informational

- [ ] Daily news feeds (RSS via `curl` + parse, cached)
- [ ] Sunrise / sunset times
- [ ] Moon phase (`curl -s wttr.in/moon`)
- [ ] ISS next overhead pass

## Fun & decoration

- [ ] ASCII art header
- [ ] Fortune with profanity enabled (`fortune -a` after `brew install fortune`)
- [ ] Random man page of the day (`man $(ls /usr/share/man/man1 | shuf -n 1)`)
- [ ] Random `apropos` rabbit hole

## Architectural improvements (infrastructure, not scripts)

- [ ] Per-script timeout wrapper (`gtimeout 5s zsh "${s}"`) so one hang
      doesn't stall MOTD generation
- [ ] Output caching for slow / network scripts to `/var/cache/macMOTD/`
      with TTL — fetch hourly, MOTD reads cache
- [ ] Expand `motd-helpers` library:
  - [ ] `motd_color` — consistent ANSI color helper
  - [ ] `motd_section_header` — visual separators
  - [ ] `motd_kv` — aligned "Label: value" rows
  - [ ] `motd_cached <ttl> <cmd>` — TTL-based output caching wrapper
- [ ] Convention: scripts that have nothing to report should output nothing,
      not "0 updates available" — keeps display informationally dense
- [ ] Conditional display gates (battery only on laptops, thermal only when
      hot, etc.) — let scripts self-skip via early `exit 0` with no output
