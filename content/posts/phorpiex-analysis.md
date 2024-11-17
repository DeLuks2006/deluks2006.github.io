+++
title = 'Phorpiex Analysis'
date = 2024-11-17T18:02:54+01:00
draft = false
+++

Whats up nerds, in this short blog post we will be taking a quick 
look at a phorpiex sample. So without further a do, let's get into it.

## Basic Information and Analysis

```txt
name        sysppvrdnvs.exe
created     Monday, 04.11.2024 20:54:31 UTC
md5         71eb58a2d671c155c41e61314105bf8f
sha256      241b78461d7743d24d7dac230facf4caa40c1c1bb9763b08c1d6f42545778938
format      pe (exe)
arch        i386
```

From analysing the sizes on disk and in memory the file is not packed. Taking a look 
at the strings we can observe some commands/arguments that could be executed once ran to 
disable windows updates and nuke our beloved windows defender. 

<div align=center>
    <img alt="strings" src="/media/phorpiex/strings.png" />
    <br /><br />
    <img alt="more strings" src="/media/phorpiex/more-strings.png" />
</div>

Jumping into IDA we first see that it calls some function that first checks, and if it 
doesnt exist, creates a file called `Tpregnant.txt` in the `%TEMP%` directory. 

<div align=center>
    <img alt="createTXT" src="/media/phorpiex/createTXT.png" />
</div>

Once that is done, it checks if a file called `\\sysppvrdnvs.exe` is in the `%userprofile%`
directory; If thats the case its then checked if its installed in the `%windir%`, if not it 
is copied there and then it sets the run key in the HKLM and saves it as "Windows Settings".

<div align=center>
    <img alt="run key set" src="/media/phorpiex/runkey.png" />
</div>

Next up we can observe it calls a function that contacts the following URL using the user-agent seen in the picture below:

`hxxp[:]//91.202.233[.]141/HKLMINSTOK`

<div align=center>
    <img alt="http server comm" src="/media/phorpiex/http.png" />
</div>

Then it proceeds to check if windows defender is installed by checking if the following path exists: 
`%programdata%\\Microsoft\\Windows Defender`. 

If it does exist it contacts the `hxxp[:]//91.202.233[.]141/WINLASTFIX` endpoint using the same user-agent and then proceeds to nuke 
defender and disable auto-updates, just like we saw above in the strings.

<div align=center>
    <img alt="nuke" src="/media/phorpiex/nuke.png" />
</div>

## Summary

Heres what I found in short, let me know if I missed something.

- Contacts `hxxp[:]//91.202.233[.]141/HKLMINSTOK` and `hxxp[:]//91.202.233[.]141/WINLASTFIX`
- nukes defender
- disables updates
- creates persistence by setting the run key in the registry
- for some reason creates the file `%TEMP%\Tpregnant.txt`
