#!/usr/bin/env python3
"""Cheat-sheet popup for tmux (bound to prefix+i in ~/.tmux.conf).

Edit BLOCKS below — layout, padding, and colors are automatic.
Blocks are laid out two per row, in order. Any key closes the popup.
"""

BLOCKS = [
    ("TMUX SESSIONS", [
        ("C-s o", "session picker"),
        ("C-s L", "last session (toggle)"),
        ("C-s N", "notes session"),
        ("C-s s", "native session tree"),
        ("C-s i", "this cheat sheet"),
    ]),
    ("INSIDE THE PICKER", [
        ("type + enter", "fuzzy filter, go / create"),
        ("^t / ^x", "only tmux / only dirs"),
        ("^g / ^a", "only configs / all"),
        ("^d", "kill highlighted session"),
        ("^n", "new session named as typed"),
    ]),
    ("NVIM GIT DIFF", [
        ("SPC ht", "toggle inline diff overlay"),
        ("SPC hB", "cycle base: index/HEAD/main"),
        ("]h / [h", "next / prev hunk"),
        ("SPC hd", "split diff vs base"),
    ]),
    ("NVIM HUNKS", [
        ("SPC hp", "preview hunk"),
        ("SPC hs / hr", "stage / reset hunk"),
        ("SPC hb", "blame line"),
        ("SPC gd", "Diffview all files"),
    ]),
    ("NVIM JUMP BACK", [
        ("C-o / C-i", "jumplist back / forward"),
        ("g; / g,", "older / newer change"),
        ("gd  C-o", "goto def, then jump back"),
        ("` `", "toggle last position"),
        ("SPC Tab", "last buffer"),
    ]),
    ("PR DIFF REVIEW (in order)", [
        ("SPC op", "PR picker"),
        ("C-o", "checkout highlighted PR"),
        ("SPC gP", "diff: tree + side-by-side"),
        ("j/k Enter", "open file's diff in tree"),
        ("]c / [c", "jump between changes"),
        ("gf", "edit real file at line"),
        ("g Tab", "bounce back to diff"),
        ("SPC e", "focus diff file tree"),
        (":DiffviewClose", "done"),
        ("git checkout -", "back to your branch"),
    ]),
    ("SHELL", [
        ("z name", "jump to dir (zoxide)"),
        ("sesh connect x", "create/attach session"),
    ]),
]

INNER = 46   # text width inside each block
KEYW = 15    # key column width
GAP = "  "

B = "\033[38;2;0;191;255m"   # border — electric blue
K = "\033[1;36m"             # keys — bold cyan
T = "\033[1m"                # block titles — bold, theme's default fg
R = "\033[0m"


def render_block(title, rows):
    lines = []
    dashes = INNER - len(title) - 3
    lines.append(f"{B}╭─ {R}{T}{title}{R}{B} {'─' * dashes}╮{R}")
    for key, desc in rows:
        desc = desc[: INNER - KEYW - 3]
        body = desc.ljust(INNER - KEYW - 2)
        lines.append(f"{B}│{R} {K}{key.ljust(KEYW)}{R} {body}{B}│{R}")
    lines.append(f"{B}╰{'─' * INNER}╯{R}")
    return lines


def blank_line():
    return " " * (INNER + 2)


def main():
    print()
    for i in range(0, len(BLOCKS), 2):
        pair = [render_block(t, r) for t, r in BLOCKS[i : i + 2]]
        height = max(len(p) for p in pair)
        for p in pair:
            p += [blank_line()] * (height - len(p))
        for parts in zip(*pair):
            print(" " + GAP.join(parts))
        print()

    # wait for any single keypress, then exit
    import sys, termios, tty
    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        sys.stdin.read(1)
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old)


if __name__ == "__main__":
    main()
