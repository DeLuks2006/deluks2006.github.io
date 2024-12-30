+++
title = 'ELF Internals - Part III: The Section Headers'
date = 2024-12-28T17:05:28+01:00
draft = false
+++

After the ELF and Program Headers, we have the section headers. This knowledge 
is, again, essential for reverse engineering, as well as malware development. 
So without wasting any time, let's jump straight into it.

## To Section Or To Segment?

Segments define how the program is loaded into memory and may contain multiple 
sections in them. Sections on the other hand are logically ordered parts of our 
binary, one section may contain code (`.text`/`.code`), while others contain 
data such as our programs variables (`.data`/`.rodata`), strings (`.strtab`) or 
even relocations (`rela.dyn`/`rela.plt`). This organisation makes it easier for 
tools (such as Bin2Bin Obfuscator) and developers (Nerds) to modify the code.

Another thing sections contain is debug information (`.debug_<something>`) which
as the name says is used by debugger as well as profiling tools, we won't cover 
the format of the debug information sections since it is out of the scope of this 
post but let's just say, without these you would be having a really bad time. 

Finally because of sections, the OS can manage memory more efficiently. For 
example the executable code can be marked as `R*X`, while sections that don't 
need to be executable we can just mark as read-only (`R**`).

## Linked And Loaded 

We can find sections in executables, shared objects and raw object files. For 
each file type the sections are treated a little differently by the linker and 
loader. 

But first lets clear up how sections are even used by the linker. When statically 
linking a binary, the structure allows multiple object files to be fused together 
into a single executable by the linker. When the binary is then loaded into 
memory,the loader uses this information to place each section into the 
appropriate memory region. In the case of dynamic linking, information such as 
references to the libraries we use are stored, so that the loader can resolve 
them during the runtime. This not only allows for more efficient memory usage 
but also reduces redundancy.

### Object Files (`.o`)

As already said, the linker combines multiple object files, resolves symbols, and 
processes relocations to create our single executable, it also merges sections 
from different object files and generates a symbol table for the final output.

### Executables (`.out`)

The linker creates the executable from the object files by ensuring all symbols 
are resolved and addresses are fixed. The sections are also organized for 
efficient execution and of course, creates the necessary headers for our loader. 

### Shared Objects (`.so`)

Shared objects are processed similarly to executables, but they allow for 
unresolved symbols, making it possible for those to be linked with other 
executables or shared objects at runtime. It also generates a dynamic symbol 
table for runtime linking (Also the case for executables that are position 
independent). The loader dynamically loads shared objects only when an executable 
requests them; the relocations and symbol resolution is then performed at runtime.

So in summary the linker uses sections such as `.symtab`, `.dynsym` for symbols, 
`.text`, `.rodata`, `data`, `.strtab` for code and data (variables), and finally 
`.got`, `.dynamic`, `.rela.*` for relocations and other stuffs.

To display all the sections in a select binary may execute: 

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

Now there is a hell of a lot going on here but it will all make sense (I hope) 
shortly. For now lets just take note of the names `.interp`, 
`.note.gnu.pr[...]` and `.note.gnu.bu[...]` those, my friend, are sections.
By now you may be asking yourself, "how does `readelf` then know what a section is
and where its located???", and the simple answer to that is "Section Headers".

## Section Header?

Each section has its own section header, and a section header is a data 
structure in an ELF binary that contains information about a section in 
the binary. We will take a look at the exact structure in a minute but 
essentially it holds info such as permissions, size, offsets, etc.
But let's first take a look how to find them.

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

### Finding The Criminal By Looking At Clues

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
we are talking a look at the 64-bit version.)

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
tuned. Huge thanks to [bextr](https://x.com/_vrzh) for the feedback while writing 
this post.

### Assignment

Like always, pick any language you want and write a simple program/script that 
will parse the section headers for you. I will be using C and you will see my 
solution in the repo I linked on the final part of the series.

## References

- https://stackoverflow.com/questions/16812574/elf-files-what-is-a-section-and-why-do-we-need-it
- https://en.wikipedia.org/wiki/Executable_and_Linkable_Format#Section_header
- https://www.man7.org/linux/man-pages/man5/elf.5.html
