---
layout: post
title: Package Management in CoreXT
comments: true
---

In this week, CoreXT is officially deprecated from the NSM repository -- more accurately other than using it in legacy
dialtone support, CoreXT is behind us in the daily development. The days of dealing with all the non-standard build
system are over. With that, I can describe some historical technical details for learning purpose.

As previously described, the CoreXT is to ensure the product build can be reproducible, consistent, and reliable. In the
latest version, it supports all kinds of projects, including regular C# libraries and executables, C/C++ native code,
Service Fabric micro-services, Windows Workflow, NuGet package generation, VHD generation, code signing (both
Authenticode and strong name signing), build compositions, etc. In this note, I specifically discuss a few common
questions regarding the package management in CoreXT.

Firstly, assuming you know the basics of C# project build, for instance create a new project in Visual Studio and save
it, you may find the following files:

- `*.cs`: C# source code.
- `*.csproj`: an XML file to describe the project, such as name, type, source code, references etc. This is consumed by
  MSBuild program. We also call it project file.
- `*.sln`: solution file is mainly for Visual Studio IDE as a collection of project files. MSBuild can parse it during
  the build, but in CoreXT it is not part of the build process.

When we run "Build Project" in Visual Studio IDE or run "msbuild" in the developer command prompt, MSBuild program will
read project files, such as csproj, and follow its instruction to compile the source code into OBJ files (often save
them in "obj" directory) and then link them to DLL or EXE files (often save them in "bin" directory).

Any non-trivial projects usually have some _dependencies_, or the references during the compile time (and load them
during the runtime). Some dependencies are part of the .NET framework, which we don't need to worry about. The question
is how to manage the references (DLL files and other collaterals) with the projects. This is why we need _package
management_.

The most common package management in CoreXT, in fact the only one that I use, is NuGet. In public environment, many
NuGet packages (a.k.a. nupkg) are stored in nuget.org, Visual Studio can manage the download, install, upgrade work.
When we add a nupkg in a legacy project (we will come to the format later), we may notice the following:

- NuGet.config file is added optionally to describe where the NuGet server is, and where to save the packages locally.
- Packages.config file is added to list the package names and their versions.
- In csproj file, the reference may use a relative path to locate the DLL in the installed packages.

This works for a single, personal, project. Where the number of the project grows, or multiple developers share a source
repository this does not work because many packages.config file will be messy, and we cannot expect everyone store nupkg
in the same path. CoreXT solves the problem in this way:

- Store all instances of NuGet.Config and Packages.config files in a central location, which is `.corext/corext.config`.
  This file lists the nupkg server locations, and list of nupkg names and versions used in the entire source repository.

- When the dev environment is initialized by running `init.cmd`, download all nupkgs to the directory specified by
  environment variable NugetMachineInstallRoot (e.g. D:\CxCache), record their locations in PROPS file which is injected
  into every CSPROJ. If there is a nupkg named "Microsoft.Azure.Network" version 1.2.3, the install location may be
  `D:\CxCache\Microsoft.Foo.Bah.1.2.3`, and a variable `PkgMicrosoft_Azure_Network` will be defined in PROPS file and
  point to the location on the local file system.

- Argo program will scan all PROJ files and replace absolute/relative paths in "Reference" element with the variables
  defined in the PROPS file. For instance, if we add a DLL refernece with path
  `D:\CxCache\Microsoft.Azure.Network.1.2.3\lib\net45\Abc.dll`, it will replace with the value
  `$(PkgMicrosoft_Azure_Network)\lib\net45\Abc.dll`.

- Above approach solves the most problems for regular DLL references. For running commands outsides of MSBuild,
  corext.config has a section to specify which nupkg paths will be defined in environment variables.

Unlike packages.config, corext.config is able to handle multiple versions. For instance, if some projects need to use
version 1.2.3 some use 2.3.4 of package Microsoft.Network.Abc, then we will write the following:

```xml
<package id="Microsoft.Network.Abc" version="1.2.3" />
<package id="Microsoft.Network.Abc" version="2.3.4" />
```

In PROPS file the following variables will be created:

- `PkgMicrosoft_Network_Abc` pointing to the highest version, i.e. 2.3.4.
- `PkgMicrosoft_Network_Abc_2` pointing to the highest version 2, i.e. 2.3.4.
- `PkgMicrosoft_Network_Abc_2_3`, similarly to 2.3.4.
- `PkgMicrosoft_Network_Abc_2_3_4` to 2.3.4.
- `PkgMicrosoft_Network_Abc_1` to 1.2.3.
- `PkgMicrosoft_Network_Abc_1_2` to 1.2.3.
- `PkgMicrosoft_Network_Abc_1_2_3` to 1.2.3.

If a project wants to references the highest version always, it will use `PkgMicrosoft_Network_Abc`. If the project
wants to lock on version 1 instead, it will use `PkgMicrosoft_Network_Abc_1` instead.

With the above basic principle in mind, now let us address a few questions.

Q: What's the need for packages.config in CoreXT?

> Packages.config files should be merged into corext.config, they should not exist. But if they do, CoreXT will install
> the packages listed there, just like another copy of corext.config.

Q: What about app.config?

> This is unrelated to package management. In the build process, this file will be copied to the output path and renamed
> to the actual assembly name. For instance, if "AssemblyName" in CSPROJ is Microsoft.Azure.Network.MyExe and the
> project type is executable, app.config will become "Microsoft.Azure.Network.MyExe.exe.config".

Q: What is the difference between CSPROJ and PROJ?

> Both are MSBuild project files with the same schema. People usually rely on the file extension to tell what the
> project is for, for instance CSPROJ for C# projects, VBPROJ for Visual Basic projects, SFPROJ for Service Fabric
> projects, NUPROJ for NuGet projects, etc. Sometimes people run out of ideas, or manually write project files, then
> they just call it PROJ.

Q: Is it a good idea to share same corext.config among multiple projects?

> Of course. In fact, all projects in the source repository share a single corext.config. Keep in mind the intention of
> corext.config is to aggregate multiple packages.config.

Q: Then how to handle the case where my project wants to use a different version?

> See above explanation.

Q: This seems like a mess, any simpler way to not deal with corext.config?

> Many source repositories have started to migrate from CoreXT to retail MSBuild with package reference. If you can find
> "Packages.props" file in the top directory and see "MSBuild.Bridge.CoreXT" in corext.config, it probably means both
> legacy and modern SDK-style projects are supported. In the latter, no CoreXT is involved. You may read [Introducing
> Central Package Management](https://devblogs.microsoft.com/nuget/introducing-central-package-management/) for some
> ideas. If you need more practical knowledge, ping me offline.

If anyone has more questions, I will compile them in this note.
