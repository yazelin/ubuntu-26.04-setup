#!/bin/bash
# Install Zellij — a terminal multiplexer (split panes / tabs / persistent
# sessions) — at user level, no sudo, no compiling.
#
# ─── Common scenarios ────────────────────────────────────────────────
#
#   I want Zellij:
#       bash setup-zellij.sh
#
#   I already have it, just grab the latest release:
#       bash setup-zellij.sh --update
#
#   I want it gone (keep my config):
#       bash setup-zellij.sh --uninstall
#
#   I want it gone, config and all:
#       bash setup-zellij.sh --uninstall --purge
#
# ─── Why the GitHub release binary, not apt / not cargo ──────────────
#
#   apt on 26.04 either lacks zellij or ships an old build — same story
#   as node / python / rust in this repo, so we follow the same pattern:
#   take the project's own up-to-date artifact, not the distro package.
#
#   We pull the prebuilt static musl binary from GitHub releases (one
#   file, dropped into ~/.local/bin). That avoids BOTH:
#     - piping a remote shell script straight into bash, and
#     - a multi-minute `cargo install` compile.
#
# ─── Why Zellij is a safe pick on this 26.04 box ─────────────────────
#
#   Zellij is a *terminal multiplexer* — it runs INSIDE whatever terminal
#   emulator you already have (GNOME Console, etc) and only deals with
#   text. It never talks to the display server, so the Wayland-only /
#   no-Xorg situation on 26.04 is irrelevant to it. Nothing to break.
#
# ─── Flag reference ──────────────────────────────────────────────────
#
#   --update       Re-download the latest release over the existing one
#   --uninstall    Remove the ~/.local/bin/zellij binary
#   --purge        With --uninstall, also delete ~/.config/zellij
#   -h, --help     Print this help

set -e

for arg in "$@"; do
    if [ "$arg" = "-h" ] || [ "$arg" = "--help" ]; then
        sed -n '/^#!/,/^set -e$/p' "$0" \
            | sed -e '1d' -e '/^set -e$/,$d' -e 's/^# \{0,1\}//'
        exit 0
    fi
done

# This script runs as the user, NOT root — it installs into ~/.local/bin
if [ "$EUID" -eq 0 ]; then
    echo "Don't run this as root. Zellij installs into your home directory."
    echo "Run as: bash $0 [flags]"
    exit 1
fi

ACTION="install"
PURGE="no"
for arg in "$@"; do
    case "$arg" in
        --update)    ACTION="update" ;;
        --uninstall) ACTION="uninstall" ;;
        --purge)     PURGE="yes" ;;
    esac
done

BIN_DIR="$HOME/.local/bin"
BIN_PATH="$BIN_DIR/zellij"
CONFIG_DIR="$HOME/.config/zellij"
LAYOUT_DIR="$CONFIG_DIR/layouts"

# --- UNINSTALL PATH ---
if [ "$ACTION" = "uninstall" ]; then
    if [ -f "$BIN_PATH" ]; then
        echo "==> Removing $BIN_PATH"
        rm -f "$BIN_PATH"
    else
        echo "    No zellij binary at $BIN_PATH"
    fi
    if [ "$PURGE" = "yes" ]; then
        echo "==> Purging $CONFIG_DIR"
        rm -rf "$CONFIG_DIR"
    else
        echo "    Kept your config at $CONFIG_DIR (use --purge to remove)"
    fi
    echo ""
    echo "Done."
    exit 0
fi

# --- INSTALL / UPDATE share the download path ---

# Map uname arch to zellij's release asset naming
RAW_ARCH="$(uname -m)"
case "$RAW_ARCH" in
    x86_64)  ASSET="zellij-x86_64-unknown-linux-musl.tar.gz" ;;
    aarch64) ASSET="zellij-aarch64-unknown-linux-musl.tar.gz" ;;
    *)
        echo "Unsupported architecture: $RAW_ARCH"
        echo "Check https://github.com/zellij-org/zellij/releases for a matching asset."
        exit 1
        ;;
esac
URL="https://github.com/zellij-org/zellij/releases/latest/download/$ASSET"

if [ "$ACTION" = "update" ] && [ ! -f "$BIN_PATH" ]; then
    echo "zellij not found at $BIN_PATH. Run without --update to install first."
    exit 1
