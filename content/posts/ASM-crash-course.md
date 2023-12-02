+++
title = 'ASM Crash Course'
date = 2023-12-02T22:25:05+01:00
draft = false
+++

#### First - What is even assembly

ASM, often referred to as "assembly", or "that one really hard and confusing language", is a low level programming language that is closely tied to the computers architecture ( what is that? 🤔).

Assembly is mostly used in OS-development, Firmware (like drivers), Embedded systems and Reverse Engineering.

---
#### So you don't know what a Computer architecture is?

Computer architecture refers to the design and organization of the various components that make up a computer system, including the CPU, memory, I/O devices, and how they interact to execute instructions and process data. It represents both the hardware and the software that allow a computer to function.

Here is an example of the Von-Neumann Architecture which is basically used in every modern Computer:

![von neumann](/media/neumann.svg)

Now back on topic...

---

The language is a human readable representation of machine code which is unique for every processor (machine code is typically just the binary data that communicates/gives instructions to the CPU), ASM consists of instructions that are directly executed by the computers brains (CPU).

With assembly you work with opcode that correspond to specific machine instructions, made to be easily read by humans so they do not have to read raw binary data. ASM allows programmers to have more control over hardware resources and since it communicates with the CPU using registers (which are like small pieces of memory in the CPU) it is also really fast.

For example, a simple assembly instruction might be:

```nasm
    mov    eax, 4
```

"What does this code do" - now you may be thinking to yourself; let me explain...

It moves the number 4 into a register calles EAX. EAX is a general purpose register and may be used for various of things. The syntax of most assembly programs is as follows:

```txt
    [instruction]    [destination], [source]
```

Now general purpose registers are one of 4 types of registers (or 3, depends how you count it):

- Instruction Pointer
- General Purpose Registers
- Status Flag Registers
- Segment Registers

Now you are probably thinking: "WHAT ARE THOSEE?!?"

Well let me tell you:

- The Instruction Pointer literally tells the CPU which line to execute next. 
- The General Purpose Registers are the typical registers that you will use. They can be used for various things but there is also a standard if you wish to use that.
- The Status Flag registers give some indication of the execution status of the program. These are commonly used while checking something, for example in a jump conditional (its something like a if statement)
- Finally the Segment Registers convert the flat memory space into diffrent segments for easier addressing.

Here is a table of all the registers:

| General Registers | Segment Registers| Status Registers | Instruction Pointer |
| --- | --- | --- | --- |
| RAX, EAX, AX, AH, AL | CS | EFLAGS | EIP, RIP, IP |
|RBX, EBX, BX, BH, BL | SS||
|RCX, ECX, CX, CH, CL|DS|||
|RDX, EDX, DX, DH, DL|ES|||
|RBP, EBP, BP|FS|||
|RSP, ESP, SP|GS|||
|RSI, ESI, SI||||
|RDI, EDI, DI||||
|R8-R15|||

Now you may be wondering, whats up with these names?

Well simply the first CPUs had 8 bit registers that could be used together as a 16bit register for example AH (A Higher) and AL (A Lower) would then be AX. Then After some time the 16bit registers got extended to 32bit and were then given the "E" (Extended) prefix, and finally after came the 64bit registers which also extended the 32-bit registers, they then got the prefix "R" (Register).

It is also important to note that if you edit for example the RAX register it also effects the other smaller registers, for a more visual example see image below:

![Registers](/media/registers.png)

Now, how do I make all of these numbers and letters work?

Simple, you use syscalls. What is that? - It is just a way to communicate to your kernel.
![syscall](/media/syscall.png)
Lets take a look at a Hello world program to understand syscalls better.

```nasm
section .data
msg     db      "Hello, World",0Ah    ; declares the message in msg

section .text
global  _start        ; this is like our int main() in C

_start:
	mov    edx, 13    ; move the length of the string + the zero terminator 
	mov    ecx, msg   ; move the message in ecx
	mov    ebx, 1     ; call to stdout to write to a file
	mov    eax, 4     ; sys_write syscall

    mov    ebx, 0     ; return 0
    mov    eax, 1     ; sys_exit syscall
    int    80h
```

Now, here we use 2 syscalls to first print our message (sys\_write) and then exit the program (sys\_exit) these numbers mean that it is a syscall. Caution these system calls are diffrent for each type of assembler system. For a table of all possible system calls for the x86-32 (32-bit) version use this link https://x86.syscall.sh/.

Now thats it folks, I hope you now have a general Idea how assembly works, what it is, and what it is used for.

