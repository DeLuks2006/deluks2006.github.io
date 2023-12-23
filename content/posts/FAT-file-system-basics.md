+++
title = 'FAT File System Basics'
date = 2023-12-23T16:07:52+01:00
draft = false
+++
Recently while trying to learn about computer viruses from the 20th century, I came to the conclusion that it is important to understand what the FAT file system is and how it works from a high level perspective. 

### Introduction:
A file system is like the organizational backbone of your computer's storage. It is the software that manages how data is stored, retrieved, and organized on a storage device like a HDD or SSD. It is like the digital equivalent of storing books (the data) on shelves, where each book has its place, and a system that keeps track of where each one is located.

#### Now Why is this so Important?
1. **Organization:** A file system organizes data into files and directories (or folders for the Windows users), making it easy for users and the computer to locate and manage information.
2. **Data Retrieval:** A file system provides a structured way to retrieve data. When you want to open a file or run a program, the file system ensures the computer can find and access the file quickly.
3. **Space Management:** It handles how data is stored physically on the storage device. This includes allocating space for new files, managing free space, and preventing data fragmentation.
4. **Access Control:** Most file systems include permissions and security features. this means you can control who can and cannot access, modify, delete or execute your files.
5. **Metadata:** Additionally file systems provide some information about files, known as metadata. This can include the files attributes, the time and date of creation and the last modification date.
### What is FAT ??
All information about every file on disk is stored in 2 areas on disk called "directory" and the "File Allocation Table" (FAT). The "directory" contains a 32 byte file descriptor record for each file. This descriptor record contains the files name, size, and the creation time and date, and most importantly the file attribute, which contains important information for the OS on how it should handle the file. The FAT is basically a map of the entire disk, which informs the OS which areas are occupied by which files.

![image](/media/descriptor.png)

Each disk has 2 FAT's (one is for backup). But A disk may also have directories. One directory known as the *root directory*, is present on every disk, but the root may habe multiple *sub-directories*, nested one inside of each other to form a tree structure. These sub-directories can be used, created, removed and modified by the user. Therefore the structure can be as simple and as complex as the user makes it.

Both FAT and the root-directory are located in a fixed area on the disk. Interestingly the sub-directories are stored similarly to files, the entry in the parent directory has the "directory" attribute and the content of it is an array of directory entries. The OS handles the sub-directory entry in a completely different way than other files, to make it look like a directory, and not just another file.

The sub-directory file, as mentioned above consists of 32 byte records with the attribute set to directory, which means that the file it refers to is a sub-directory of a sub-directory.
### Versions of FAT

There is about 5 versions of the FAT file system though only 4 of them are commonly used. Here is a short summary of the important versions:
FAT12:
max. volume size of 32MB
FAT16:
max. volume size of 2GB
FAT32:
max. volume size of 2TB
exFAT:
theoretically up to 64ZB (zettabytes), but practical limits may vary
VFAT:
doesn't have a specified volume size since its not a standalone file system
### Now What Are Clusters?

Clusters are units of allocation on a storage device within a file system. When you save a file on a storage device, the file system doesn't allocate space on a byte-by-byte basis. instead it assigns space in clusters. Now a cluster is a group of sectors, which are the smallest physical storage units on a disk. 

### Conclusion
I hope by the end of this blog you have a basic understanding what file systems are and a high level view on how the FAT file system works. Special thanks go to [lukflug](https://github.com/lukflug) for helping me understand how exactly the sub-directories are stored.
