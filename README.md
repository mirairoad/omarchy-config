# omarchy-config

Portable, public-safe Omarchy configuration managed with
[chezmoi](https://www.chezmoi.io/).

It captures the parts of my desktop that should feel consistent across
machines while leaving passwords, keys, accounts, hardware identities and
private data to be configured locally.

## Included

- Hyprland Lua configuration, keybinding overrides, gaps and rounding
- Desktop/laptop-aware monitor template
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
- Downloaded wallpapers without clear redistribution permission
- Omarchy runtime state and caches

## Install on a new Omarchy machine

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
chezmoi update
```

## Personal data and secrets

Configure accounts, passwords, SSH keys and machine identities directly on
each computer or through a dedicated password manager. Do not add them to this
public repository.

The MIT license covers repository-authored configuration and code. Third-party
assets retain their own licenses and should only be added when redistribution
is permitted.

The Nanoleaf widget remains visible but inactive on computers that do not have
the optional `nanoleaf-pegboard` command installed.
