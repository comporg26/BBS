#!/bin/sh

# Width of the flag, in terminal character cells.
width=40

# Create one row consisting only of spaces.
row=$(printf '%*s' "$width" '')

# Red stripe.
printf '\033[41m%s\033[0m\n' "$row"

# Blue stripe.
printf '\033[44m%s\033[0m\n' "$row"

# Yellow/orange-ish stripe.
printf '\033[43m%s\033[0m\n' "$row"

