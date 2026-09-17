# Introduction to VT100, Sixel, and ReGIS

## 1. The important idea: a terminal is an interpreter

A traditional video terminal is not a bitmap display controlled directly by the computer.

The host computer sends a **stream of bytes** over a serial line. Most bytes are ordinary characters:

```text
H e l l o
```

The terminal displays them and moves its cursor.

Some bytes are **control characters** or begin **control sequences**. Those bytes tell the terminal to do things such as:

- move the cursor;
- erase part of the screen;
- change text attributes;
- select a character set;
- draw graphics.

So a terminal can be thought of as a small interpreter:

```text
host program
    |
    | bytes
    v
terminal parser
    |
    +--> characters
    +--> cursor movement
    +--> screen editing
    +--> text attributes
    +--> graphics
```

The keyboard works in the other direction: the terminal sends bytes back to the host.

This model is still visible today. A modern terminal emulator such as `xterm` is software, but it is still interpreting a byte stream much like a hardware terminal did.

---

# 2. What was the VT100?

The DEC VT100 was a very influential text terminal.

Its display was fundamentally a grid of **character cells**, not a general-purpose pixel framebuffer exposed to the host.

A typical application therefore did not send the complete screen again and again. Instead, it could send commands such as:

```text
move cursor to row 10, column 20
print "Hello"
move cursor upward
erase this line
enable reverse video
```

This is one reason terminal applications can be extremely compact.

The VT100 used control sequences based largely on the ANSI terminal-control standards of the time, together with some DEC-specific commands.

Modern terminals support many extensions that the original VT100 did **not** have, so the expressions "ANSI terminal" and "VT100 terminal" are often used more loosely today than they should be.

---

# 3. ESC, CSI, and control sequences

The ASCII **ESC** character has value:

```text
decimal:     27
hexadecimal: 1B
octal:       033
```

In shell examples we can generate it with:

```sh
printf '\033'
```

The four visible characters:

```text
\033
```

are not sent to the terminal. The shell's `printf` turns them into the single byte `0x1b`.

Many VT100 commands begin with:

```text
ESC [
```

This is called **CSI**, the Control Sequence Introducer, in its 7-bit representation.

For example:

```text
ESC [ 10 ; 20 H
```

means approximately:

```text
put the cursor at row 10, column 20
```

From a shell:

```sh
printf '\033[10;20H'
```

---

# 4. First VT100 experiments

These examples should work in almost every modern terminal emulator.

## Clear the screen

```sh
printf '\033[2J'
```

## Move the cursor home

```sh
printf '\033[H'
```

We often combine the two:

```sh
printf '\033[2J\033[H'
```

## Move to row 10, column 20

```sh
printf '\033[10;20HHello'
```

The terminal does not receive nineteen spaces and nine newline characters.

It receives a short command telling it where the cursor should go.

## Move the cursor

```sh
# Up 3 rows
printf '\033[3A'

# Down 3 rows
printf '\033[3B'

# Right 5 columns
printf '\033[5C'

# Left 5 columns
printf '\033[5D'
```

The general form is:

```text
ESC [ n A     cursor up
ESC [ n B     cursor down
ESC [ n C     cursor right
ESC [ n D     cursor left
```

If `n` is omitted, the default is normally 1.

---

# 5. Text attributes

The command ending in `m` is called **SGR**, Select Graphic Rendition.

For example:

```sh
printf '\033[7mreverse video\033[0m\n'
```

Useful classic attributes include:

```text
ESC [ 0 m     reset attributes
ESC [ 1 m     increased intensity / bold
ESC [ 4 m     underline
ESC [ 5 m     blink
ESC [ 7 m     reverse video
```

For example:

```sh
printf 'normal '
printf '\033[4munderlined\033[0m '
printf '\033[7mreverse\033[0m\n'
```

### A historical warning about color

Commands such as:

```text
ESC [ 31 m
```

for red text are common on modern terminals, but **ANSI color was not a feature of the original VT100**.

When teaching terminal protocols it is useful to separate:

1. what the real VT100 implemented;
2. later DEC terminal features;
3. later ANSI/ECMA features;
4. extensions added by modern terminal emulators.

---

# 6. VT100 "graphics" are not pixel graphics

The VT100 has a **DEC Special Graphics character set**.

It contains characters useful for drawing boxes and diagrams, including horizontal and vertical lines and corners.

For example:

```sh
printf '\033(0lqqqqk\r\nx    x\r\nmqqqqj\033(B\r\n'
```

On a compatible terminal this produces approximately:

```text
┌────┐
│    │
└────┘
```

The important point is that these are still **characters in character cells**.

The sequence:

```text
ESC ( 0
```

selects the DEC Special Graphics set.

The sequence:

```text
ESC ( B
```

selects ASCII again.

In the special graphics set, ordinary byte values are displayed differently. For example, the character `q` is displayed as a horizontal line.

So this is clever text-mode drawing, but it is not a bitmap protocol.

---

# 7. Three different ideas

It is useful to keep these three technologies separate:

| Technology | Main purpose | Basic object sent by host |
|---|---|---|
| VT100 controls | text-terminal control | characters and terminal commands |
| ReGIS | vector graphics | drawing instructions |
| Sixel | raster graphics | encoded pixels |

