#!/bin/sh

width=40
row=$(printf '%*s' "$width" '')

# ESC [ 48 ; 2 ; R ; G ; B m
#
# 48 = background color
# 2  = RGB / true-color mode
#
# Armenian flag colors, approximately:
# red    #D90012 = 217, 0, 18
# blue   #0033A0 =   0, 51, 160
# orange #F2A800 = 242, 168, 0

printf '\033[48;2;217;0;18m%s\033[0m\n' "$row"
printf '\033[48;2;0;51;160m%s\033[0m\n' "$row"
printf '\033[48;2;242;168;0m%s\033[0m\n' "$row"

