# ESC [ 5 m
#   ESC = ASCII 27
#   [   = CSI introducer
#   5m  = enable blinking
#
# ESC [ 0 m
#   reset all attributes back to normal

printf '\033[5mTHIS TEXT SHOULD BLINK\033[0m\n'


