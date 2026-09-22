# One Byte at a Time: How x86 Grew From 16 to 64 Bits Without Breaking Anything

*A student-friendly deep dive into x86 instruction encoding, and how the same 256 one-byte opcodes survived two major transitions: 16→32 bit (80386) and 32→64 bit (AMD64). Ready to convert to PDF.*

---

## 1. The Puzzle

On x86-64, some instructions are only one byte long:

```asm
58    pop %rax
50    push %rax
C3    ret
90    nop
```

Wait a minute. There are only **256 possible one-byte values**. The 8086 was designed in the late 1970s — didn't the 8-bit opcode space fill up decades ago? How can the *same* byte `58` mean `pop %ax` on a 1978 machine and `pop %rax` on a modern one? And how did the 386 (32-bit) and AMD64 (64-bit) transitions reuse the same bytes three times without breaking compatibility?

This document answers that question. The short version:

1. **The one-byte space is not the whole ISA.** Bytes are also *prefixes* and *escape codes* that open up enormous secondary opcode spaces.
2. **Opcode bytes have no fixed meaning by themselves.** What they mean depends on the *mode* the CPU is in.
3. **Each transition redefined the default, and added a prefix to reach the old size.** That trick was used twice: 16→32 and 32→64.

---

## 2. The One-Byte Opcode Map Is a Tree, Not a Table

The naive mental model of an ISA is: 256 opcodes, one per byte. The real model is a *variable-length encoding tree*:

- **Most bytes** are real one-byte opcodes, usually followed by a **ModRM byte** that encodes register and memory operands (see §3).
- **0x0F is an escape byte.** `0F xx` opens the *two-byte opcode space* (another 256 opcodes: CPUID is `0F A2`, the SSE instructions, hint NOPs `0F 1D–0F 1F`, etc.).
- **0x0F 0x38 and 0x0F 0x3A** open the *three-byte opcode spaces* — SSSE3, AES-NI, PCLMUL, lots of AVX. That is another 512 opcodes.
- **0x62** (in 64-bit mode) is the **EVEX escape** used by AVX-512, carrying huge operand fields.
- **Prefix bytes** stack *before* the opcode and modify it (operand size, repetition, locking, segment, register extension...).

So the usable opcode space is not 256 — it is hundreds of thousands of instruction forms, reached by walking a tree: `[prefixes] [escape] opcode [ModRM] [SIB] [displacement] [immediate]`.

**Why did the designers of the 8086 make `push`/`pop` one byte?** Because code size and speed mattered enormously: memory was tiny and expensive, and there was no instruction cache on the 8086 at all (it had a small prefetch queue). The most frequent operations — push, pop, mov, arithmetic on the "classic" registers AX–DX — got the shortest encodings. This allocation was frozen in 1978, and we still live with it: that is why `push %rdx` is one byte but `push %r8` needs two.

---

## 3. ModRM: One Opcode, Hundreds of Instructions

A single opcode byte does not mean one instruction. Most opcodes take a **ModRM byte** right after them, which packs three fields:

```text
 7  6  5  4  3  2  1  0
[mod][  reg  ][  r/m   ]
```

- `mod` (2 bits): operand in register, or in memory with various addressing modes
- `reg` (3 bits): a register operand (or an opcode extension for some instructions)
- `r/m` (3 bits): the other register, or a memory addressing mode (with a SIB byte + displacement following if needed)

Example: opcode `01` is "ADD r/m32, r32". The byte `01 C0` decodes ModRM=`C0` (mod=11, reg=000, r/m=000) → `add %eax, %eax`. With a different ModRM the same one-byte opcode becomes `add %eax, (%rbx)` and so on. So one opcode byte + one ModRM byte already covers a couple hundred distinct instruction *forms*.

This is why the ISA never really fit in 256 bytes — the one-byte map was always just the entry points.

---

## 4. The Key Idea: Bytes Mean Nothing Without a Mode

Here is the single most important concept of this document:

> **The same byte sequence decodes differently depending on the mode the CPU is currently executing in.**

The byte `58`:

| CPU mode | `58` decodes as |
|---|---|
| 16-bit mode (real mode / 16-bit protected) | `pop %ax` |
| 32-bit mode (386 protected mode, D=1) | `pop %eax` |
| 64-bit mode (long mode) | `pop %rax` |