They can all travel through the same kind of terminal byte stream.

A program might theoretically send:

```text
text
VT control sequences
more text
ReGIS graphics
more text
Sixel bitmap
more text
```

provided the terminal understands all of those protocols.

---

# 8. ReGIS

**ReGIS** means **Remote Graphic Instruction Set**.

It appeared in DEC graphics terminals of the VT125 era and was supported by later graphics terminals such as the VT240 and VT340.

ReGIS is a **drawing language**.

Instead of saying:

> pixel 100,100 is on  
> pixel 101,100 is on  
> pixel 102,100 is on  
> ...

ReGIS can say something closer to:

> move to 100,100  
> draw a line to 400,300

This makes it conceptually similar to a very small vector graphics language.

Common ReGIS commands include:

```text
S     screen control
W     writing control
P     position
V     vector
C     curve
T     text
F     polygon fill
```

---

# 9. DCS: carrying a graphics language inside the terminal stream

ReGIS and Sixel are normally transported using a **DCS**, Device Control String.

In a 7-bit environment:

```text
DCS = ESC P
ST  = ESC \
```

`ST` means **String Terminator**.

So the general idea is:

```text
ESC P
    some special language
ESC \
```

The character immediately following the DCS parameters tells the terminal what kind of data follows.

For ReGIS, the selector is `p`.

For Sixel, the selector is `q`.

This gives us:

```text
ESC P p   ReGIS data   ESC \
ESC P q   Sixel data   ESC \
```

In shell notation:

```text
\033Pp ... \033\\
\033Pq ... \033\\
```

Notice that the final backslash itself must be escaped in the shell string.

---

# 10. First ReGIS example

A simple ReGIS line is:

```sh
printf '\033PpP[100,100]V[400,300]\033\\'
```

Read it as:

```text
ESC P p
P[100,100]
V[400,300]
ESC \
```

where:

```text
P[100,100]     position the graphics cursor
V[400,300]     draw a vector to 400,300
```

The terminal receives coordinates and performs the rasterization itself.

---

# 11. Draw a rectangle with ReGIS

```sh
printf '\033PpS(E)P[100,100]V[400,100]V[400,300]V[100,300]V[100,100]\033\\'
```

Broken into lines for readability:

```text
S(E)           erase the graphics screen

P[100,100]     move to the first corner

V[400,100]     draw right
V[400,300]     draw down
V[100,300]     draw left
V[100,100]     draw up
```

The rectangle can be hundreds of pixels wide, but the description is still only a small number of bytes.

That is one of the major advantages of a vector-oriented protocol.

---

# 12. Draw a circle with ReGIS

A simple circle example is:

```sh
printf '\033PpP[400,240]C[500,240]\033\\'
```

Here:

```text
P[400,240]
```

positions the graphics cursor at the center, and:

```text
C[500,240]
```

defines a circle whose radius reaches the specified point.

On a VT340-style graphics display, the classic graphics coordinate space is 800 × 480.

---

# 13. ReGIS text

ReGIS can also draw text as part of a graphics image.

For example:

```sh
printf '\033PpP[100,100]T"HELLO FROM REGIS"\033\\'
```

This is different from ordinary terminal text.

Ordinary text is placed into terminal character cells.

ReGIS text is part of the graphics language and is drawn in the graphics display.

---

# 14. A small ReGIS "house"

```sh
printf '\033PpS(E)P[200,300]V[200,150]V[300,80]V[400,150]V[400,300]V[200,300]\033\\'
```

Conceptually:

```text
          /\
         /  \
        /    \
       |      |
       |      |
       +------+
```

Only the important vertices are transmitted.

The terminal draws the lines between them.

---

# 15. Sixel

Sixel solves a different problem.

ReGIS says:

> draw a line  
> draw a circle  
> fill this shape

Sixel says, essentially:

> here are the pixels

Sixel is therefore a **raster graphics protocol**.

It was used by DEC printers and later by graphics-capable video terminals such as the VT240 family and VT330/VT340.

Modern terminal emulators can also implement it.

---

# 16. Why is it called "Sixel"?

The name comes from:

> **six pixels**

One Sixel data character describes a vertical column of **six pixels**.

A Sixel character contains a 6-bit value:

```text
bit 0     top pixel
bit 1
bit 2
bit 3
bit 4
bit 5     bottom pixel
```

The value is converted into a printable ASCII character by adding 63.

Therefore the Sixel data characters range from:

```text
?    ASCII 63
```

through:

```text
~    ASCII 126
```

The decoded value is:

```text
ASCII code - 63
```

---

# 17. Understanding individual Sixel characters

Consider these examples:

```text
Character   ASCII   Value   Pixels

?             63      0     000000
@             64      1     000001
A             65      2     000010
B             66      3     000011
...
~            126     63     111111
```

Remember that the **least significant bit is the top pixel**.

Therefore:

```text
~
```

means:

```text
█
█
█
█
█
█
```

one vertical column, six pixels tall.

---

# 18. The smallest useful Sixel example

Try:

