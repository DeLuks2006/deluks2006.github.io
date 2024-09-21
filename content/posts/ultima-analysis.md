+++
title = 'Ultima Analysis'
date = 2024-09-21T22:39:03+02:00
draft = false
+++

So, ya boi is back with yet another of his geeky interests. This time we are 
gonna be taking a look at a sample made by [crow](https://github.com/cr-0w) 
called "ultima", it is apparently a easy reversing challenge for new malware 
analysts like me, so without further a do, lets get started taking this chunk
of bytes apart!!

# Basic Info and Analysis

To start, let's throw this sucka into PE-Bear and get some basic info about the 
sample:
```txt
ultima
basic info-----------------------------------------------------------------------
( extracted using pe bear v0.7.0 )
name		ultima.exe.crow
md5 		73c0bd614ceeaa765f9e1284c28fdc16
sha256 	    	f48f43594cc5563217a6a19d2af2dc8d82f397a98540fd96c0c5b7d6d6a2a402
type 		pe (exe)
file size 	30840
creation    	28.02.2024 09:18:2024 UTC
modified    	28.02.2024 10:32:2024 UTC
---------------------------------------------------------------------------------
```

Now because I was lucky once a few months ago, I check the headers for 
anything unusual, like a modified DOS stub or something; However I found...
exactly nothing. (womp womp) Anyhow let's proceed, I look for any weird sections 
or a big difference between the size on disk and size in memory, but we 
(*luckily*) find nothing special (see note on why), except that the binary seems to 
be compiled with debug symbols... rookie mistake haha.

> \* *But DeLuks, why would it be a problem if theres something weird in the sections*
>
> Well dear reader, if we were to find something weird, it could be a indicator that the sample is packed, which sucks! (because I got a massive skill issue)

Next let's go on to the strin- WAIT ITS SIGNED, there is a lot of junk in the 
strings but we see some digicert stuff and the info about the signature, 
heres what I found:
```txt
signature-------------------------------------------
name 	Garlean Empire / digicert 2023
email   gaius@mysweetchocobo.eo
time    28.02.2024 11:32:24
valid   27.02.2025
----------------------------------------------------
```

Okay, back to strings, we see more trash and then boom, we stumble across very 
descriptive strings that give us a good idea of what the sample does:

```txt
Attempting to read value from Computer\HKEY_CURRENT_USER\Console\VirtualTerminalLevel...
Computer\HKEY_CURRENT_USER\Console\VirtualTerminalLevel exists but isn't set to one...
Computer\HKEY_CURRENT_USER\Console\VirtualTerminalLevel is already set to one!
Computer\HKEY_CURRENT_USER\Console\VirtualTerminalLevel wasn't found!
Enabling ansi support for command prompt...
Registry key and value created successfully. Terminal restart required.
Heh. We'll take care of that for you. See ya 'round, initiate.
```

This seems to be checking if ANSI is enabled on the system... weird bit 
alright. Then we see a banner and right below we see that it creates a text 
file in `C:\Temp` called `garlean_note.txt`. No idea why but aight...

```txt
Branded by the Garlean Empire.
C:\Temp
C:\Temp\garlean_note.txt
Left a little nugget beh
```

Right below that we see some strange plaintext strings and below a welcome 
message with a login prompt, from that we can assume these could be some 
credentials. Better note these down for later.

```txt
gaius
glitterychocobo123
Welcome operator. Use your Empire-issued credentials to sign in.
Username :: >
Password :: >
```

Then we see some debug prints that are very verbose and describe
the samples behaviour extremely well, Awesome!!


```txt
[0x%p] Current process handle.
VirtualAlloc
[0x%p] [RW-] Allocated a buffer with PAGE_READWRITE [RW-] permissions!
WriteProcessMemory
[0x%p] [RW-] [%zu/%zu] Writing payload bytes to the allocated buffer...
[0x%p] [RW-] Wrote %zu-bytes to the allocated buffer
VirtualProtect
[0x%p] [R-X] Changed buffer's page protection to PAGE_EXECUTE_READ [R-X]
CreateThread
[0x%p] Thread created! waiting for it to finish its execution...
[0x%p] Thread finished execution, beginning cleanup...
[0x%p] Closed process handle
[0x%p] Closed thread handle
[0x%p] Remote buffer freed
```
From this we see this could be a local shellcode injection, which also means
we'll maybe have to reverse some shellcode maybe. T-T

> SPOILER: We won't have to do that because \*dynamic analysis\* O-O

Anywayys we see some more signature junk and finally the location of the pdb file on 
the malware developers machine:
```txt
C:\Users\hepha\Documents\Programs\maldev\Ultima\x64\Release\Ultima.pdb
```

Now, let's take a look at the Imports. We first see some stdlib stuff which is 
not really malicious, but then we see that it imports some rather interesting
functions from `KERNEL32` and `ADVAPI32` these, again, indicate that the sample 
modifies some registry values (possibly to enable ANSI) and does a (local) process injection.

```txt
/*---------[ Registry Modifications ]---------*/
RegGetValueA
RegCreateKeyExA
RegSetValueExA
RegCloseKey
/*---------[ Strong Indicators of a Process Injection ]---------*/
GetCurrentProcessId
GetCurrentThreadId
GetCurrentProcess

WriteProcessMemory
VirtualProtect
VirtualAlloc
CreateThread
```

Now lets confirm our finds with capa, below you can see the capa output:
```txt
ATT&CK Tactic                     │ ATT&CK Technique
DEFENSE EVASION                   │ Process Injection::Thread Execution Hijacking T1055.003
                                  │ Reflective Code Loading T1620
DISCOVERY                         │ Query Registry T1012
EXECUTION                         │ Shared Modules T1129

MBC Objective                     │ MBC Behavior
FILE SYSTEM                       │ Create Directory [C0046]
OPERATING SYSTEM                  │ Registry::Query Registry Value [C0036.006]
                                  │ Registry::Set Registry Key [C0036.001]
PROCESS                           │ Create Thread [C0038]

Capability                        │ Namespace
contains PDB path                 │ executable/pe/pdb
create directory                  │ host-interaction/file-system/create
inject thread                     │ host-interaction/process/inject
query or enumerate registry value │ host-interaction/registry
set registry value                │ host-interaction/registry/create
parse PE header                   │ load-code/pe
```

Now as we can see I *may* have been right, however we cannot trust these tools fully
so we need to take this sucka apart in IDA.

## Static Analysis with IDA

Since ya boi has absolutely ZERO skills, we hit that <kbd>F5</kbd> faster than light can reach it.
And now that we see our pseudo-C, we can start reversing this sucka.

The main function first checks if ANSI is enabled, if not it enables it and prompts the 
"*victim*" to restart the Program. If it is enabled we proceed to the login where the 
sample does its magic:

![Main Function](/media/main.png)

Let's step into the ANSI check just to be sure its doing what its supposed to...

![ansi check](/media/check_ansi.png)

Aand yeah, looks fine! It reads the `Computer\HKEY_CURRENT_USER\Console\VirtualTerminalLevel` 
and checks if it is set to 1, which obviuosly means that it's on. If it ain't on, we return 0, 
otherwise a 1 is returned.

Next we gotta check the other function I named "enable\_ansi" juuust in case:

![enable ansi](/media/enable_ansi.png)

Yuup, seems aight. It creates a new key at `HKEY_CURRENT_USER\Console` called "VirtualTerminalLevel" 
and sets its value to 1, how nice :)