fi

echo "==> 1/3  Downloading latest Zellij ($RAW_ARCH)"
mkdir -p "$BIN_DIR"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
curl --proto '=https' --tlsv1.2 -fL "$URL" -o "$TMP_DIR/zellij.tar.gz"

echo "==> 2/3  Installing into $BIN_DIR"
tar -xzf "$TMP_DIR/zellij.tar.gz" -C "$TMP_DIR"
install -m 0755 "$TMP_DIR/zellij" "$BIN_PATH"

echo "==> 3/3  Installing starter layouts (non-destructive)"
mkdir -p "$LAYOUT_DIR"

# Write a layout from stdin only if it doesn't already exist, so re-runs
# and --update never clobber edits you've made to your own layouts.
install_layout() {
    local dest="$LAYOUT_DIR/$1.kdl"
    if [ -f "$dest" ]; then
        echo "    $1.kdl exists — leaving your version untouched."
    else
        cat > "$dest"
        echo "    Wrote $dest"
    fi
}

install_layout dev <<'KDL'
// Starter Zellij layout — edit this file freely, it's yours now.
//
// Launch with:   zellij --layout dev      (or: zellij -l dev)
// IMPORTANT:     layouts do NOT hot-reload. After editing, close the
//                session and relaunch with -l dev to see the change.
//
// split_direction="vertical"   => panes side-by-side   (left | right)
// split_direction="horizontal" => panes stacked         (top / bottom)
//
// To auto-launch claude in a pane, give it a cwd + command, e.g.:
//     pane cwd="/home/ct/project/mori-desktop" command="claude"
// (the cwd must exist or the pane errors — that's why the panes below
//  just open plain shells until you fill in your own paths)

layout {
    // Keep the default top tab-bar + bottom status/hint bar. The hint
    // bar is what shows you which keys do what — handy while learning.
    default_tab_template {
        pane size=1 borderless=true {
            plugin location="zellij:tab-bar"
        }
        children
        pane size=2 borderless=true {
            plugin location="zellij:status-bar"
        }
    }

    tab name="code" focus=true {
        pane split_direction="vertical" {
            pane   // left:  e.g. cwd="…/worktree-a" command="claude"
            pane   // right: e.g. cwd="…/worktree-b" command="claude"
        }
    }
    tab name="run" {
        pane
    }
}
KDL

install_layout grid4 <<'KDL'
// grid4 — 2x2 grid, four Claude Code sessions, all rooted in the launch dir.
//
// Launch from whatever directory you want them rooted in:
//     cd ~/project/mori-desktop && zellij -l grid4
// Every pane below omits cwd, so it inherits that launch directory.
//
// To pin a pane to its OWN directory / git worktree instead, add cwd:
//     pane cwd="/home/ct/project/mori-desktop-feat-a" command="claude"
//
// WARNING — no file locking across Claude sessions: four claudes sharing
// ONE working tree will clobber each other if two edit the same files or
// run git at the same time. Safe when each pane has a non-overlapping or
// read-only job; for parallel EDITING, give each pane its own worktree.
//
// Edits to this file apply on the NEXT `zellij -l grid4` (no hot-reload).

layout {
    // Keep the top tab-bar + bottom hint/status bar (shows you the keys).
    default_tab_template {
        pane size=1 borderless=true {
            plugin location="zellij:tab-bar"
        }
        children
        pane size=2 borderless=true {
            plugin location="zellij:status-bar"
        }
    }

    tab name="claude-x4" focus=true {
        pane split_direction="horizontal" {     // two rows, stacked
            pane split_direction="vertical" {    // top row: left | right
                pane command="claude"
                pane command="claude"
            }
            pane split_direction="vertical" {    // bottom row: left | right
                pane command="claude"
                pane command="claude"
            }
        }
    }
}
KDL

install_layout grid6 <<'KDL'
// grid6 — 3 columns x 2 rows = six Claude Code sessions in the launch dir.
//
// Launch:   cd <dir> && zellij -l grid6
// Panes omit cwd, so they inherit the launch directory (add cwd per pane
// to point each at its own project / git worktree — see grid4.kdl notes).
//
// Same WARNING as grid4: no file locking across sessions; prefer separate
// git worktrees for parallel editing.
//
// ERGONOMICS: six full Claude TUIs on a single laptop screen are CRAMPED
// (each pane ~1/3 width). This layout really wants a wide / external
// monitor. If you mostly want to FLIP between six sessions rather than
// watch all at once, tabs (one full-width claude each, Ctrl-t + number)
// are far comfier than a 6-way split — see tabs4.kdl.

