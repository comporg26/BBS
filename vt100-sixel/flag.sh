# Armenian flag using ANSI background colors.
#
# ESC [ 41 m = red background
# ESC [ 44 m = blue background
# ESC [ 43 m = yellow background
# ESC [ 0 m  = reset attributes
#
# Note:
# Standard ANSI has "yellow", not a precise Armenian orange.
# We use yellow here because it belongs to the basic 8-color palette.

printf '\033[41m                    \033[0m\n'
printf '\033[44m                    \033[0m\n'
printf '\033[43m                    \033[0m\n'

