---
layout: post
title: Time Span Measurement in Managed Code
comments: true
---

In performance analysis, the first step is often the time span measurement of various operations in the applications.
It is important to know the correct timestamp and understand which step takes how much time accurately.  Without right
data, one may make incorrect decision and spend resource inappropriately.  This just happened in my team when a DHCP
slow response issue was investigated.

On computers the time is measured by some variant of system clock, which can be a hardware device that maintains a
simple count of ticks elapsed since a known starting date, a.k.a. the epoach, or the relative time measurement device by
performance counters in CPU.  In applications sometimes we want to know the *calendar time*, or the wall clock time so
we can correlate what happens inside the program with what happens in real world (e.g. customer places an order),
sometimes we want to know the *time span*, or how fast / slow an operation is.  We often use *timestamp* retrieved from
the system time for the former, and calculate the difference of two timestamps to get the latter.  Conceptually it
works, but the relative error of the measurement matters.

On the PC motherboard there is a real-time clock chip, some people call it CMOS clock since the clock is a part of CMOS.
It keeps the date and time, as well as a tiny CMOS RAM which contains the BIOS settings in old days. Even when PC is
powered off, it is still running on a built-in battery.  Via I/O ports 0x70 and 0x71, one can read or update the current
date / time.  Because the cheap oscillator often not works at designed frequency, the clock may drift over time.  The OS
compensates this by periodically synchronizing with the time service using NTP, e.g. time.nist.gov is considered as one
of most authortiative time source.

In the OS the initial date / time clock is retrieved from RTC, then it is updated periodically, typically 50 - 2000
times per second.  The duration is called *clock interval*.  The clock interval can be adjusted by applications, for
instance multimedia applications and Chrome browser often set the clock interval to 1 ms.  Smaller interval has negative
impact on the battery usage, it is avoided whenever possible.  On servers this is normally kept as default.

One can query the clock using sysinternal app `clockres.exe` or Windows built-in program `powercfg`.  On my desktop the
clock interval is 15.625 milliseconds (ms) (64 Hz frequency), and the minimum supported interval is 0.5 ms.  15 ms
resolution is sufficient for most real-world events, e.g. when the next TV show starts, but it is insufficient for time
measurements on computers in many cases, in particular the events lasting tens of milliseconds or less.  For instance,
if an action starts at some point in clock interval 1 and stops at another point in clock interval, using the system
clock you will see a time span of 31 ms, but actually it can be anywhere from 15.625 to 46.875 ms.  On the other hand,
if an action starts and stops within the same clock interval, the system clock will tell you the duration is 0 but it
can be as long as 15 ms.  My coworker once said "the request is received at xxx, at the same time it gets processed
...", sorry within a single thread two different things do not happen at the *same* time.

In .NET, system clock is retrieved using `DateTime.UtcNow` (see [MSDN
doc](https://msdn.microsoft.com/en-us/library/system.datetime.utcnow%28v=vs.110%29.aspx?f=255&MSPPError=-2147217396)).
It is implemented by calling Win32 API [GetSystemTimeAsFileTime
function](https://msdn.microsoft.com/en-us/library/windows/desktop/ms724397(v=vs.85).aspx).  Note that although the unit
is in tick (100 ns), the resolution is really clock interval.

In old days (Windows XP, Linux many years ago) people used to read processor timestamp counter (rdtsc) to acquire high
resolution timestamps.  It is tricky to get it right in virtual environment, multiple-core system, and special
hardwares.  Nowadays on Windows the solution is Win32 API [QueryPerformanceCounter
function](https://msdn.microsoft.com/en-us/library/windows/desktop/ms644904(v=vs.85).aspx).  On modern hardware (i.e.
almost all PCs nowadays), the resolution is less than 1 microseconds (us).  On my "cost effective" home PC, the
resolution is about 300 ns, or 3 ticks.  For more information on QPC read MSDN article
[here](https://msdn.microsoft.com/en-us/library/windows/desktop/dn553408%28v=vs.85%29.aspx?f=255&MSPPError=-2147217396).

In .NET, QPC is implemented by `System.Diagnostics.Stopwatch` (see reference source
[here](http://referencesource.microsoft.com/#System/services/monitoring/system/diagnosticts/Stopwatch.cs,69c6c3137e12dab4)).
For any time span measurement this should be considered as the default choice.

Another thing to remember is that `Stopwatch` or QPC is not synchronized to UTC or any wall clock time.  This means that
if the computer adjusts the clock after synchronizing to the time server, this will not be affected -- no forward or
backward jump.  In fact I saw a stress test failure caused by clock forward adjustment, when the timeout was evaluated
the time sync happened so the calculated time span was several minutes greater than the actual value.  This kind of bug
is hard to notice and investigate, but trivial to fix.  Avoid wall clock time if possible.

In term of overhead, Stopwatch is more expensive than DateTime.UtcNow.  However both take very little CPU time.  On my
home PC, Stopwatch takes about 6 ns vs 3 ns for DateTime.UtcNow.  Normally it is much shorter than the duration being
measured.

The last question is that, if we do need the absolute time correlation on multiple computers, is there anything better
than `System.DateTime.UtcNow`?  The answer is yes, setup all computers to the same time source, then use
[GetSystemTimePreciseAsFileTime
API](https://msdn.microsoft.com/en-us/library/windows/desktop/hh706895%28v=vs.85%29.aspx?f=255&MSPPError=-2147217396).
It is supported in Win8 / Server 2012 or later.  In .NET one needs to use P/Invoke to use it.
