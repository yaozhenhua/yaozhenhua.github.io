---
layout: post
title: Effective Code Search on Windows
comments: true
---

No one remembers everything. In a large code base, we usually only know the details of a tiny part of it. Often times we have to search the code to know how things are defined or used across large number of files. Here I’d like to share a few tips to search source code.

Many software including Visual Studio, notepad++, Sublime Text provide a multiple-file search option, such as “Find in Files”. I don’t use them too often, my alternative is <code>findstr /snipc:STRING files…</code> for literal string search. If the amount of files isn’t too huge, these non-indexing options are often acceptable. Note that “regex” in findstr is very limited. If you do need regex search, PowerShell Select-String cmdlet works much better.

For pure source code in Git and you only need to search one repo, “git grep” is faster than brute-force search. If you don’t know this command, try it now and you will be surprised.

For huge code base, indexing is the only effective option that I know of. Fortunately it is super simple. Here is what I do:

- Create a separate directory for all source code you may use. Store all repos/enlistments in this directory.
- Open “Indexing Options” in Control Panel, click “Modify” button and select the directory above. It will be listed in “Index these locations”.
- Make sure the filter description for the interested File Type is “Index Properties and File Contents”. I haven’t found any file types are set incorrectly by default, but your situation might be different
- Indexing will take a while. Wait for a day or two.
- All above steps only need to be performed once. Later you can update the code as usual, and search the code in File Explorer.

My source code stored in a spinning disk is about 50 GB with 240k text and binaries. Searching is instant (lower than sub-second), which is amazing for so many files.
