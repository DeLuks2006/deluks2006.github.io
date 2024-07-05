+++
title = 'ELF Internals: Part I'
date = 2024-07-03T19:33:48+02:00
draft = false
+++
So... You wanna learn something about those weird Linux executables known as ELFs? Well you are in luck, me too!
I've taken it upon me to seek around the dark dusty corners of the world wide webs to learn about those ELFs so 
you do not have to look as much and *maybe* help you out! 

But beware young traveler I am learning with you, so there may be some mistakes.

# Part I: What in the Great Heavens is an ELF 

First off... No its not a elve! 

ELF stands for *Executable and Linkable Format*, and simply put, its just a File Format commonly used on the \*UNIX
operating systems for... well plain ol' executables but also for other stuff like kernel modules (.ko), shared libaries (.so)
and even core dumps (.core)!

## So why should *anyone* care?

Well, there are several reasons why one would want to learn more about the ELFs... Here are a few (which I can think of):

### Malware

Whether you are analysing or developing mischevious computer software, you the analyist or developer should know at least the 
basics of the ELF! Why??? Because I said so. Aaand also because for example as the developer you could make the analyists life 
a nightmare by modifying some silly bytes to confuse the disassemblers/decompilers, or as the analyist you may want to know the 

evil tricks of the developer to find out his actual intents while reverse engineering. Or if you are like me and think viruses and 
file infectors are cool you probably need to know about ELFs to properly write a infector/virus. 

### Binary Golfing

Ahh so you wanna be part of the cool kids club, ey? Well knowing the ELF structure helps **a lot** when trying to make your silly 
little binary as small and cute as possible. The standard ELF loader on Linux does not care all that much about your binaries 
header integrity as we will see later!

### Compatibilty

Maybe you are the big brained fella that wants to create his own operating system and want to use the good ol' ELF as the standard for 
your executables or you just want to *somehow* port the ELF to some other weird operating system, like... I don't know... Windows??? 

**(dont get any stupid ideas...)**

# Part II: Let the horrors begin!

The ELF consists of 6 main parts:

- The ELF header 
- Program headers (table) 
- Section headers (table)
- Sections
- Symbols 
- Relocation

Now... Before diving in, lets first create a small binary to have a nice little example:

```c 
#include <stdio.h>

int main(void) {
    printf("Hello World!\n");
    return 0;
}
```

Now... hexdump that sucka (or whatever you use) and let's begin!

## The ELF Header 

The good old ELF header consists of 14 little parts, and those tiny parts contain some very important data, let us take a deeper look.

The ELF header is defined like so: \[1]

```c 
typedef struct {
    unsigned char e_ident[16];
    uint16_t      e_type;
    uint16_t      e_machine;
    uint32_t      e_version;
    ElfN_Addr     e_entry;
    ElfN_Off      e_phoff;
    ElfN_Off      e_shoff;
    uint32_t      e_flags;
    uint16_t      e_ehsize;
    uint16_t      e_phentsize;
    uint16_t      e_phnum;
    uint16_t      e_shentsize;
    uint16_t      e_shnum;
    uint16_t      e_shstrndx;
} ElfN_Ehdr;
```

now lets see what each member does:

starting off with `e_ident`, it's a kind of a weird combo of multiple
significant bytes so lets try to not get confused here...

we will use the hexdump output as reference:
`7f 45 4c 46 02 01 01 00  00 00 00 00 00 00 00 00` <- example
`7f 45 4c 46 __ __ __ __  __ __ __ __ __ __ __ __` <- "__" means the loader don't care

(for more info about golfing and learning about what the loader ignores id check out blogs \[1]\[2])

lets start with the magic bytes `7f 45 4c 46` or just ` ELF`, this one just 
tells us that its a ELF binary, without it, the loader and other stuff will 
refuse the binary. Next up, we have the byte after our magic, it tells us in 
which format the binary is, so for 32bit executables we have the value `01` and 
for 64bit executables we have the value `02`. After that comes the byte that signifies
the endianess of the binary, `01` being little endian and `02` being big endian. Finally
we have the version of the ELF which is (almost) always `01`.
Next we got 2 bytes that are not usually used *automatically*, the first one 
signifies for which OS the binary was compiled for, for example Linux would be `03` and OpenBSD would be `0c`,
and the latter signifies the version of the OS (also not used anymore after Linux kernel version 2.6)
Aaaand finally, we have some padding bytes, used for... well padding.

`02 00 3e 00 01 00 00 00  00 10 40 00 00 00 00 00`
`02 00 3e 00 __ __ __ __  00 10 40 00 00 00 00 00`

next up we have the `e_type` member signifying the file type of our binary, `02` meaning a executables, `03` meaning a shared object
and etc. Annd after that we got `e_machine` specifying the instruction set, this one can be left out. 
Then we have the `e_version`, that is 4 bytes long, specifying the version of the ELF (again??). And Finally
we have the `e_entry` that just contains the entry point of our file, in this case it is `0x0000000000401000` or just `0x401000`

`40 00 00 00 00 00 00 00  10 21 00 00 00 00 00 00`
`40 00 00 00 00 00 00 00  __ __ __ __ __ __ __ __`

on to the 3rd line of the dump, we got the `e_phoff` or Program Header Offset, is a 8 byte chonk 
and a pointer to the program header table. And since it usually just follows after the ELF header 
its most of the time at the offset `0x40` on 64bit. Next we have another chonk, the `e_shoff`, 
this is just a pointer to the Section Header table.

`00 00 00 00 40 00 38 00  03 00 40 00 06 00 05 00`
`__ __ __ __ 40 00 38 00  03 00 __ __ __ __ __ __`

Now here the first 4 bytes are architecture specific and belong to the member `e_flags`. Next up we have the `e_ehsize`
which is 2 bytes that just say how big the ELF header is. 

After that we got the `e_phentsize` member, this one is also 2 bytes and contains the size of "each" program header entry, 
this is most likely gonna be `0x38` on 64bit. Right after that we have the number of entries in the program header table (also 2 bytes). 

And for the section header table we have the members `e_shentsize`, `e_shnum` and `e_shstrndx` representing the section header 
entry size, the number of section header entries and the index of the of the section header table entry that contains the section 
names respectfully.

# Conclusion

So this is it for the first part of the small series I plan to do on the ELF file format. I hope I did not bore you 
too much! In the next parts we will cover the program headers and the section headers so be sure to check this site 
again after a few days.. or weeks... or months. While you wait, I have left you a little assignment you can do to 
directly use the knowledge you learned today so it helps ya memorise it! ))

> P.S. I'll try my best to make the next post not as boring as this one ))

> P.P.S. If you find anything in this article that is not correct be sure to DM me on discord at "deluks."

# ASSIGNMENT:

> Pick any language you want and write a simple ELF header parser, keep in mind we will be expanding this as we go.
> I will be using C and you will see my solution in the next post!

# References

\[0] https://en.wikipedia.org/wiki/Executable_and_Linkable_Format

\[1] https://tmpout.sh/1/1.html *

\[2] https://n0.lol/ebm/ *

\[3] https://www.man7.org/linux/man-pages/man5/elf.5.html

\* be sure to check these awesome posts out, the authors are extremely talented and explain their topics very well!

