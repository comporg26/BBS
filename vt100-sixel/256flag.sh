#!/bin/sh

width=40
row=$(printf '%*s' "$width" '')

# These are approximate xterm-256color palette choices.
#
# 48;5;160m  -> dark/strong red
# 48;5;27m   -> blue
# 48;5;208m  -> orange
#
# 0m         -> reset

printf '\033[48;5;160m%s\033[0m\n' "$row"
printf '\033[48;5;27m%s\033[0m\n'  "$row"
printf '\033[48;5;208m%s\033[0m\n' "$row"

