---
layout: post
title: Build Systems Through My Eyes
comments: true
---

Before joining Microsoft, I worked on Linux almost all the time for years. Similar as most other projects, we used shell
scripts to automate the build process, and GNU automake / autoconf were the main toolset. Occasionally
[CMake](https://cmake.org/) was used to handle some components where necessary. In Windows team, I witnessed how to
build enormouse amount of code consistently and reliably using sophicated in-house software. In this note, a few build
systems that I used in the past are discussed to share some learnings.

## Why do we need a "build system"?

A simple hello world program or school project doesn't need a build system. Load it to your favorite IDE and run it. If
it works, congrats. If not, it is your responsibility to fix it. Obiviously this logic won't fly for any projects shared
by multiple people. Windows SDK and Visual Studio don't really tell us how to deal with large number of projects in an
automated and reliable manner.
[NMake](https://docs.microsoft.com/en-us/cpp/build/reference/nmake-reference?view=msvc-160) is the counterpart of
Makefile and able to do the job to some extend. However, honestly I haven't seen anyone using it directly because of the
complexity level at large scale. We need a layer on top of SDK and VS toolset to automate the entire build process for
both developers and lab builds, and the process must be reliable and repeatable. For Windows, *reproducibility* is
critical. Imagine you have to fix a customer reported issue on a version released long time back, it would be
unthinkable if you could not produce the same set of binaries as the build machines did previously in order to debug. By
the way, all build systems are command line based since no one will glare at their monitor for hours, no fancy UI is
needed.

## Razzle and Source Depot

*Razzle* is the first production-quality build system I used. Essentially it is a collection of command line tools and
environment variables to run build.exe for regular dev build and timebuild for lab builld. At the start of day, a
command prompt is opened, razzle.cmd is invoked, which performs some validation to the host environment, sets up
environment variables and presents a command prompt for conducting subsequent work for the day.

In Razzle, everything is checked into the source repository. Here "everything" is literally *everything* including
source code, compilers, SDK, all external dependencies, libraries, and all binaries needed for the build process.
Outside of build servers, no one checks out everything on their dev machine which could be near or at TB. Working
enlistment is a partial checkout at tens of GB level.  Because of the outrageous requirement on the scale, an in-house
source repository called *Source Depot* (rumor said it was based off [Perforce](https://en.wikipedia.org/wiki/Perforce)
with needed improvement, not sure the accuracy though) is used, and a federation of SD servers is used to support the
Windows code base. On top of sd.exe, there is a batch script called sdx.cmd to coordinate the common operations across
multiple SD servers. For instance, instead of using "sd sync", we used to run "sdx sync" to pull down the latest
checkine. Some years later, in order to modernize the dev environment [git](https://en.wikipedia.org/wiki/Git) replaced
SD, which I have no hands-on experience.

Razzle deeply influenced other build systems down the line. Even now, people used to type "build" or even "bcz" even if
the latter is not really meaningful in the contemporary build systems. One of the great advantages of Razzle is its
reproducibility and total independence. Because everything is stored in SD, if you want to reproduce an old build, you
just check out the version at the required changeset, type "build" and eventually you will get the precise build
required by the work, other than timestamp, etc. In practicality, with a clean installed OS, run the enlistment script
on a network share which in turn calls sd to download the source code (equivalent to "git clone"), then you have the
fully working enlistment, nothing else is needed (assuming you are fine with editing C++ code with notepad).

Instead of Makefile or MSBuild project files, `dirs` files are used for directory traversal, `sources` files are used to
build the individual project. An imaginary sources file is like the following (illustration purpose only):

```
TARGETNAME  = Hello
TARGETTYPE  = DYNLINK
UMTYPE      = console

C_DEFINES   = $(C_DEFINES) -DWIN32 -DMYPROJECT

LINKER_FLAGS = $(LINKER_FLAGS) -MAP

INCLUDES    = $(INCLUDES);\
    $(PROJROOT)\shared;

SOURCES     = \
    hello.cpp \

TARGETLIBS  = $(TARGETLIBS) \
    $(SDK_LIB_PATH)\kernel32.lib \
    $(PROJROOT)\world\win32\$(O)\world.lib \
```

Invocation of underlying ntbuild will carry out several build passes to run various tasks, such as preprocessing, midl,
compile, linking, etc. There are also postbuild tasks to handle code signing, instrumentation, code analysis,
localization, etc. Publish/consume mechanism is used to handle the dependencies among projects, so it is possible to
enlist a small subset of projects and build without missing dependencies.

Coming from Linux world, I didn't find it too troublesome using another set of command line tools, other than missing
cygwin and VIM.  However, for people who loved Visual Studio and GUI tools, this seemed to be a unproductive
environment. Additionally, you cannot easily use Razzle for projects outside Windows.

## CoreXT

After moving out of Windows, I came to know CoreXT in an enterprise software project. Initially as a Razzle clone, it is
believed to be a community project maintained by passionate build engineers inside Microsoft (by the way I have never
been a build engineer). It is widely used in Office, SQL, Azure, and many organizations even today.  Six years ago,
Azure projects were based on CoreXT and followed similar approach as Windows on Razzle: everything stored in SD,
dirs/sources on top of ntbuild, timebuild to produce nightly build, etc. The main difference was each service had its
own enlistment project, just like a miniature of Windows code base. Inter-service dependencies were handled by copying
files around. For instance, if project B had to use some libraries generated by project A, project A would *export*
those files, and project B would *import* them by adding them to SD.  For projects based on managed code (most are),
msbuild instead of NTBuild was used for convenience.

At the time, the dev experience on CoreXT was not too bad. It inherited all the goodness of Razzle. But it was still a
bit heavyweight. Even you only had tens of MB in source code, the build environment and external dependencies would
still be north of ten GBs in size. Young engineers considered it as dinosour environment, which was hard to argue if
comparing with open source toolset. The supportibility of Visual Studio IDE was via csproj files (used by both build and
IDE) and sln files (used by IDE only).

Five years ago, people started to modernize the dev environment. The first thing was move from SD to git. Without LFS,
it is impractical to store much data in git. At least, 1 GB was considered as acceptable upbound at the time. So we had
to forget about the practice of checking in everything and started to reduce the repo size dramatically. But Windows SDK
alone was already well over 1 GB, how to handle the storage issue without sacrifising reproducibility? The solution was
to leverage [NuGet](https://docs.microsoft.com/en-us/nuget/what-is-nuget). Essentially, besides corext bootstrapper
(very small) and source code everything was wrapped into NuGet packages. This solution has been lasted until today.

Most projects have its own git repository. Under the root directory, init.cmd is the replacement of Razzle.cmd, it
invokes corext bootstrapper to setup the enlistment environment. Similarly as Razzle, it is still a command prompt with
environment variables and command aliases. `corext.config` under `.corext` is similar as nuget.config, which contains the
list of NuGet feeds (on-premises network shares in the past, ADO nowadays) and list of packages. All packages are
downloaded and extracted into *CoreXT cache* directory. MSBuild project files are modified to use the toolset in the
cache directory, such as:

```xml
<?xml version="1.0" encoding="utf-8"?>
<Project ToolsVersion="15.0" DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <Import Project="$(EnvironmentConfig)" />
  ...
  <Import Project="$(ExtendedTargetsPath)\Microsoft.CSharp.targets" />
</Project>
```

Here the trick is `EnvironmentConfig` is a environment variable pointing to a MSBuild props file in CoreXT cache, this
file bootstraps everything after that. With that, when build alias is invoked, MSBuild program is called, then compilers
and build tools in CoreXT cache are used, instead of the one installed on the host machine.

In theory, the entire process relies on nothing but the files in CoreXT cache. One does not need to install Visual
Studio or any developer tools on their computers. In practice, occasionally some packages reference files outside of the
cache and assume certain software to be installed. However, that is rather an exception than a norm.

For developers, we use Visual Studio or VS Code to browse code, write code, build and debug. A tool is provided to
generate solution file from a set of MSBuild project files (csproj and dirs.proj). Then the solution is loaded in IDE.

Dependencies among projects are handled by NuGet packages. During official build, we can choose whether or not to
publish packages into feeds on ADO. Other projects simply add the `<package .../>` in corext.config file should they
want to consume any packages.

So far most projects and most people in my org are still using CoreXT in this form. It is used by engineers during
daily development, by build machines in the lab, by distributed build in the cloud, and everywhere we want it to be.
Other than compiling source code and building product binaries, it also carries out various other tasks, including but
not limited to static code analysis, policy check, VHD generation, NuGet package creation, making app package suitable
for deployment, publishing symbols, etc.

## CBT and Retail MSBuild

Again, CoreXT is considered to be modern day relic. People use it because they have to. In particular, it is highly
desireable to have seamless integration with Visual Studio and ability to consume latest technology from dotnet core.
Before MSBuild becomes more capable, [Common Build Toolset](https://github.com/CommonBuildToolset) (CBT) was developed
as a GitHub project to fulfill this requirement. This is a lightweight framework to provide consistent "git clone +
msbuild" experience to codebase using it. One of additional advantage is it is open source, for the internal projects
that need to sync to github periodically, no more duplicate build systems (one for internal build, one for public) is
needed.

Using CBT is extremely simple from dev perspective. No internal machinary whatsoever. Just clone the repo and open it
using Visual Studio.  Adding new project is also straightforward, no more need to perform brain surgery to csproj files
like CoreXT.  The downside is obvious, you must install essential build tools such as VS. Reproducibility isn't strictly
guaranteed as far as I can. After all, the VS developer command prompt is used. For most Azure teams, this may not be a
concern since things move so fast, I haven't met anyone who complains they cannot *reproduce* the build one year ago for
serving old version of their service.

CBT is somewhat short-lived. For some people, by the time they come to know the migration path from CoreXT to CBT, it is
already deprecated. The latest shiny framework on the street is Retail MSBuild. :-)  It works similarly as CBT but even
more lightweight. With this framework, engineering teams are able to use Visual Studio and retail Microsoft toolset in
their most natural way. In CoreXT, people have to spend a lot of time for any new technology because the framework
intentionally works differently. Personally I've spent many hours to make dotnet core working in my team, some other
components might be worse. With retail MSBuild, everything just works with plain simple SDK style project files with
PackageReference. Precious resource can be spent on real work, we are not rewarded for reinventing the wheel (and
possibly a worse one) anyway.

## Snowflakes

Other than the most popular ones aforementioned, some teams write their own framework for meeting their unique
requirement. For instance, several years ago a team needed a high-performance build integrating with VSTS build
defitions with minimal overhead, so a thin wrapper was built on top of collection of project files and batch scripts. In
[RingMaster](https://github.com/Azure/RingMaster) I had to write my own version of build framework because internal
proprietary build system could not be released because of approval process, project would not build without one similar
to CoreXT, and no other alternative was available (CBT did not exist at the time). At the end, the projects were
migrated to SDK-style to make this work easier.

In the future, I look forward to retail MSBuild being adopted more widely and internal build systems going away
eventually. I love open source down to my heart. :-)
