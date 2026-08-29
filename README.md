# omarchy-config

Portable, public-safe Omarchy configuration managed with
[chezmoi](https://www.chezmoi.io/).

It captures the parts of my desktop that should feel consistent across
machines while leaving passwords, keys, accounts, hardware identities and
private data to be configured locally.

## Included

- Hyprland Lua configuration, keybinding overrides, gaps and rounding
- Desktop/laptop-aware monitor and input templates
- Omarchy Shell layout and menu extension
- Local workspace and Nanoleaf Pegboard shell widgets
- The third-party btop activity widget, fetched from its upstream repository
- Wifus color theme with an original generated placeholder image
- Foot and Fastfetch configuration
- Small, curated package manifests

## Deliberately excluded

- Passwords, tokens, API keys and SSH keys
- Wi-Fi, Bluetooth and Syncthing device identities
- Browser profiles and application databases
- Machine-specific monitor identifiers beyond a safe laptop default
- Original, uncompressed wallpaper files
- Omarchy runtime state and caches

## Install on a new Omarchy machine

### Quick install

Run this from a terminal on an existing Omarchy installation:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/mirairoad/omarchy-config/main/install.sh)
```

The installer fetches chezmoi through Omarchy when necessary, presents a
`desktop`/`laptop` selection, installs the managed configuration, and
applies the Wifus theme. Sudo authentication happens locally through Omarchy;
the script does not receive or store the password.

If you prefer to inspect downloaded scripts before executing them:

```bash
curl -fsSLO https://raw.githubusercontent.com/mirairoad/omarchy-config/main/install.sh
less install.sh
bash install.sh
```

### Manual install

Install chezmoi first:

```bash
omarchy pkg add chezmoi
```

Then initialize and preview the changes:

```bash
chezmoi init mirairoad/omarchy-config
chezmoi diff
```

Apply when the preview looks right:

```bash
chezmoi apply
```

Chezmoi asks whether the machine is a `desktop` or `laptop`. Package
installation may ask for the local sudo password; no password is stored.

### Machine roles

| Role | Behavior |
| --- | --- |
| `desktop` | Uses automatic monitor discovery with the shared scale, bindings, 2px gaps, 8px rounding, shell layout and theme. |
| `laptop` | Targets the internal `eDP-1` display and additionally enables natural/inverse touchpad scrolling plus three-finger drag. |

Omarchy continues to provide its standard shortcuts. Personal additions and
overrides live in `~/.config/hypr/bindings.lua` and are managed by this
repository. The shared appearance settings, including gaps and rounding, live
in `~/.config/hypr/looknfeel.lua`.

### Wallpapers

The Wifus wallpapers are stored as high-quality WebP files. Their original
pixel dimensions are preserved, metadata is removed, and the complete set is
about 4 MB instead of 76 MB.

After applying, inspect monitor names and supported modes:

```bash
hyprctl monitors all
```

Edit `~/.config/hypr/monitors.lua` through chezmoi if the generated default is
not appropriate:

```bash
chezmoi edit --apply ~/.config/hypr/monitors.lua
```

## Daily workflow

Edit a managed file and apply it:

```bash
chezmoi edit --apply ~/.config/hypr/bindings.lua
```

Commit from the source repository:

```bash
chezmoi cd
git add .
git commit -m "Update keybindings"
git push
```

Update another machine:

```bash
~/.local/share/chezmoi/update.sh
```

Or fetch and run the newest updater directly:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/mirairoad/omarchy-config/main/update.sh)
```

The updater is intentionally authoritative: GitHub wins when a managed file
was edited locally. Before enforcing the repository, it archives the existing
Hyprland, Omarchy, Foot and Fastfetch configuration under:

```text
~/.local/state/omarchy-config/backups/
```

It then runs `chezmoi update --force`, applies Wifus through the live Omarchy
theme path, restarts Omarchy Shell so background selection works immediately,
reloads Hyprland and checks `hyprctl configerrors`. The updater prints a
restore command for the backup created during that run.

## Personal data and secrets

Configure accounts, passwords, SSH keys and machine identities directly on
each computer or through a dedicated password manager. Do not add them to this
public repository.

The MIT license covers repository-authored configuration and code. Third-party
assets retain their own licenses and should only be added when redistribution
is permitted.

The Nanoleaf widget remains visible but inactive on computers that do not have
the optional `nanoleaf-pegboard` command installed.
