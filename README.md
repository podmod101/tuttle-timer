# tuttle-timer

A countdown timer and alarm widget for the [Omarchy](https://omarchy.org/) bar,
modelled on `xfce4-timer-plugin`. It shows the soonest remaining time next to
its icon, and a click opens a panel to manage several timers at once.

## Features

- Several timers at once; the bar shows the soonest one
- Presets (1m, 5m, 10m, 15m, 30m) or a typed time
- Alarms for a clock time (`@7:30` = the next 07:30)
- Pause, resume, restart, repeat and remove per timer
- On finish: critical notification, alarm sound, and an optional command
- Timers keep absolute end times in `~/.local/state/podmod101.timer/timers.json`,
  so they survive shell restarts

### Time formats

| Input      | Meaning                    |
|------------|----------------------------|
| `5`        | 5 minutes                  |
| `90s`      | 90 seconds                 |
| `1h30m`    | 1 hour 30 minutes          |
| `1:30:00`  | 1 hour 30 minutes (h:m:s)  |
| `@7:30`    | alarm at the next 07:30    |

## Install

Requires Omarchy (Quickshell shell), `notify-send` and `pw-play`.

```bash
omarchy plugin add https://github.com/podmod101/tuttle-timer.git --enable
```

Or by hand:

```bash
mkdir -p ~/.config/omarchy/plugins/podmod101.timer
cp manifest.json Timer.qml ~/.config/omarchy/plugins/podmod101.timer/
omarchy plugin enable podmod101.timer --section centerEnd
```

The plugin id is `podmod101.timer`, so it must live in a folder of that name.

## Moving it around the bar

The label grows the widget while a timer runs, so put it where a wider widget
won't collide with neighbours. Move it with `omarchy bar move`:

```bash
omarchy bar move podmod101.timer --section centerEnd   # next to the weather icon (default here)
omarchy bar move podmod101.timer --section left        # far left of the bar
omarchy bar move podmod101.timer --section right       # right side, by the tray
```

Sections, in order along the bar: `left`, `centerBegin`, `center`,
`centerEnd`, `right`. Put it in `centerBegin` or `centerEnd`, not `center`, or
the clock moves off centre. The layout is stored in
`~/.config/omarchy/shell.json`, which hot-reloads on save.

Other commands:

```bash
omarchy plugin list                       # see whether it is enabled
omarchy plugin disable podmod101.timer    # turn it off
omarchy restart shell                     # needed after editing Timer.qml
```

## Notes

- After editing `Timer.qml`, run `omarchy restart shell`. A running shell keeps
  the old copy of the widget and the edit will not show up otherwise.
- Don't place it on the far right next to the tray: the label makes it wide and
  it can crowd the tray icons.