layout {
    default_tab_template {
        pane size=1 borderless=true {
            plugin location="zellij:tab-bar"
        }
        children
        pane size=2 borderless=true {
            plugin location="zellij:status-bar"
        }
    }

    tab name="claude-x6" focus=true {
        pane split_direction="horizontal" {     // two rows, stacked
            pane split_direction="vertical" {    // top row: 3 across
                pane command="claude"
                pane command="claude"
                pane command="claude"
            }
            pane split_direction="vertical" {    // bottom row: 3 across
                pane command="claude"
                pane command="claude"
                pane command="claude"
            }
        }
    }
}
KDL

install_layout tabs4 <<'KDL'
// tabs4 — four FULL-WIDTH Claude Code sessions, one per tab (not split).
//
// Unlike grid4/grid6 (small panes side by side), each claude here gets the
// whole screen. You FLIP between them instead of watching all at once —
// much more readable when Claude's TUI wants width.
//
// Launch:   cd <dir> && zellij -l tabs4
// All four inherit the launch directory (no cwd). To point a tab at its
// own project / git worktree, add cwd to its pane, e.g.:
//     tab name="feat-a" { pane cwd="/home/ct/project/mori-feat-a" command="claude" }
//
// Switch tabs (default keys):
//     Ctrl-t then 1 / 2 / 3 / 4     jump to tab N
//     Ctrl-t then ← / →             previous / next tab
//
// Edits apply on the NEXT `zellij -l tabs4` (no hot-reload).

layout {
    default_tab_template {
        pane size=1 borderless=true {
            plugin location="zellij:tab-bar"
        }
        children
        pane size=2 borderless=true {
            plugin location="zellij:status-bar"
        }
    }

    tab name="claude-1" focus=true {
        pane command="claude"
    }
    tab name="claude-2" {
        pane command="claude"
    }
    tab name="claude-3" {
        pane command="claude"
    }
    tab name="claude-4" {
        pane command="claude"
    }
}
KDL

install_layout dual <<'KDL'
// dual — two Claude Code sessions side by side, both in the launch dir.
//
// The simplest "more than one claude" layout: left | right, full height.
// Launch:   cd <dir> && zellij -l dual
// Add cwd per pane to pin each to its own project / git worktree:
//     pane cwd="/home/ct/project/mori-feat-a" command="claude"
//
// No file locking across sessions — for parallel EDITING of one repo,
// point each pane at a separate git worktree.
//
// Edits apply on the NEXT `zellij -l dual` (no hot-reload).

layout {
    default_tab_template {
        pane size=1 borderless=true {
            plugin location="zellij:tab-bar"
        }
        children
        pane size=2 borderless=true {
            plugin location="zellij:status-bar"
        }
    }

    tab name="claude-x2" focus=true {
        pane split_direction="vertical" {
            pane command="claude"
            pane command="claude"
        }
    }
}
KDL

install_layout tabs6 <<'KDL'
// tabs6 — six FULL-WIDTH Claude Code sessions, one per tab (not split).
//
// The comfy alternative to grid6: instead of cramming six tiny panes onto
// one screen, each claude gets full width and you FLIP between them.
//
// Launch:   cd <dir> && zellij -l tabs6
// All six inherit the launch directory (no cwd). To point a tab at its
// own project / git worktree, add cwd to its pane, e.g.:
//     tab name="feat-a" { pane cwd="/home/ct/project/mori-feat-a" command="claude" }
//
// Switch tabs (default keys):
//     Ctrl-t then 1..6              jump to tab N
//     Ctrl-t then ← / →             previous / next tab
//
// Edits apply on the NEXT `zellij -l tabs6` (no hot-reload).