```sh
printf '\033Pq~~~~~~\033\\'
```

The parts are:

```text
ESC P       begin DCS
q           this is Sixel data

~~~~~~      six columns;
            every column has all six pixels enabled

ESC \       end the DCS
```

Each `~` is one column six pixels high.

Six `~` characters therefore describe a solid:

```text
6 pixels wide × 6 pixels high
```

block.

This is an especially useful example because you can understand the entire bitmap by looking directly at the six Sixel characters.

---

# 19. A 6 × 6 Sixel checkerboard

The character:

```text
T
```

has ASCII value 84:

```text
84 - 63 = 21
```

and:

```text
21 = binary 010101
```

Since the least significant bit is the top pixel, its vertical pattern is:

```text
ON
OFF
ON
OFF
ON
OFF
```

The character:

```text
i
```

has ASCII value 105:

```text
105 - 63 = 42
```

and:

```text
42 = binary 101010
```

which gives the opposite vertical pattern.

Therefore this:

```sh
printf '\033PqTiTiTi\033\\'
```

produces a tiny checkerboard-like bitmap:

```text
█ █ █
 █ █ █
█ █ █
 █ █ █
█ █ █
 █ █ █
```

This is a good exercise because students can decode the image manually.

---

# 20. More than six pixels high

A Sixel data row describes a band six pixels high.

The `-` control moves to the next six-pixel band.

For example:

```sh
printf '\033Pq~~~~~~-~~~~~~\033\\'
```

contains two bands:

```text
first band:   6 pixels high
second band:  6 pixels high
```

so the image is 12 pixels high.

---

# 21. Sixel run-length encoding

Sixel has a simple repeat command:

```text
!nX
```

meaning:

```text
repeat Sixel character X n times
```

Instead of:

```text
~~~~~~~~~~~~
```

we can write:

```text
!12~
```

So a 12 × 12 solid block can be written as:

```sh
printf '\033Pq!12~-!12~\033\\'
```

The first:

```text
!12~
```

draws twelve completely filled columns in the first six-pixel band.

Then:

```text
-
```

moves to the next band.

The second:

```text
!12~
```

draws another twelve columns.

---

# 22. Sixel color

Sixel also supports color registers.

A common RGB form is:

```text
#number;2;red;green;blue
```

where the RGB values are percentages from 0 through 100.

For example:

```text
#1;2;100;0;0
```

defines color register 1 as red.

Then:

```text
#1
```

selects that register.

A small red square can therefore be sent with:

```sh
printf '\033Pq"1;1;12;12#1;2;100;0;0#1!12~-!12~\033\\'
```

The raster-attribute part:

```text
"1;1;12;12
```

declares square pixels and a nominal 12 × 12 raster.

Terminal implementations vary, so small details of placement, scrolling, palette handling, and image persistence can differ.

---

# 23. Useful Sixel control characters

Some of the most important Sixel syntax is:

```text
? through ~     six-pixel data characters

!nX             repeat X n times

$               carriage return inside the current
                six-pixel band

-               move to the next six-pixel band

#n              select color register n

#n;2;r;g;b      define RGB color register n

" ...           set raster attributes
```

A real image encoder mainly has to:

1. divide an image into six-pixel-high bands;
2. examine one vertical six-pixel column at a time;
3. turn those six pixels into a 6-bit value;
4. add 63;
5. output the resulting character;
6. use color and repeat commands where useful.

That is the heart of Sixel.

---

# 24. Why Sixel data is much larger than a VT100 command

This is where the comparison becomes interesting.

Suppose we have a monochrome image that is:

```text
800 × 480 pixels
```

The raw bitmap contains:

```text
800 × 480 = 384,000 bits
```

or:

```text
48,000 bytes
```

before any protocol encoding.

A naive Sixel encoding divides the image into:

```text
480 / 6 = 80
```

six-pixel bands.

Each band has 800 columns, so we need approximately:

```text
800 × 80 = 64,000
```

Sixel data characters before considering control commands or compression.

Run-length encoding can make simple images much smaller, but photographs or noisy images still require substantial data.

Now compare that to a VT100 command:

```text
ESC [ 10 ; 20 H
```

which is only a handful of bytes.

But the comparison is slightly unfair.

The VT100 command does **not contain an image**.

It merely tells the terminal to change some existing state.

---

# 25. ReGIS can be much smaller than Sixel for geometric pictures

Suppose we want a rectangle.

In Sixel, we eventually have to describe the pixels making up the rectangle.

In ReGIS we can send approximately:

```text
move here
draw there
draw there
draw there
draw back to the beginning
```

The size of the ReGIS program depends mostly on the number of geometric objects.

The size of a Sixel image depends much more directly on the number of pixels.

Therefore:

```text
text/control problem  -> VT-style control sequences

geometric drawing     -> ReGIS can be very compact

arbitrary bitmap      -> Sixel is appropriate
```

A photograph cannot easily be represented as a few ReGIS lines and circles.

That is exactly the kind of image for which a raster protocol makes sense.

---

# 26. "VT100 is smaller than Sixel" — a better way to say it

It is reasonable to feel that VT100 is "much smaller", but they are not exactly competing protocols.

