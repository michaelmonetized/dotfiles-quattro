# dotfiles-quattro

Fourth iteration of my dotfiles. Arch Linux, [Omarchy](https://omarchy.org), Hyprland. Every config here earns its place or it gets deleted.

Simplicity is prerequisite for reliability. Same rule applies to a window manager.

## Who I Am

Michael C Hurley — Canton, North Carolina.

20+ years building businesses and the software that runs them. Full-stack developer (bash, C, PHP, TypeScript, Swift) with CTO and P&L-carrying operator experience. I've grown a restaurant from $1.3M to $5.4M in annual revenue, scaled a studio from $50K to $387K in net profit, and taken two companies through successful exits. Spoken at Digital Summit 2015 and Internet Summit (iSummit '16).

I build complex systems as simply as possible. This repo is that philosophy applied to my daily driver.

- Website: [michaelchurley.com](https://www.michaelchurley.com)
- GitHub: [@michaelmonetized](https://github.com/michaelmonetized)

## The Arc

| Years | Chapter |
|---|---|
| 1996–2003 | Regional Manager, Corporate Cleaning. First P&L, first team. |
| 2001–2003 | Trident Technical College — AA, Commercial Graphics. |
| 2003–2007 | College of Charleston — BS, Computer Science. Production Manager at Signs R Us on the side. |
| 2007–2010 | Founder, StudioTWELVE design agency. Grew $50K → $387K annual net profit. Sold for $1.2M. |
| 2010–2014 | Owner/operator, Hurley's Creekside Dining & Rhum Bar. Grew $1.3M → $5.4M revenue. Sold. |
| 2014–2015 | Franchisee Partner, Papa Johns. Learned what scale really means. |
| 2015–2024 | Director, White Fox Studios. Grew accounts from 30 to 350 with 98% retention. |
| 2023–2024 | CTO, Realay.com. Onboarded 60,000 users. Successful exit with 20% buy-out. |
| 2024–now | Director, Hustle Launch. Building the next thing. |

Design and engineering were never separate careers. They're the same job: remove everything that doesn't work.

## What's Inside

Omarchy-based setup on Hyprland. The pieces that matter:

- `hypr/` — Hyprland config, window rules, keybinds
- `omarchy/` — Omarchy config plus my own theme ([hurleyus](https://github.com/michaelmonetized/omarchy-hurleyus-theme), wired in as a submodule)
- `nvim/` — Neovim, configured the way I want it
- `tmux/` + `tmux-powerline/` — terminal multiplexer setup
- `zsh/` + `starship.toml` — shell and prompt
- `atuin/`, `lazygit/`, `thefuck/`, `mise/` — workflow tooling
- Terminals: `alacritty/`, `foot/`, `kitty/`, `ghostty/` — yes, all four. One has to win.
- `btop/`, `systemd/`, `environment.d/` — system-level glue

## Install

Clone straight into `~/.config`:

```sh
git clone --recurse-submodules git@github.com:michaelmonetized/dotfiles-quattro ~/.config
```

Assumes Arch + Omarchy. If you're not on Omarchy, read the configs and steal what's useful instead of running anything blind.

## License

Do whatever you want with it. Attribution appreciated, never required.
