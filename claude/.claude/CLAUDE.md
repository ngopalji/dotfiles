## Opening files in my editor

When I ask you to open, show, or take me to a file or line ("open that", "show me where it changed", "jump to the definition"), run `nvim-open path/to/file[:line[:col]]` instead of printing the file. It opens it in my running nvim (the one in your herdr tab, else your herdr workspace, else a new pane beside you) and focuses that pane. Several locations: open the one I most likely want and list the rest as `path:line`. Don't call it unprompted — it moves my editor and focus. `nvim-open --list` shows which nvims are running.