A useful mental model is:

```text
VT100
    manages a text screen

ReGIS
    describes a drawing

Sixel
    describes a bitmap
```

The implementation requirements are therefore different.

A simple VT-style terminal needs something like:

```text
character grid
cursor
attributes
escape-sequence parser
scrolling
```

A Sixel implementation additionally needs things such as:

```text
Sixel parser
pixel storage
six-bit decoding
color registers
raster positioning
run-length decoding
```

A ReGIS implementation needs something closer to:

```text
ReGIS parser
graphics coordinate system
line rasterizer
circle/curve rasterizer
fill operations
graphics text
drawing state
```

So Sixel syntax itself is not necessarily enormous.

The **data it carries** is often enormous compared with a short VT100 command.

ReGIS syntax is also compact, but the terminal needs considerably more drawing logic to execute it.

---

# 27. An important architectural difference

With Sixel:

```text
HOST                              TERMINAL

bitmap
  |
Sixel encoder
  |
  +------ encoded pixels -------> Sixel decoder
                                      |
                                      v
                                   bitmap
                                      |
                                      v
                                   display
```

With ReGIS:

```text
HOST                              TERMINAL

geometry
  |
  +------ drawing commands ------> ReGIS interpreter
                                      |
                                      v
                                   rasterizer
                                      |
                                      v
                                   bitmap
                                      |
                                      v
                                   display
```

With ordinary VT100 text:

```text
HOST                              TERMINAL

characters + commands ----------> terminal interpreter
                                      |
                                      v
                                character-cell screen
```

These are three different divisions of work between the host and the terminal.

---

# 28. Why these protocols made sense over serial lines

Historical terminals often communicated at speeds that seem extremely slow today.

For example:

```text
9600 bit/s
19200 bit/s
```

At those speeds, sending fewer bytes matters a great deal.

For a text application, it would be absurd to send an entire bitmap framebuffer every time one character changes.

Instead, the host can send:

```text
move cursor
print one character
```

Vector graphics can also be efficient.

A ReGIS instruction describing a circle can be much smaller than transmitting every pixel in that circle.

Sixel accepts a larger data cost because it solves the harder problem of transporting an arbitrary raster image.

---

# 29. Why Sixel uses printable characters

A serial communications path was not always a perfectly transparent stream of arbitrary 8-bit binary values.

Sixel represents its six-bit pixel values using printable ASCII characters:

```text
? ... ~
```

This made the graphics data easier to transport through systems designed primarily around textual terminal traffic.

There is overhead compared with a tightly packed binary framebuffer, but the representation fits naturally into terminal communications.

---

# 30. 7-bit and 8-bit control representations

Later DEC terminals also understood C1 control characters.

For example, DCS and ST have 8-bit forms.

But the 7-bit forms are easy to type and demonstrate:

```text
DCS = ESC P
ST  = ESC \
```

Similarly:

```text
CSI = ESC [
```

This explains why escape sequences often look as though they are made from ordinary printable characters following an ESC byte.

---

# 31. A terminal stream is a little programming language

Consider:

```sh
printf '\033[2J\033[H'
printf 'HELLO'
printf '\033[10;20H'
printf 'WORLD'
```

This is almost a program:

```text
clear
home
print HELLO
goto 10,20
print WORLD
```

ReGIS makes this even more obvious:

```text
erase graphics
move
draw
draw
draw
write text
```

Sixel is different because most of its stream is data rather than high-level drawing instructions, but it still has its own parser state and commands.

Thinking of a terminal as a **virtual machine that interprets a bytecode-like language** is often more useful than thinking of it as a passive screen.

---

# 32. Modern terminal emulators

Modern terminal emulators may support:

- VT100-compatible control sequences;
- later VT200/VT300/VT400 features;
- ANSI colors;
- Unicode;
- mouse reporting;
- Sixel;
- ReGIS;
- many emulator-specific extensions.

Support must not be assumed.

For example, `xterm` can support Sixel and ReGIS when built and configured with those graphics capabilities. Other terminals may implement one, both, or neither.

This is why:

```sh
printf '\033Pq~~~~~~\033\\'
```

may display a tiny image in one terminal and do nothing useful in another.

The escape sequence is being sent either way.

The difference is whether the receiving terminal understands it.

---

# 33. Do not confuse `$TERM` with the actual protocol

Unix programs often inspect the environment variable:

```sh
echo "$TERM"
```

You may see values such as:

```text
xterm
xterm-256color
vt100
vt220
```

`$TERM` is primarily a name used to select a **terminfo/termcap capability description**.

It is not a perfect description of everything the terminal emulator actually supports.

For example, a terminal may support Sixel even though the `$TERM` name does not contain the word `sixel`.

Likewise, lying about `$TERM` can cause applications to send commands the actual terminal does not understand.

---

# 34. Suggested classroom experiment: inspect the bytes

Instead of merely looking at the screen, inspect the exact bytes.

For example:

```sh
printf '\033[10;20H' | od -An -tx1
```

You should see something corresponding to:

```text
1b 5b 31 30 3b 32 30 48
```

Decode it:

```text
1b     ESC
5b     [
31     1
30     0
3b     ;
32     2
30     0
48     H
```

