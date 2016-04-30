---
layout: post
title: How to Read Large MSBuild Log Files
comments: true
---

Our projects are mostly C# and C++ code, and MSBuild is the engine to drive the entire build process.  If the code base
is large, the log file can be very large.  For instance, our build log is over 600 MB and counts for over 5 million
lines of text.  Although the logging is designed to be human readable, it is a challenge to read and extract useful
information in such a huge file.  I would like to share a few tips and hope this info makes your work easier.

Firstly we need a decent editor that is capable to handling large files.  I use VIM all the time, it works well in this
scenario.  Some people like Sublime Text, which I have no experience, but it seems to be equally powerful.  Notepad is a
bad choice, it can handle large file but the performance is so bad and I always wonder why it still exists in Windows.
Notepad++ and Visual Studio Code refuse to load large files, so avoid them.  Finding a nice editor is what every
developer should do.

### Node

Normally MSBuild builds multiple projects in paralle.  Different loggers can be used, we only use the default console
logger, which is multiple-processor aware.  In the log file, each chunk of log, which can be one or multiple lines, is
prefixed with the build node number, for instance:

    Build started 4/28/2016 4:05:25 PM.
         1>Project "X:\bt\713442\repo\src\dirs.proj" on node 1 (default targets).
         1>Building with tools version "12.0".
    ...
         1>Project "X:\bt\713442\repo\src\dirs.proj" (1) is building "X:\bt\713442\repo\src\deploy\dirs.proj" (2) on node 1 (VerifyAlteredTargetsUsed;Build target(s)).
         2>Building with tools version "12.0".
    ...
         2>Project "X:\bt\713442\repo\src\deploy\dirs.proj" (2) is building "X:\bt\713442\repo\src\deploy\WABO\dirs.proj" (6) on node 1 (VerifyAlteredTargetsUsed;Build target(s)).
         6>Building with tools version "12.0".

Suppose you are inspecting a particular project, try to determine the node, then follow all the lines with the right
node as prefix.

### Start and finish

A project is started by loading the specific version of tool:

         6>Building with tools version "12.0".

When the build is finished, the last line looks like:

         6>Done Building Project "X:\bt\713442\repo\src\deploy\WABO\dirs.proj" (VerifyAlteredTargetsUsed;Build target(s)).

Each target also has the similar pattern.  If you want to search the start and end, you may use the following regex
pattern (applies to VIM):

    project .* on node\|done building project

### Copying files

Sometimes the project output could have missing files or wrong version of dependencies.  Typically one can check
`CopyFileToOutputDirectory` to see how the files are copied, for instance:

        54>CopyFilesToOutputDirectory:
             Copying file from "X:\bt\713442\repo\src\Tools\Hugin\obj\amd64\Hugin.exe" to "X:\bt\713442\repo\out\retail-amd64\Hugin\Hugin.exe".

The following regex can be used:

    copying file from .*obj.* to

Once you are familiar with the structure of build log and know a little bit into MSBuild targets, it is quite
straightforward to search the log and investigate the issue.  If you have any question drop a comment and I will try to
answer.
