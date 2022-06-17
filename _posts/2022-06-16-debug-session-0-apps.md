---
layout: post
title: Debug Apps Running In Session 0
comments: true
---

Sometimes we have to debug the process crashing issue during the startup. The problem to handle this in Windows Debugger
(a.k.a. windbg) is that the process dies very quickly, by the time you want to attach the debugger the target process is
already gone. A well known solution is _Image File Execution Options_. We can either run `gflags` or set a registry key
so the debugger is automatically started when the process is started. For more information, visit [Image File Execution
Options](https://docs.microsoft.com/en-us/previous-versions/windows/desktop/xperf/image-file-execution-options). In
short, we can add a key at the following location:

    HKLM\Software\Microsoft\Windows NT\CurrentVersion\Image File Execution Options

the name of the key is the EXE file name, such as "notepad.exe", then add a string value with name "Debugger" and value
"C:\Debuggers\windbg.exe", where the value points to the full path of the debugger executable.

Note that the debugger process will be running in the same login session as the process being debugged. If the process
is launched by a Windows system service (or Service Fabric micro-services) in the session 0, the deugger will be too. In
other words, we cannot see the debugger so cannot do anything. The solution for this is to start a debugger server in
session 0 and connect to it from the current login session. For instance, if we want to attach to debugger when
notepad.exe is started, the registry value will be:

    C:\Debuggers\ntsd.exe -server npipe:pipe=dbg%d -noio -g -G

This means whenever Windows wishes to launch "notepad.exe" it will run above command and add "notepad.exe" at the end,
effectively start a debug session. The parameters are:

- Start a debugger server with a named pipe with the specified name, and the NTSD process ID is the suffix so it is
  possible to debug multiple instances.
- No input or output.
- Ignore the initial breakpoint when the process is started.
- Ignore the final breakpoint at process termination.

Now find the NTSD process ID using the Task Manager or the command line:

```
d:\rd\Networking\NSM\src\nsm\NetworkManager\Logging\Logging>tasklist | findstr /i ntsd
ntsd.exe                     18816 RDP-Tcp#0                  2     27,496 K
```

Then we can connect to the debug server:

    C:\Debuggers\windbg -remote npipe:pipe=dbg18816,server=localhost

Note that the pipe name has the NTSD PID.

Finally, do not forget to set the symbol server path. Within the Microsoft corpnet the following environment variable is
recommended (assuming the cache is at `D:\sym`):

    _NT_SYMBOL_PATH=srv*d:\sym*http://symweb
