+++
title = 'ELF Internals - Part III: The Section Headers'
date = 2024-12-28T17:05:28+01:00
draft = false
+++

After the ELF and Program Headers we have the section headers. This knowledge 
is, again, essential for reverse engineering, as well as malware development. 
So without wasting any time, let's jump straight into it.

## What Is A Section?

Sections are, as some guy from Stack Overflow put it, "the smallest continuous 
regions in the file"- basically sections are a way to organize the binary 
logically into, as the name says, sections. A few common ones are:

- `.text` - stores executable code
- `.bss` - stores uninitialized data, also stand for "block starting symbol"
- `.data` - stores, as the name says, data such as variables
- `.rodata` - stores read only data - so.. constants

So basically with sections we divide the binary into logical parts *on disk*.
The loader and linker use those then for various purposes. For example, the 
linker uses them to combine multiple object files into one final binary, *HOW?* 
By merging the sections of all the object files into one. The linker also uses
sections to resolve symbols and resolve relocations. 

To see the sections we may execute: 

```bash
[deluks@baltazar ~]$ readelf -S <FILE>
There are 30 section headers, starting at offset 0x4630:

Section Headers:
 [Nr] Name              Type             Address           Offset
      Size              EntSize          Flags  Link  Info  Align
 [0]                   NULL             0000000000000000  00000000
      0000000000000000  0000000000000000           0     0     0
 [1] .interp           PROGBITS         0000000000000318  00000318
      000000000000001c  0000000000000000   A       0     0     1
 [2] .note.gnu.pr[...] NOTE             0000000000000338  00000338
      0000000000000040  0000000000000000   A       0     0     8
 [3] .note.gnu.bu[...] NOTE             0000000000000378  00000378
      0000000000000024  0000000000000000   A       0     0     4
<----------------------------- SNIP ---------------------------->
```

NOTE: Command output slightly modified to not have the horizontal scrollbar.

Now there is a hell of a lot going on here but it will all make sense (I hope) 
shortly. For now lets just take note of the names `.interp`, 
`.note.gnu.pr[...]` and `.note.gnu.bu[...]` those, my friend,  are sections.
By now you may be asking yourself, "how does `readelf` then know what a section is
and where its located???", and the simple answer to that is "Section Headers".

## What Is A Section Header?

Each section has its own section header, and a section header is a data 
structure in an ELF binary that contains information about a section in 
the binary. We will take a look at the exact structure in a minute but 
essentially it holds info such as permissions, size, offsets, etc.
But let's first take a look how to find them.

### How Do We Find The Section Headers?

We may find the section headers by reading the `e_shoff` member of the ELF 
header. Since there are of course more than one sections in a binary, we 
also have the members:

- `e_shentsize` holding the size of the section header entry.
- `e_shnum` holding the number of the sections in the binary. 
- `e_shstrndx` holding the index of the section header table that contains the sections names.

```c
typedef struct {
    unsigned char e_ident[16];
    uint16_t      e_type;
    uint16_t      e_machine;
    uint32_t      e_version;
    ElfN_Addr     e_entry;
    ElfN_Off      e_phoff;
    ElfN_Off      e_shoff;     // <-- offset to first section_hdr entry
    uint32_t      e_flags;
    uint16_t      e_ehsize;
    uint16_t      e_phentsize;
    uint16_t      e_phnum;
    uint16_t      e_shentsize; // <-- size of section_hdr entry
    uint16_t      e_shnum;     // <-- no. of sections
    uint16_t      e_shstrndx;  // <-- names
} ElfN_Ehdr;
```

Now, basically all we have to do is get the offset and cast it to this very 
cool structure called `ElfN_Shdr`, where `N` is either "32" or "64" depending
on if we are on a 32-bit or a 64-bit system respectively. (For this blog post 
we are taking a look at the 64-bit version.)

### How Is The Structure Defined?

Taking a look at the definition of the structure, we see the following:

```c
typedef struct {
    uint32_t   sh_name;
    uint32_t   sh_type;
    uint64_t   sh_flags;
    Elf64_Addr sh_addr;
    Elf64_Off  sh_offset;
    uint64_t   sh_size;
    uint32_t   sh_link;
    uint32_t   sh_info;
    uint64_t   sh_addralign;
    uint64_t   sh_entsize;
} Elf64_Shdr;
```

