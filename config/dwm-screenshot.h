/* dwm config.h: region screenshot to the clipboard (hacksaw selects, Esc cancels). */
{ MODKEY|ShiftMask, XK_s, spawn, SHCMD("g=$(hacksaw) && grab -g \"$g\" - | xclip -selection clipboard -t image/png") },
