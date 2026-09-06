# Theme Sync

Switch between a light and a dark Omarchy theme on a local-time schedule.

The plugin runs inside Omarchy Shell as a headless `service`: it reads the local
hour on a timer and, when the current theme is the configured light or dark
theme, hands it to `omarchy theme set`. Nothing else is touched — no wallpaper
of its own, no systemd unit, no second Quickshell process.

A bar widget cycles three modes with a click:

- **Auto** — the schedule decides (light from `lightFrom`, dark from `darkFrom`)
- **Light** — pinned to the light theme
- **Dark** — pinned to the dark theme

The mode survives restarts and is re-asserted on login. While pinned, the
schedule is suspended: switch themes freely, and the plugin leaves them alone
until you click back to Auto.

## Requirements

- Omarchy 4 (Quattro) or newer, with the Quickshell plugin system
- `omarchy theme set`, shipped with Omarchy — nothing else

## Install

```sh
omarchy plugin add https://github.com/geoochi/omarchy-theme-sync.git --enable
```

The service starts immediately. To also get the bar button, enable it with a
placement (it defaults to the right section):

```sh
omarchy plugin enable io.github.geoochi.theme-sync --section right --after omarchy.power
```

`omarchy bar move io.github.geoochi.theme-sync --section right` moves it later.

## Configure

Defaults are a light theme from 07:00 and a dark one from 19:00. Override any of
them in `~/.config/omarchy/theme-sync/config.json`:

```json
{
  "lightTheme": "catppuccin-latte",
  "darkTheme": "tokyo-night",
  "lightFrom": 7,
  "darkFrom": 19,
  "checkIntervalMinutes": 10
}
```

The file is watched, so saving it applies the new schedule immediately. Deleting
it falls back to the defaults above. A `config.json` created after the shell
already started is picked up on the next check rather than instantly.

Times are local: the hour comes from the system clock in the timezone the
session is running in, so changing timezone (or crossing a DST boundary) is
picked up on the next check.

## How it decides

- Outside the configured pair — a theme you picked by hand, or a third theme —
  the current theme is never replaced. Switch back to either half of the pair
  and the schedule takes over again.
- A theme you set by hand inside the pair survives until the next check, then
  the schedule wins. That is the same contract the shell script version had.
- Saving or deleting `config.json` is an explicit action, so it syncs
  immediately — even over a theme you picked by hand. Switching modes from the
  bar or IPC is the same: an explicit instruction wins.
- Nothing happens when the theme is already the right one, and only one
  `omarchy theme set` runs at a time.

## Usage

```sh
omarchy-shell theme-sync status                  # current state as JSON
omarchy-shell theme-sync applyNow                # apply the theme for this hour right now
omarchy-shell theme-sync reload                  # re-read the config and the current theme
omarchy-shell theme-sync setMode light|dark|auto # pin or unpin the schedule
omarchy-shell theme-sync cycleMode               # auto -> light -> dark -> auto
```

The bar button does what `cycleMode` does.

## Remove

```sh
omarchy plugin remove io.github.geoochi.theme-sync
```

Removing the plugin leaves `~/.config/omarchy/theme-sync/config.json` in place so
a later reinstall reuses your schedule. Delete it separately if you do not want
that.

## License

MIT — see [LICENSE](LICENSE).
