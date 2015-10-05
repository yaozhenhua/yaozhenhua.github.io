---
layout: post
title: Copy app.config in the project reference
---

This is a note of how to ensure the app.config file is copied along with assemblies for the project
reference in managed project.

**Problem**: suppose we have the two C# projects A and B, project A is referenced in B.

* Project A
  * app.config
  * …
  * bin
    * A.dll
    * A.dll.config
* Project B
  * app.config
  * …
  * bin
    * B.dll
    * B.dll.config
    * A.dll

When the project B is built, project A assembly will be copied to the output path but the app.config
will not follow.

**Solution**: build the project with MSBuild with options “/fl /v:d”, read MSBuild.log and analyze when
the output of project A is copied to the output path of project B.  We can see that it is the following
parameters and target in file `%windir%\Microsoft.NET\Framework\v4.0.30319\Microsoft.Common.targets`
that control what to be copied and how:

        <!--
        These are the extensions that reference resolution will consider when looking for files related
        to resolved references.  Add new extensions here if you want to add new file types to consider.
        -->
        <AllowedReferenceRelatedFileExtensions Condition=" '$(AllowedReferenceRelatedFileExtensions)' == '' ">
            .pdb;
            .xml
        </AllowedReferenceRelatedFileExtensions>
    
    ...
    
        <ResolveAssemblyReference
            Assemblies="@(Reference)"
            AssemblyFiles="@(_ResolvedProjectReferencePaths);@(_ExplicitReference)"
            TargetFrameworkDirectories="@(_ReferenceInstalledAssemblyDirectory)"
            InstalledAssemblyTables="@(InstalledAssemblyTables);@(RedistList)"
            IgnoreDefaultInstalledAssemblyTables="$(IgnoreDefaultInstalledAssemblyTables)"
            IgnoreDefaultInstalledAssemblySubsetTables="$(IgnoreInstalledAssemblySubsetTables)"
            CandidateAssemblyFiles="@(Content);@(None)"
            SearchPaths="$(AssemblySearchPaths)"
            AllowedAssemblyExtensions="$(AllowedReferenceAssemblyFileExtensions)"
            AllowedRelatedFileExtensions="$(AllowedReferenceRelatedFileExtensions)"
    ...
            &lt;Output TaskParameter="CopyLocalFiles" ItemName="ReferenceCopyLocalPaths"/>
    ...
        </ResolveAssemblyReference>

Therefore the solution is to put the following lines in csproj file in project B at the beginning of
`<PropertyGroup>`:

    ...
    <PropertyGroup>
      <AllowedReferenceRelatedFileExtensions>
          .pdb;
          .xml;
          .exe.config;
          .dll.config
      </AllowedReferenceRelatedFileExtensions>
    ...

With the change, app.config will follow the assemblies in both the build and unit test.