On to the fun part, the login function check for specific credentials and gives the user/victim
3 tries before it exits, however, the credentials are stored in plaintext so we can just note 
those down and proceed.

![login](/media/login.png)

Now at the end of the login we see a function gets called that, when taking a closer look
it does a "local shellcode process injection" (lots of words just to say it injects some 
shellcode into itself). As you may by know have noticed I'm pretty new at this so ain't no 
way in hell im reversing shellcode.

![shellcode](/media/shellcode_injection.png)

## Dynamic Analysis

So, let's run this (in a VM!!) and see what happens B)

![run](/media/run.png)

Taking a look at procmon, theres a loooot of stuff but everything is as expected.
And as a payload we get this cute little MessageBox:
<div align=center>
  <img alt="msg" src="/media/msgbox.png">
</div>


To sum up program checks for ansi support, enables ansi if necessary, throws a little 
login prompt and finally injects into itself a little message box and leaves a file in 
`C:\Temp\`

## Conclusion

Cool, mystery solved. Here is a little graph for ya to get the gist of how this
thingy works:

![diagram](/media/diagram.png)

Thats all folks! Hope yall enjoyed it! Now I know this post consists of more pictures
than quality content however keep a look out for the next post, which will be all about 
reversing a proper malware sample and not a gameified little program. 

Be sure to check out crow and his YouTube channel and I'll catch ya later!!

## Extra Little Section

> *To: MalwareAuthor@mycodesucks.org*
>
>  Dear Threat-actor, 
>
>  PLEASE do better next time, will ya?
>  - use prints in debug builds
>  - and don't release your darn sample compiled with debug symbols
>  - maybe even consider doing API hashing to hide those imports
>
>  Love, DeLuks <3 