The "mysterious terminal command" is simply eight bytes.

Try the smallest Sixel example:

```sh
printf '\033Pq~~~~~~\033\\' | od -An -tx1
```

Now identify:

```text
ESC P
q
six Sixel data characters
ESC \
```

This is a very useful way to remove the magic from terminal protocols.

---

# 35. Suggested programming exercise: decode one Sixel character

Write a program that accepts a Sixel character and prints its six pixels.

The core algorithm is:

```text
value = ASCII(character) - 63

for bit = 0 to 5:
    if value & (1 << bit):
        print "#"
    else:
        print "."
```

For:

```text
~
```

the result should be:

```text
#
#
#
#
#
#
```

For:

```text
T
```

the result should be:

```text
#
.
#
.
#
.
```

Once this works, students have already implemented the central idea of a Sixel decoder.

---

# 36. Suggested programming exercise: make a Sixel encoder

Start with a monochrome image only six pixels high.

For every X coordinate:

1. inspect the six vertical pixels;
2. form a six-bit integer;
3. add 63;
4. output that ASCII character.

For example, if the six pixels from top to bottom are:

```text
ON
OFF
ON
OFF
ON
OFF
```

the bit value is:

```text
00010101 binary
```

which is:

```text
21 decimal
```

Add 63:

```text
21 + 63 = 84
```

ASCII 84 is:

```text
T
```

So that entire six-pixel column becomes one byte:

```text
T
```

---

# 37. Suggested programming exercise: draw with ReGIS

Write a shell script that outputs:

```text
ESC P p
```

followed by ReGIS commands.

Start with:

```text
P[100,100]
V[400,100]
V[400,300]
V[100,300]
V[100,100]
```

and finish with:

```text
ESC \
```

Then change the coordinates.

Observe that increasing the rectangle from 100 pixels wide to 500 pixels wide does not require sending 400 additional pixels.

Only the numeric coordinate changes.

That is the central vector-graphics idea.

---

# 38. Suggested comparison exercise

Ask students to represent the same picture in three ways.

For example, draw a box.

### Method 1: character cells

Use DEC Special Graphics:

```text
┌──────┐
│      │
└──────┘
```

Advantages:

```text
very little data
very simple terminal
```

Disadvantages:

```text
restricted to character-cell geometry
```

### Method 2: ReGIS

Send four vectors.

Advantages:

```text
precise pixel-like coordinates
compact representation
scales well for geometry
```

Disadvantages:

```text
terminal must implement a graphics interpreter and rasterizer
not ideal for photographs
```

### Method 3: Sixel

Send the rasterized pixels.

Advantages:

```text
can represent arbitrary bitmap images
host controls exactly what pixels the image contains
```

Disadvantages:

```text
more data
terminal needs raster graphics storage and decoding
```

---

# 39. Historical progression

A simplified way to think about the DEC terminal family is:

```text
VT100
  |
  | text terminal control
  v
VT100 family
  |
  +------------------------------+
  |                              |
  v                              v
VT125                         later text terminals
  |
  | ReGIS graphics
  v
VT240 / VT241
  |
  | ReGIS + Sixel graphics
  v
VT330 / VT340
  |
  | richer graphics capabilities
  v
later DEC terminals and emulators
```

This diagram is intentionally simplified, but it helps show that Sixel is **not a feature of the original VT100**.

Likewise, ReGIS is not "a VT100 drawing command."

They belong to later DEC graphics-terminal technology while coexisting with VT-style terminal controls.

---

# 40. The main ideas to remember

If you remember only a few things, remember these:

1. **A terminal receives a byte stream and interprets it.**

2. **The VT100 is fundamentally a character-cell text terminal.**

3. **VT100 escape sequences manipulate terminal state; they do not transmit a framebuffer.**

4. **DEC Special Graphics gives the VT100 line-drawing characters, not arbitrary pixel graphics.**

5. **ReGIS is a vector-like graphics instruction language.**

6. **Sixel is a raster graphics encoding.**

7. **One Sixel character represents six vertical pixels.**

8. **Sixel values are encoded as printable characters from `?` through `~`.**

9. **ReGIS can describe geometric images in very few bytes because the terminal draws the geometry.**

10. **Sixel can represent arbitrary images, but its data volume generally grows with image size.**

11. **ReGIS and Sixel are carried inside DCS strings and can coexist with ordinary terminal text/control protocols.**

12. **Modern terminal emulators often implement a mixture of features from many generations of real terminals.**

---

# 41. Quick reference

## VT-style controls

```text
ESC [ 2 J          clear screen
ESC [ H            cursor home
ESC [ r ; c H      cursor to row r, column c
ESC [ n A          cursor up
ESC [ n B          cursor down
ESC [ n C          cursor right
ESC [ n D          cursor left
ESC [ 0 m          reset attributes
ESC [ 4 m          underline
ESC [ 7 m          reverse video
```

## DEC Special Graphics

```text
ESC ( 0            select special graphics
ESC ( B            select ASCII
```

## ReGIS