layout {
    default_tab_template {
        pane size=1 borderless=true {
            plugin location="zellij:tab-bar"
        }
        children
        pane size=2 borderless=true {
            plugin location="zellij:status-bar"
        }
    }

    tab name="claude-1" focus=true {
        pane command="claude"
    }
    tab name="claude-2" {
        pane command="claude"
    }
    tab name="claude-3" {
        pane command="claude"
    }
    tab name="claude-4" {
        pane command="claude"
    }
    tab name="claude-5" {
        pane command="claude"
    }
    tab name="claude-6" {
        pane command="claude"
    }
}
KDL

install_layout hybrid <<'KDL'
// hybrid — the ergonomic sweet spot: two claude side by side on the main
// tab (watch both at once), PLUS two more full-width claude on their own
// tabs. Four sessions total, but only the two you care about share the
// screen; flip to the others with Ctrl-t + 2 / 3.
//
// Launch:   cd <dir> && zellij -l hybrid
// All panes inherit the launch dir (add cwd to pin to worktrees/projects).
//
// Switch tabs (default keys):
//     Ctrl-t then 1 / 2 / 3        jump to tab N
//     Ctrl-t then ← / →            previous / next tab
//
// Edits apply on the NEXT `zellij -l hybrid` (no hot-reload).

layout {
    default_tab_template {
        pane size=1 borderless=true {
            plugin location="zellij:tab-bar"
        }
        children
        pane size=2 borderless=true {
            plugin location="zellij:status-bar"
        }
    }

    tab name="main" focus=true {
        pane split_direction="vertical" {
            pane command="claude"
            pane command="claude"
        }
    }
    tab name="claude-3" {
        pane command="claude"
    }
    tab name="claude-4" {
        pane command="claude"
    }
}
KDL

install_layout cockpit <<'KDL'
// cockpit — one tab per project, a launchpad across your repos.
//
// Each tab opens a plain shell already cd'd into a project, so you just
// type `claude` (or anything) when you're ready in that repo. Uncomment a
// tab's `command="claude"` line to have it auto-launch claude there.
//
// NOTE: each cwd must point at a directory that EXISTS, or that pane
// errors. The paths below are this machine's repos — edit as they move.
// (This layout is intentionally machine-specific; the grid/tabs/dual/dev
//  layouts stay path-free and portable.)
//
// Launch:   zellij -l cockpit      (launch dir doesn't matter — each tab
//                                    sets its own cwd)
// Switch:   Ctrl-t then 1..4  (or Ctrl-t then ← / →)

layout {
    default_tab_template {
        pane size=1 borderless=true {
            plugin location="zellij:tab-bar"
        }
        children
        pane size=2 borderless=true {
            plugin location="zellij:status-bar"
        }
    }

    tab name="mori" focus=true {
        pane cwd="/home/ct/project/mori-desktop"
        // auto-launch instead:
        //   pane cwd="/home/ct/project/mori-desktop" command="claude"
    }
    tab name="agentos" {
        pane cwd="/home/ct/agentos"
    }
    tab name="blog" {
        pane cwd="/home/ct/yazelin.github.io"
    }
    tab name="scratch" {
        pane
    }
}
KDL

echo ""
echo "Done. Version:"
"$BIN_PATH" --version
echo ""

# PATH sanity check — ~/.local/bin is on PATH by default on Ubuntu via
# ~/.profile, but only after a fresh login. Warn if this shell can't see it.
case ":$PATH:" in
    *":$BIN_DIR:"*) : ;;
    *)
        echo "NOTE: $BIN_DIR is not on this shell's PATH yet."
        echo "      Open a new login session, or run:  export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo ""
        ;;
esac

echo "Try it:"
echo "  zellij                 # blank session; hint bar at the bottom shows keys"
echo "  zellij -l dev          # starter 2-pane layout (~/.config/zellij/layouts/)"
echo "  zellij attach          # reattach to a running session after closing the terminal"
echo ""
echo "Bundled claude layouts (zellij -l <name>):"
echo "  dual   2 panes side by side        grid4  2x2 four claude"
echo "  grid6  3x2 six claude              tabs4  four full-width claude tabs"
echo "  tabs6  six claude tabs             hybrid 2 panes + 2 claude tabs"
echo "  cockpit  one tab per project (mori / agentos / blog)"
echo ""
echo "First keys to know (default):"
echo "  Ctrl-p then n          # new pane"
echo "  Ctrl-p then arrows     # move focus between panes"
echo "  Ctrl-t then n          # new tab"
echo "  Ctrl-q                 # quit"
