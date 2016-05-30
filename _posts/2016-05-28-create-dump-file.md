---
layout: post
title: Create Process Dump File
comments: true
---

In cloud environment we mostly rely on log traces to understand what is happening inside a program and investigate
abnormal behaivors if things do not work as expected. However, sometimes it is needed to get a deep insight of the
process internals via debugging.  When live debugging is not possible, we have to capture a user-mode process dump and
conduct post-mortem analysis.  For instance, memory leak or unusual memory usage increase is such a case where objects
on heap need to examined closely.

The most common way to create a dump file is to use Windows Task Manager.  One can open Task Manager, click "Processes"
tab for Windows 7, or "Details" tab for Windows 8/10, then right-click the name of the process and then click "Create
Dump File".  Once the dump file is created, it will be saved at `%TEMP%` directory, which is usually
`\Users\UserName\AppData\Local\Temp` directory on the system drive.  The size of the dump file is roughly the number of
virtual bytes of the process.

The downside of this method is that the location of the dump file cannot be specified.  In addition, one cannot choose
whether minidump (only thread and handle information) or full dump (all process memory) to create.

In some cases, this could be a severe issue.  In Azure data center, free space on the system drive is extremely limited
(often times less than 15 GB).  Personally I have seen (via post-mortem analysis) that dump file creation causes disk
space exhaustion and makes the OS unusable when responding to a live-site incident, which makes the situation worse by
having a second incident.

A better way to create dump file is to use [ProcDump](https://technet.microsoft.com/en-us/sysinternals/dd996900.aspx) or
AdPlus (a part of WinDBG).  An example of creating a full dump is:

    procdump -ma MyProcess c:\temp\myprocess.dmp

ProcDump is written by Mark Russinovich, a Microsoft Technical Fellow.  It is very small in size.  One can visit technet
page to [download](https://download.sysinternals.com/files/Procdump.zip).  If a GUI is perferred, I strongly recommend a
Task Manager replacement, [Process Explorer](https://technet.microsoft.com/en-us/sysinternals/processexplorer) by the
same author.