```text
ESC P p            begin ReGIS DCS
P[x,y]             position
V[x,y]             vector
C[x,y]             curve/circle
T"text"            graphics text
S(E)               erase graphics screen
ESC \              string terminator
```

## Sixel

```text
ESC P q            begin Sixel DCS
? ... ~            six-pixel data values
!nX                repeat X n times
$                   carriage return in band
-                   next six-pixel band
#n                  select color
#n;2;r;g;b          define RGB color
ESC \               string terminator
```

---

# 42. Tiny examples to keep

## VT100

```sh
printf '\033[2J\033[H'
printf '\033[10;20HHello'
```

## VT100 special graphics box

```sh
printf '\033(0lqqqqk\r\nx    x\r\nmqqqqj\033(B\r\n'
```

## Sixel 6 × 6 block

```sh
printf '\033Pq~~~~~~\033\\'
```

## Sixel checkerboard

```sh
printf '\033PqTiTiTi\033\\'
```

## Sixel 12 × 12 block using repetition

```sh
printf '\033Pq!12~-!12~\033\\'
```

## ReGIS line

```sh
printf '\033PpP[100,100]V[400,300]\033\\'
```

## ReGIS rectangle

```sh
printf '\033PpS(E)P[100,100]V[400,100]V[400,300]V[100,300]V[100,100]\033\\'
```

---


# 43. A genuine VT100 example: blinking text

Blinking text is a useful example because, unlike color, it really is part of
the original VT100's text attributes.

Try:

```sh
printf '\033[5mTHIS TEXT SHOULD BLINK\033[0m\n'
```

Break it into pieces:

```text
ESC [ 5 m
ESC [ 0 m
```

The first sequence:

```text
ESC [ 5 m
```

means:

```text
ESC [        begin a Control Sequence
5            SGR parameter 5: blink
m            Select Graphic Rendition
```

So:

```sh
printf '\033[5m'
```

changes the terminal's current text attributes.

The characters that follow are then displayed using the blinking attribute:

```text
THIS TEXT SHOULD BLINK
```

Finally:

```text
ESC [ 0 m
```

resets the attributes.

That reset is important. Terminal escape sequences modify **terminal state**.
They are not tags attached to a string.

Conceptually, the host sends:

```text
enable blink
print these characters
reset attributes
```

not:

```text
<blink>these characters</blink>
```

A slightly larger demonstration is:

```sh
printf 'normal text\n'
printf '\033[5mWARNING: BLINKING TEXT\033[0m\n'
printf 'normal again\n'
```

The byte stream is therefore roughly:

```text
normal text
ESC [ 5 m
WARNING: BLINKING TEXT
ESC [ 0 m
normal again
```

## Why might it not blink today?

Modern terminal emulators do not all render blinking text.

Some:

- support it normally;
- disable it by default;
- render it as another attribute;
- ignore it completely.

That does not make the escape sequence invalid. It simply means that modern
terminal emulators do not always reproduce every historical display effect.

---

# 44. An Armenian flag using terminal character cells

The Armenian flag is a good example of the difference between **terminal
attributes** and **pixel graphics**.

It has three horizontal stripes:

```text
red
blue
orange
```

The original VT100 was a monochrome terminal, so a real VT100 cannot display a
red, blue, and orange flag.

However, later ANSI-compatible terminals and modern terminal emulators support
color attributes.

A simple modern terminal version is:

```sh
# Armenian flag using basic ANSI background colors.
#
# ESC [ 41 m = red background
# ESC [ 44 m = blue background
# ESC [ 43 m = yellow background
# ESC [ 0 m  = reset attributes
#
# Basic ANSI has yellow rather than a good orange, so the third stripe
# is only an approximation.

printf '\033[41m                    \033[0m\n'
printf '\033[44m                    \033[0m\n'
printf '\033[43m                    \033[0m\n'
```

The important point is that we are **not sending an image**.

Consider the first line:

```sh
printf '\033[41m                    \033[0m\n'
```

It means:

```text
ESC [ 41 m
```

select a red background,

then:

```text
20 space characters
```

are printed.

A space has no visible glyph, but its **character cell still has a
background**, so we get a solid red rectangular strip.

Finally:

```text
ESC [ 0 m
```

resets the attributes.

So the host is effectively saying:

```text
background = red
print 20 spaces
background = normal
```

The display is still a grid of character cells.

---

# 45. A wider Armenian flag

Instead of manually writing many spaces, let the shell construct a row:

```sh
#!/bin/sh

# Width of the flag in terminal character cells.
width=40

# Make a string containing exactly $width spaces.
row=$(printf '%*s' "$width" '')

# Red stripe.
printf '\033[41m%s\033[0m\n' "$row"

# Blue stripe.
printf '\033[44m%s\033[0m\n' "$row"

# Yellow/orange approximation.
printf '\033[43m%s\033[0m\n' "$row"
```

Conceptually the result is:

```text
████████████████████████████████████████
████████████████████████████████████████
████████████████████████████████████████
```

with each line having a different background color.

Notice what changing:

```sh
width=40
```

actually changes.

It does not change a bitmap width.

It changes the number of **character cells** that the terminal paints.

---

# 46. Armenian flag with 256-color terminal extensions

