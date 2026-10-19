/* dwm config.h: region screenshot to the clipboard (xregion selects, Esc or right click cancels). */
{ MODKEY|ShiftMask, XK_s, spawn, SHCMD("g=$(xregion) && grab -g \"$g\" - | xclip -selection clipboard -t image/png") },