Nobody "reused" or "ran out" of anything. It is *one* opcode — `POP r` — whose **default operand size comes from the current mode, not from the byte**.

How does the CPU know the mode? Two mechanisms:

1. **The D (Default operand size) bit in the code segment descriptor.** The OS sets this per code segment: D=0 means 16-bit default, D=1 means 32-bit default. This is how the 386 could run both old 16-bit code and new 32-bit code.
2. **Long mode (x86-64)** replaces the descriptor logic: in 64-bit mode the D bit is ignored, the default operand size is 32 bits for almost everything, and new prefixes (REX, §7) widen things to 64.

Now let's see how the two transitions each played this game.

---

## 5. Transition 1: 8086 (16-bit) → 80386 (32-bit), 1985

The 386 doubled the register width: AX→EAX, etc. The question was what to do with the encoding. Intel chose the cheapest possible trick:

**They changed the default, and added one prefix to reach back to the old size.**

- In a 32-bit code segment (D=1), every existing opcode silently became 32-bit. `58` is now `pop %eax`. `89 C8` is now `mov %ecx, %eax`. Same bytes as 1978, doubled register width, zero new opcodes spent.
- The **operand-size prefix `0x66`** means "use the *opposite* of the current default." In a 32-bit segment, `66 89 C8` is `mov %cx, %eax` — 16-bit. In a 16-bit segment, `66 89 C8` is 32-bit. One prefix, both directions.
- Same story for addresses: the **address-size prefix `0x67`** switches 16↔32-bit addressing (needed because 16-bit addressing modes had a much more limited form — no SIB byte, no full 32-bit displacements).

Because the D bit is per code segment, an OS can run 16-bit and 32-bit code side by side, switching by far-jumping between segments. Old 16-bit programs ran on a 386 unmodified — that was the entire commercial point.

**What was actually added in 386:** new instructions got *two-byte* opcodes behind the `0F` escape (e.g. `0F 80–0F 8F` are the 32-bit conditional jumps `JO/JNO/...` with 32-bit displacements; `0F B6/B7` are MOVZX/MOVSX; `0F C8–0F CF` are BSWAP). The escape mechanism was already there — on the 8086, `0F` was a "POP CS" that was never used — and now it became the growth path. The one-byte space was left untouched.

---

## 6. Interlude: Why Not Just Make a Clean 64-bit ISA?

By the early 2000s 32-bit x86 was the dominant installed base on Earth. Intel tried the clean-slate route (Itanium, IA-64) and the market said no. AMD's winning move (2003) was to extend x86 to 64 bits while keeping every byte of existing 32/16-bit code working. The constraint: **you may not invent new meanings for existing encodings in existing modes.** The solution, once again, was the same trick — but with a twist, because "shrink back to the old size" was not good enough this time.

---

## 7. Transition 2: 32-bit → AMD64 (x86-64), 2003

In 64-bit mode:

- The default operand size stays **32 bits** (not 64!). Almost all legacy code keeps executing with 32-bit semantics.
- The **REX prefix** (bytes `0x40`–`0x4F`) is introduced. Its bit `W` (REX.W, in `0x48`–`0x4F`) says "make this operation 64-bit." So `48 89 C8` is `mov %rcx, %rax` while plain `89 C8` remains `mov %ecx, %eax`.
- The old `66` prefix still means "16-bit." `66 89 C8` in 64-bit mode is `mov %cx, %ax`.

So now a single instruction root like `89` covers all three widths:

```asm
89 C8      mov %ecx, %eax     ; 32-bit (default)
66 89 C8   mov %cx,   %ax     ; 16-bit (66 = shrink)
48 89 C8   mov %rcx,  %rax    ; 64-bit (REX.W = widen)
```

### 7.1 Where did the REX bytes come from?

`0x40`–`0x4F` were the one-byte **INC r** and **DEC r** opcodes since 1978. In 64-bit mode Intel sacrificed them (you use the ModRM-based `FE /0` and `FF /1` forms instead) and recycled the whole 16-byte range as the REX prefix. This is the one place where 64-bit mode did break *encoding* compatibility — but only in the new mode; 16/32-bit code still sees them as INC/DEC.

### 7.2 The second job of REX: more registers