Modern `xterm`-style terminals commonly support a 256-color palette.

The background-color syntax is:

```text
ESC [ 48 ; 5 ; n m
```

where:

```text
48      change background color
5       use indexed-color mode
n       palette index
m       finish SGR command
```

For example:

```sh
#!/bin/sh

width=40
row=$(printf '%*s' "$width" '')

# Approximate xterm 256-color palette choices:
#
# 160 = strong red
# 27  = blue
# 208 = orange

printf '\033[48;5;160m%s\033[0m\n' "$row"
printf '\033[48;5;27m%s\033[0m\n'  "$row"
printf '\033[48;5;208m%s\033[0m\n' "$row"
```

This gives a much more convincing Armenian flag than the basic 8-color
version.

But it is important to say this accurately:

> This is not a VT100 feature.

It is a later terminal extension in the same broad escape-sequence tradition.

---

# 47. Armenian flag using modern 24-bit RGB color

Many modern terminal emulators support direct RGB color.

The syntax for a background color is:

```text
ESC [ 48 ; 2 ; R ; G ; B m
```

For example:

```sh
#!/bin/sh

width=40
row=$(printf '%*s' "$width" '')

# Approximate Armenian flag colors:
#
# red    #D90012 = 217,   0,  18
# blue   #0033A0 =   0,  51, 160
# orange #F2A800 = 242, 168,   0

printf '\033[48;2;217;0;18m%s\033[0m\n' "$row"
printf '\033[48;2;0;51;160m%s\033[0m\n' "$row"
printf '\033[48;2;242;168;0m%s\033[0m\n' "$row"
```

The first color command:

```text
ESC [ 48 ; 2 ; 217 ; 0 ; 18 m
```

can be read as:

```text
48          set background
2           RGB mode
217         red component
0           green component
18          blue component
m           finish SGR
```

Again, the terminal is still coloring character cells.

This is not Sixel.

A useful progression is:

```text
original VT100
    monochrome character cells
    attributes such as blink, underline, reverse
            |
            v
later ANSI color terminals
    small indexed palettes
            |
            v
xterm-style terminals
    256 colors
            |
            v
modern terminals
    24-bit RGB
```

---

# 48. The same Armenian flag idea in Sixel

With Sixel, we would approach the flag differently.

Instead of saying:

```text
make the next 40 character-cell backgrounds red
```

we would create an actual raster image:

```text
top third       red pixels
middle third    blue pixels
bottom third    orange pixels
```

and encode those pixels as Sixel.

That difference is fundamental:

```text
ANSI/xterm color flag:
    terminal character cells are colored

Sixel flag:
    an actual raster image is transmitted
```

The ANSI version is extremely compact because the terminal already knows how
to paint character-cell backgrounds.

The Sixel version gives us pixel-level control, but usually requires more data.

---

# 49. Drawing a circle with Sixel

Sixel does not contain a command meaning:

```text
draw a circle
```

That is much closer to what a vector language such as ReGIS provides.

With Sixel, the **host rasterizes the circle first**.

For a circle centered at:

```text
(cx, cy)
```

with radius:

```text
r
```

we can test pixels using the circle equation:

```text
(x - cx)^2 + (y - cy)^2 = r^2
```

For a visible outline we normally accept pixels whose distance is merely
*close* to `r`.

Here is a complete Python example:

```python
#!/usr/bin/env python3

import sys
import math

W = 80
H = 80

cx = W / 2
cy = H / 2
r = 30

# Our host-side bitmap.
pixels = [[False] * W for _ in range(H)]

# ------------------------------------------------------------
# Rasterize the circle.
#
# Every element pixels[y][x] is one pixel.
# We calculate its distance from the center.
# If that distance is close to the radius, turn the pixel on.
# ------------------------------------------------------------

for y in range(H):
    for x in range(W):

        distance = math.sqrt(
            (x - cx) ** 2 +
            (y - cy) ** 2
        )

        if abs(distance - r) < 1.0:
            pixels[y][x] = True


# ------------------------------------------------------------
# Begin a Sixel DCS.
#
# ESC P q
# ------------------------------------------------------------

sys.stdout.write("\x1bPq")

# Raster attributes:
#
# "1;1;W;H
#
# 1;1 asks for a 1:1 pixel aspect ratio.
# W and H declare the nominal raster dimensions.

sys.stdout.write(f'"1;1;{W};{H}')


# ------------------------------------------------------------
# Sixel works in horizontal bands six pixels high.
# ------------------------------------------------------------

for y0 in range(0, H, 6):

    # For every X coordinate, build one vertical six-pixel
    # Sixel value.

    for x in range(W):

        value = 0

        for bit in range(6):

            y = y0 + bit

            if y < H and pixels[y][x]:

                # bit 0 = top pixel of this six-pixel column
                # bit 5 = bottom pixel
                value |= 1 << bit

        # Sixel printable character = value + 63.
        sys.stdout.write(chr(63 + value))

    # '-' means move to the next six-pixel band.
    if y0 + 6 < H:
        sys.stdout.write("-")


# ------------------------------------------------------------
# End the DCS with ST:
#
# ESC \
# ------------------------------------------------------------

sys.stdout.write("\x1b\\")
sys.stdout.flush()
```

