---
layout: post
title: Thought on managed code injection and interception
---

Sometimes code injection/interception will be useful for legitimate reasons.  One scenario is fault injection, where we want to introduce faults to certain code paths in particular exception handling path which might rarely be reached otherwise.  Another scenario is to change the behavior of .NET system libraries.  Recently I was thinking if I could use an alternative app.config to override the appSettings section of an application.  I have source code, but it would be cool if there is a non-intrusive way to do this.  In both scenarios, code injection is a viable technique to solve the problem quickly.

For native code, Microsoft [Detours](http://research.microsoft.com/en-us/projects/detours/) is a very useful and popular tool to intercept Win32 APIs.  It rewrites the code in memory for the target function being intercepted with custom code, and preserves the original code before the instrumentation.  By doing this it is possible to extend the functions or completely changes its behaviors.

For managed code, I am not aware of similar tool as Detours.  A few websites provide a clue to solve this problem.  Most notable one is [A More Complete DLL Injection Solution Using CreateRemoteThread](http://www.codeproject.com/Articles/20084/A-More-Complete-DLL-Injection-Solution-Using-Creat) on [The Code Project](http://www.codeproject.com) and [a blog article by Damian](http://damianblog.com/2008/07/02/net-code-injection/).  It is a similar or in some sense an extended approach of [Three Ways to Inject Your Code into Another Process](http://www.codeproject.com/Articles/4610/Three-Ways-to-Inject-Your-Code-into-Another-Proces).  Basically this approach (essentially native one) works as follows:

1. Opens the target process and gets the HANDLE (OpenProcess).
2. Allocates a virtual memory in the target process for storing the file name of DLL to be injected (VirtualAllocEx).
3. Writes the DLL file name into the virtual memory in the target process (WriteProcessMemory).
4. Starts a thread in the target process which calls LoadLibrary to the DLL name (CreateRemoteThread).
5. The DllMain function starts to take control and do appropriate things, including attaching to the first .NET domain in the process, and loading a managed assembly.

It is also possible to write the code directly to the process memory and start a thread from there.  Nevertheless it is a lot of work, and many things can go wrong.  Since [WriteProcessMemory](https://msdn.microsoft.com/en-us/library/windows/desktop/ms681674(v=vs.85).aspx) and [CreateRemoteThread](https://msdn.microsoft.com/en-us/library/windows/desktop/ms682437.aspx) are designed for debugging native applications, there must be better way to do this.  By accident I saw a project on http://www.codeplex.com/ named [TestApi](http://testapi.codeplex.com/) developed by fellow MSFTees.  It has a fault injection engine for the managed code and this approach is much more elegant.  Essentially it leverages CLR profiling interface to perform code injection/interception.  In high level the approach is like:

1. Gets ICLRProfiling COM interface from mscoree.dll and calls [AttachProfiler](https://msdn.microsoft.com/en-us/library/dd695930.aspx) method to attach custom profiler to the target process.  The profiler is an inproc COM server with [ICorProfilerCallback](https://msdn.microsoft.com/en-us/library/ms230818.aspx) interface.
2. In the callback, two methods are interesting: [JITCompilationStarted](https://msdn.microsoft.com/en-us/library/ms230586.aspx) and [JITCompilationFinished](https://msdn.microsoft.com/en-us/library/ms231578.aspx).  The former notifies the profiler a function is going to be compiled.  As the documentation says, at this point it is possible to replace the MSIL (Microsoft intermediate language) code for the method by calling [SetILFunctionBody](https://msdn.microsoft.com/en-us/library/ms232096.aspx).
3. The functions for getting and setting IL function body are in ICorProfilerInfo interface.
4. To translate the FunctionID to required parameters in SetILFunctionBody, one can use [GetFunctionInfo](https://msdn.microsoft.com/en-us/library/ms232589.aspx) to get the module/method IDs.

More detailed information on the profiler attach and detach is provided on MSDN at this page.  There is also a TechNet article: Rewrite MSIL Code on the Fly with the .NET Framework Profiling API.  MSDN Achieve also provides a sample code to attach a profiler: CLR V4 Profiling API Attach Trigger Sample.  At some point, I might give it a try and see how it works. 