A 3-bit register field covers 8 registers. AMD64 added r8–r15, doubling the register count to 16, which needed one extra bit *everywhere* — reg, r/m, SIB base, SIB index. The REX prefix supplies those bits: `R` extends reg, `B` extends r/m/base, `X` extends the SIB index. This is why `pop %r8` costs two bytes (`41 58` — REX.B + the same `58` root), and it is the honest answer to "why don't the new registers get one-byte encodings": the one-byte map was fully allocated by 1980, and the only spare 16 bytes went to prefixes.

### 7.3 What 64-bit mode changed about defaults

- **Default operand size: 32**, except that a few operations are implicitly 64-bit (near jumps and all addressing are naturally 64-bit; pushes/pops operate on 64-bit stack slots).
- **REX.W (`48`–`4F`)** widens arithmetic/logic ops to 64 bits.
- **Default address size: 64.** The `67` prefix shrinks it to 32 (rarely used).
- Immediates in 64-bit arithmetic are sign-extended 32-bit values — a compromise to avoid bloating every `mov r64, imm64`.

---

## 8. The Big Picture: One Table to Remember

| Year | CPU / mode | Default operand size | Prefix to shrink | Prefix to widen | New-register bits |
|---|---|---|---|---|---|
| 1978 | 8086 (16-bit) | 16 | — | (`66` in a 32-bit segment, later) | — |
| 1985 | 386, 32-bit segment | 32 | `66` | — | — |
| 2003 | AMD64, 64-bit mode | 32 | `66` | `48`+ (REX.W) | `40`–`4F` (REX.R/X/B) |

The elegant invariant across both transitions:

> **The prefixes never mean "16 bits" or "32 bits" or "64 bits" absolutely. They mean "deviate from the current default."** That is why every prefix remains meaningful in every era, and no encoding ever had to be redefined.

---

## 9. Worked Examples

### 9.1 One root, three widths of POP

```asm
58        pop %rax    ; the classic one-byte root, now 64-bit in long mode
5C        pop %rsp
41 58     pop %r8    ; REX.B (41) + root 58: same opcode, new register bit
```

### 9.2 The `89` family (MOV r/m, r)

```asm
89 C8     mov %ecx, %eax
66 89 C8  mov %cx,   %ax
48 89 C8  mov %rcx,  %rax
```

### 9.3 Escapes and prefixes in a modern instruction

```asm
F3 0F 1E FA              endbr64            ; F3 prefix + 0F escape + opcode + ModRM
66 0F 38 10 C1           pblendvb %xmm0,%xmm0 ; 66 + 0F 38 three-byte escape
62 F1 FD 08 28 C1        vmovapd %zmm0,%zmm1  ; EVEX escape (62) — AVX-512
```

Each is one "instruction" from the programmer's view; the decoder walks a prefix-and-escape tree to find it.

### 9.4 A trap for the unwary: disassembling non-code

If you run `objdump -D` (all sections) instead of `objdump -d` (code only), you will see garbage like this from a data/note section:

```asm
42d:  00 00          add %al,(%rax)
434:  4f 01 00       rex.WRXB add %r8,(%r8)
43c:  52             push %rdx
444:  54             push %rsp
```

Those bytes are not instructions at all — they are ELF note lengths and strings (e.g. `52 01 00` is the little-endian value 0x152). The disassembler happily decodes any byte stream *somewhere in the tree*, because nearly every byte is either an opcode, a prefix, or an escape. **Lesson:** bytes mean nothing without a mode *and* without knowing they are actually code.

---

## 10. Why This Design Is Both Genius and Painful

**Genius:** a program compiled for the 8086 still contains byte sequences a modern CPU executes. Every transition was additive: a new default plus one new prefix. The installed base never had to be recompiled.

**Painful:** variable-length decoding through a prefix tree is serial work. A modern x86 core burns real silicon and real cycles in its decoders, which is why high-end chips decode once into cached μops. Fixed-width ISAs (RISC-V, classic ARM) mock this from the other side of the fence. And the register-encoding asymmetry — `push %rdx` = 1 byte, `push %r8` = 2 bytes — is a 1978 allocation decision that compilers still work around with register-allocation heuristics nearly fifty years later.

**Summary for students:** the one-byte space *was* exhausted, around 1980. x86 survived by (1) turning opcode bytes into prefix and escape bytes, (2) letting the CPU mode — not the byte — decide the operand width, and (3) twice adding a single prefix meaning "different size than default." 256 bytes was never the limit; it was just the front door.