The first member holds the offset to the section name in the `.shstrtab` section. 
Following it we have a huge member called `sh_type`, this identifies the type of
this header, and let me tell you, there are a lot of types, we will take a look 
at only 11 though to not bore you to death. The 11 Types are:

| Value | Name         | Description     |
| ----- | ------------ | --------------- |
| 0x00  | SHT_NULL     | Unused |
| 0x01  | SHT_PROGBITS | Program data |
| 0x02  | SHT_SYMTAB   | Symbol table |
| 0x03  | SHT_STRTAB   | String table |
| 0x04  | SHT_RELA     | Relocation entries with addends |
| 0x05  | SHT_HASH     | Symbol hash table |
| 0x06  | SHT_DYNAMIC  | Dynamic linking info |
| 0x07  | SHT_NOTE     | Notes |
| 0x08  | SHT_NOBITS   | BSS |
| 0x09  | SHT_REL      | Relocation entries |
| 0x0B  | SHT_DYNSYM   | Dynamic linker symbol table |

Next up, we have the member `sh_flags` and it holds the attributes of our 
section. Again, a lot of members, but the most important are listed in the 
table below:

| Value | Name                 | Description     |
| ----- | -------------------- | --------------- |
| 0x001 | SHF_WRITE            | Writable |
| 0x002 | SHF_ALLOC            | Uses some memory during execution |
| 0x004 | SHF_EXECINSTR        | Executable |
| 0x010 | SHF_MERGE            | Maybe Merged |
| 0x020 | SHF_STRINGS          | Contains Strings |
| 0x040 | SHF_INFO_LINK        | SHT index is in `sh_info` |
| 0x080 | SHF_LINK_ORDER       | Preserve order after combining sections |
| 0x100 | SHF_OS_NONCONFORMING | OS Specific processing required |
| 0x200 | SHF_GROUP            | Section is a group member |
| 0x400 | SHF_TLS              | Section holds thread local storage |

And now that we got these horrors out of the way, we can speed trough the rest 
of the members. `sh_addr`, `sh_offset` and `sh_size` contain the virtual address 
of the section in memory, the offset to the section on disk and the size of the 
section in bytes respectfully. The member `sh_link` holds the section index of 
the specified section and the `sh_info` member holds additional infos about the 
section, both depend on the exact type of the section. Finally we have 
`sh_addralign` and `sh_entsize` that contain the required alignment for the 
section and the entry size of an section assuming it contains fixed-size entries.

### What Is The Difference Between A Segment And A Section?

Simply put, sections are used for organization and contain specific data types 
used by the linker. On the other hand segments define how the program is loaded 
into memory and  may contain multiple sections. For example the an segment may
contain both the .text an .data section.

Now coming back to this, the mess makes a bunch more sense, sure the formatting
of the output is a little weird but we see all the members of the `ElfN_Shdr`
structure for each and every section in our file (and at that in just 2 lines!!).

```bash
There are 30 section headers, starting at offset 0x4630:

Section Headers:
 [Nr] Name              Type             Address           Offset
      Size              EntSize          Flags  Link  Info  Align
 [0]                   NULL             0000000000000000  00000000
      0000000000000000  0000000000000000           0     0     0
 [1] .interp           PROGBITS         0000000000000318  00000318
      000000000000001c  0000000000000000   A       0     0     1
 [2] .note.gnu.pr[...] NOTE             0000000000000338  00000338
      0000000000000040  0000000000000000   A       0     0     8
 [3] .note.gnu.bu[...] NOTE             0000000000000378  00000378
      0000000000000024  0000000000000000   A       0     0     4

<----------------------------- SNIP ---------------------------->
```

## Conclusion

That's all for today folks, I hope you learned something new about ELFs and also 
hope I did not bore you too much! The next part covers the ELF symbols so stay 
tuned.

### Assignment

Like always, pick any language you want and write a simple program/script that 
will parse the section headers for you. I will be using C and you will see my 
solution in the repo I linked on the final part of the series.

## References

- https://stackoverflow.com/questions/16812574/elf-files-what-is-a-section-and-why-do-we-need-it
- https://en.wikipedia.org/wiki/Executable_and_Linkable_Format#Section_header
- https://www.man7.org/linux/man-pages/man5/elf.5.html
