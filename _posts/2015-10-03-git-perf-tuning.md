---
layout: post
title: Git Performance Tuning
---

The vanilla Git installed using Chocolatey or [git-scm](https://git-scm.com/download/win) (same source) is slow.  On my company dev machine it is even slower than my home machine. If you compare the performance with Linux counterpart, it is noticeably slower. In fact if you open Git Bash, you may notice every command, including ```ls```, has significant slow response. There are fundamental issues that we cannot fix, for instance extensive using of fork() which is cheap on Linux but expensive on Windows, but with some tuning we can make it faster.

## Exclude source location in virus scanning

This has nothing to do with Git. By excluding the source location Git, the build process, etc. effectively bypasses the FS filter driver. You should do this even if you are not using Git for development.

## Modify bash profile

Git is built on top of mingw, and it often involves bash which in turns load user profile. In Git bash, launch of shell
will load ```/etc/profile``` and then ```$HOME/.bashrc```. In msysgit, the shell prompt is set to display various repo
information, and this requires running Git commands. This overhead can be simply eliminated by setting the following in
```$HOME/.bashrc```:

    #!/bin/bash
    export PS1='\w $ '

## Caching in Git

The following configuration will turn on file system operations in parallel and cache:

    git config --global core.preloadindex true
    git config --global core.fscache true

## Code Signing

Msysgit, repo.exe (distributed by Azure build), and Chocolatey are all unsigned (Authenticode signing). Thanks to awesome
AppLocker (enforced by IT department) Windows will try to validate the source of publisher and load all catalogue files
under ```%windir%\System32\catroot\{F750E6C3-38EE-11D1-85E5-00C04FC295EE}```. On my machine, that’s over 5500 files to
filter and causes over one half second. And this is done for each process launched every time (i.e. no caching). To
eliminate this, using your own code signing certificate to sign *.exe in the following locations:

- C:\Chocolatey\bin
- C:\Program Files (x86)\Git\bin
- C:\Program Files (x86)\Git\cmd

To check whether you have code signing cert or not, run the following command in PowerShell:

    dir Cert:\CurrentUser\my -CodeSigningCert

The simplest way to sign all executables is (run this as Administrator):

    for %f in (*.exe) do "C:\Program Files (x86)\Windows Kits\8.1\bin\x86\signtool.exe" sign /a /uw %f

This will look for all valid certs and select the one that is valid the longest. It doesn’t matter what cert it is, as
long as the cert chain is valid.

With these adjustment, “git status” in a workspace with about 32k files takes about 0.4 seconds, also the Git SH is much
more useful. I hope this tip is useful to you.
