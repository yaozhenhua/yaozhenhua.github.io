---
layout: post
title: How to Retrive Internet Cookies Programmatically
comments: true
---

Using the cookies stored by the website in the script is a nice trick to use the existing authentication to access the
web service, etc.  There are several ways to retrieve the cookies from IE / Edge, the most convenient way is to directly
read the files on the local disk.  Basically we can use the `Shell.Application` COM object to locate the cookies folder,
then parse all text files for the needed information.  In each file, there are several records delimited by a line of
single character `*`, in each record the first line is the name, second line the value, third line the host name of
website that sets the cookie.  Here is a simple PowerShell program to retrieve and print all cookies:

```
Set-StrictMode -version latest

$shellApp = New-Object -ComObject Shell.Application
$cookieFolder = $shellApp.NameSpace(0x21)
if ($cookieFolder.Title -ne "INetCookies") {
    throw "Failed to find INetCookies folder"
}

$allCookies = $cookieFolder.Items() | ? { $_.Type -eq "Text Document" } | % { $_.Path }
foreach ($cookie in $allCookies) {
    Write-Output "Cookie $cookie"
    $items = (Get-Content -Raw $cookie) -Split "\*`n"
    foreach ($item in $items) {
        if ([string]::IsNullOrEmpty($item.Trim())) {
            continue
        }
        $c = $item -Split "\s+"
        Write-Output "  Host $($c[2])"
        Write-Output "  $($c[0]) = $($c[1])"
    }
}
```

Note that files in `%LOCALAPPDATA%\Microsoft\Windows\INetCookies\Low` do not show up in `$cookieFolder.Items()` list.
An alternative approach is to browse the file system directly, e.g. 
```
    gci -File -Force -r ((New-Object -ComObject Shell.Application).Namespace(0x21).Self.Path)
```