Run it as:

```sh
python3 circle.py
```

The important architectural point is that there are really two stages:

```text
mathematical circle
        |
        v
host rasterizer
        |
        v
boolean bitmap
        |
        v
Sixel encoder
        |
        v
terminal
```

The terminal does **not know that the picture is a circle**.

It only knows which pixels it was asked to draw.

---

# 50. Understanding the central Sixel encoding loop

The most important part of the circle program is:

```python
for bit in range(6):
    y = y0 + bit

    if y < H and pixels[y][x]:
        value |= 1 << bit
```

Imagine one vertical group of pixels:

```text
pixel 0     ON
pixel 1     OFF
pixel 2     ON
pixel 3     OFF
pixel 4     ON
pixel 5     OFF
```

The corresponding bits are:

```text
bit 0 = 1
bit 1 = 0
bit 2 = 1
bit 3 = 0
bit 4 = 1
bit 5 = 0
```

So:

```text
value = 1 + 4 + 16
      = 21
```

Then:

```python
chr(63 + value)
```

gives:

```text
63 + 21 = 84
```

ASCII 84 is:

```text
T
```

So those six vertical pixels become just:

```text
T
```

in the Sixel stream.

This is the same principle we used earlier in the tiny checkerboard example.

---

# 51. Drawing a sine wave with Sixel

A sine wave is another excellent example because the mathematics is very
simple.

Instead of testing every pixel against a circle equation, calculate one Y
coordinate for every X coordinate:

```text
y = center + sin(angle) * amplitude
```

For example:

```python
import math

W = 160
H = 80

pixels = [[False] * W for _ in range(H)]

for x in range(W):

    # Four pi radians gives us two complete sine-wave periods.
    angle = x / W * 4 * math.pi

    y = int(
        H / 2
        + math.sin(angle) * H / 3
    )

    pixels[y][x] = True
```

Then feed `pixels` to exactly the same Sixel encoder used by the circle
example.

The pipeline is:

```text
sin(x)
   |
   v
calculate one y for every x
   |
   v
set those bitmap pixels
   |
   v
Sixel encoder
   |
   v
terminal
```

Conceptually the bitmap looks something like:

```text
          ******                         ******
       ***      ***                   ***
     **            **               **
   **                **           **
 **                    **       **
*                        *******


                         *******
 **                    **       **
   **                **           **
     **            **               **
       ***      ***                   ***
          ******                         ******
```

Again, Sixel itself has no knowledge of sine functions.

The host computes the curve and sends the resulting raster.

---

# 52. Circle: ReGIS versus Sixel

The circle example shows the difference between ReGIS and Sixel especially
well.

With ReGIS, the host can send a compact geometric command describing a circle.

Conceptually:

```text
position graphics cursor
draw circle with this radius
```

The terminal contains the graphics interpreter and rasterizer.

With Sixel:

```text
host computes the circle
host rasterizes the circle
host encodes the resulting pixels
terminal displays those pixels
```

So:

```text
ReGIS
    transmit geometry

Sixel
    transmit rasterized result
```

This division of labor explains why ReGIS can be dramatically smaller for
simple geometric pictures.

It also explains why Sixel is more general for arbitrary raster images.

A photograph is naturally a bitmap.

Describing a photograph as thousands of circles, curves, and polygons would
usually be much less convenient than simply transmitting its pixels.

---

# 53. A useful classroom comparison

The Armenian flag, circle, and blinking-text examples demonstrate three
different levels of terminal graphics.

## Blinking text

```text
ESC [ 5 m
```

changes a **text attribute**.

The terminal still displays ordinary characters.

## Armenian flag using ANSI colors

```text
ESC [ 48 ; ... m
```

changes the **background attribute of character cells**.

The terminal still displays a character grid.

## Circle using Sixel

The host sends an actual **raster image**.

The image is no longer constrained to character-cell geometry.

## Circle using ReGIS

The host sends **geometric drawing commands**.

The terminal performs the rasterization.

So we can summarize them as:

```text
VT100 text attributes
        |
        | character-cell state
        v
blink / underline / reverse


later ANSI/xterm color
        |
        | character-cell colors
        v
colored text / colored blocks


ReGIS
        |
        | geometry
        v
lines / circles / curves


Sixel
        |
        | pixels
        v
arbitrary raster images
```

This is one of the most useful ways to understand the progression from a
classic text terminal to a graphics-capable terminal.


# 54. References for further study

The original DEC documentation is especially valuable because it describes what the actual hardware terminals implemented.

Useful manuals include:

- **Digital VT100 User Guide — Programmer Information**
- **VT125 ReGIS Primer**
- **VT240 Series Programmer Reference / Programmer Pocket Guide**
- **VT330/VT340 Programmer Reference Manual, Volume 2: Graphics Programming**
  - ReGIS programming
  - Sixel graphics
- **xterm Control Sequences** for the behavior of a modern terminal emulator implementing many DEC protocols

When comparing documentation, always notice which terminal model is being described. "VT-compatible" terminal behavior accumulated over many generations and should not all be attributed to the original VT100.
