---
layout: post
title: Autologon and run GUI programs remotely in desktop session
comments: true
---

This is a note of how to automate the remote execution of a GUI program on a test machine.

Note: you should not use this against a non-test machine because the autologon may impose a security risk.

**Scenario**: there is a test machine “ZY” with Windows Server 2008R2 installed, and I want to automate the
process of running a GUI program on it, the program itself is fully automated but cannot run in session 0.

The basic idea is to use scheduled task to run the program in the login session.  PSEXEC will not work
because the process started from session 0 by NT services will be running in session 0, thus no GUI will show
up.  In order to ensure the program can be started after scheduled task is created, the given user must be logged
on to the computer.  This can be done by automatic logon.

### Step 1: Turn on automatic logon

Run the following commands to change the registry values on ZY to turn on autologon:

    reg add \\zy\HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon /v DefaultUserName /d [MyUserName] /f 
    reg add \\zy\HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon /v DefaultPassword /d [MyPassword] /f 
    reg add \\zy\HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon /v DefaultDomainName /d [MyDomain] /f
    reg add \\zy\HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon /v AutoAdminLogon /d 1 /f

For more information please read http://support.microsoft.com/kb/315231

### Step 2: Create scheduled task

Suppose the program we want to run is C:\Windows\System32\notepad.exe.  The credential (must be identical with step 1)
is: CONTOSO\MyUser, password is MyPassword.  The the following command to create a task:

    schtasks /Create /S zy /U CONTOSO\MyUser /P MyPassword /RU CONTOSO\MyUser /RP MyPassword /SC once /TN "notepad" /TR C:\Windows\System32\Notepad.exe /ST 14:50 /IT /F

Note that:

* /ST must specify a future time.  It is not important how exact the start time is, since we will use “schtasks /run” to run the command.
* If the current user is the same as the remote computer where we want to run the command, options /U /P can be ignored.
* It is important to use /IT in order to run the command interactively when the user is logged in.

### Step 3: Reboot the machine

There are several ways to do this, for instance

    shutdown /r /m \\zy /t 0

### Step 4: Check if the computer is rebooted and user has logged in

This can be done by check if there is process running on Console (session 1) or user sessions (session > 1) with given user name:

    tasklist /s zy /u CONTOSO\MyUser /p MyPassword /fi "session gt 0" /fi "username eq MyUser"

If explorer.exe and dwm.exe are listed, the login has completed.

### Step 5: Run the task

We don’t have to wait until the task is started, instead we may start it immediately by:

    schtasks /run /S zy /U CONTOSO\MyUser /P MyPassword /I /TN "notepad"

Note that the task name in /TN should be the same as the name in step 2.

### Step 6: Delete the task

Run the following command to delete the scheduled task:

    schtasks /delete /S zy /U CONTOSO\MyUser /P MyPassword /TN "notepad" /F

### Step 7: Disable the autologon

Refer to commands in step 1 and replace with “reg delete” to delete DefaultPassword and change AutoAdminLogon to 0.

