---
layout: post
title: Containerized .NET 5.0 App Running on Raspberry Pi 3B
comments: true
---

The release of .NET 5.0 is an exciting news for us. No more argument whether to migrate to .NET core or upgrade to newer
version of .NET framework, .NET 5 or 6 (LTS version) will be the north star for control plane services with better
performance and faster speed of innovations. Additionally it is relieving to know multiple platforms (not just different
editions of Windows) can be unified with one set of source code.

Today I found a little cute [Raspberry Pi 3B](https://www.raspberrypi.org/products/raspberry-pi-3-model-b/) lying
unused. It was a toy for my son but he got a real computer already. I wondered whether it was able to run .NET 5 apps,
so I decided to give a try. The process turns out to be quite straightforward, although I don't think it's useful to do
so. Anyway here is what I've done.

## Upgrade Raspberry Pi OS

Although no endpoint is opened, it is still a good practice to keep the OS up to date:

    sudo apt update
    sudo apt upgrade
    sudo apt full-upgrade
    sudo autoremove

## Setup Docker

My work doesn't actually use Docker, but I was curious whether it runs in such a resource-constrained environment.
Firstly, run the script from the official website:

    curl -sSL https://get.docker.com | sh

In order to not prefix almost all commands with `sudo`, I added the default user account to the docker user group:

    sudo usermod -aG docker pi

Then ran a smoke testing:

    docker version
    docker info
    docker hello-world

It was encouraging to see everything just works.

## Install .NET SDK 5.0.1

Initially I thought package management might take care of this. But I had to do it manually like the following:

    wget https://download.visualstudio.microsoft.com/download/pr/567a64a8-810b-4c3f-85e3-bc9f9e06311b/02664afe4f3992a4d558ed066d906745/dotnet-sdk-5.0.101-linux-arm.tar.gz
    sudo mkdir /var/dotnet
    sudo tar zxvf dotnet-sdk-5.0.101-linux-arm.tar.gz -C /var/dotnet

Then I created a sample console app to confirm it indeed worked. Lastly, I changed `$HOME/.bashrc` for required change
of environment variables.

## Visual Studio Code

VI is preinstalled on Raspberry Pi, just like every other Linux distributions. However, VS Code is so popular that I
must give a try.  After download the Debian package from VS Code download site, I installed it with the following:

    sudo apt install ./code_1.52.1-1608136275_armhf.deb

Now the "development" environment is ready. Understandably nothing is as responsive as my desktop, but it isn't slow to
the point of unbearable. In fact, writing a simple code was just fine.

Since .NET already provides a sample docker image, why not give a try:

```
pi@raspberrypi:~ $ docker run --rm mcr.microsoft.com/dotnet/samples
Unable to find image 'mcr.microsoft.com/dotnet/samples:latest' locally
latest: Pulling from dotnet/samples
c06905228d4f: Pull complete 
6938b34386db: Pull complete 
46700bb56218: Pull complete 
7cb1c911c6f7: Pull complete 
a42bcb20c9b3: Pull complete 
08b374690670: Pull complete 
Digest: sha256:9e90c17b3bdccd6a089b92d36dd4164a201b64a5bf2ba8f58c45faa68bc538d6
Status: Downloaded newer image for mcr.microsoft.com/dotnet/samples:latest

      Hello from .NET!
      __________________
                        \
                        \
                            ....
                            ....'
                            ....
                          ..........
                      .............'..'..
                  ................'..'.....
                .......'..........'..'..'....
                ........'..........'..'..'.....
              .'....'..'..........'..'.......'.
              .'..................'...   ......
              .  ......'.........         .....
              .                           ......
              ..    .            ..        ......
            ....       .                 .......
            ......  .......          ............
              ................  ......................
              ........................'................
            ......................'..'......    .......
          .........................'..'.....       .......
      ........    ..'.............'..'....      ..........
    ..'..'...      ...............'.......      ..........
    ...'......     ...... ..........  ......         .......
  ...........   .......              ........        ......
  .......        '...'.'.              '.'.'.'         ....
  .......       .....'..               ..'.....
    ..       ..........               ..'........
            ............               ..............
          .............               '..............
          ...........'..              .'.'............
        ...............              .'.'.............
        .............'..               ..'..'...........
        ...............                 .'..............
        .........                        ..............
          .....
  
Environment:
.NET 5.0.1-servicing.20575.16
Linux 4.19.66-v7+ #1253 SMP Thu Aug 15 11:49:46 BST 2019
```

The following is a screenshot of VS Code:

![VS Code Screenshot](/public/20201225-vs-code-screenshot.png)

## Create a Docker Image

It was not tricky to create a Docker image using the official .NET 5.0 image. The following command shows the pulled
image:

    docker pull mcr.microsoft.com/dotnet/runtime:5.0

After copying the published directory to the image, it ran smoothly. However, I found the image was quite large in size,
the above was 153 MB. After some trial and error, I found a way to make it smaller.

Firstly, change the csproj file to enable Self-Contained-Deployment with trimming, and also turn off globalization since
I almost never need to deal with it in the control plane:

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net5.0</TargetFramework>
    <InvariantGlobalization>true</InvariantGlobalization>
    <PublishTrimmed>true</PublishTrimmed>
    <TrimMode>link</TrimMode>
    <TrimmerRemoveSymbols>true</TrimmerRemoveSymbols>
  </PropertyGroup>

</Project>
```

Then a SCD package was published to `out` directory:

    dotnet publish -c release -r ubuntu.18.04-arm --self-contained -o out 

Note that it is specifically targeted to Ubuntu 18.04 LTS. The package size seems to be reasonable given the runtime is
included:

```sh
pi@raspberrypi:~/tmp $ du -h out
16M	out
```

A docker file is written to build image on top of Ubuntu 18.04 minimal image:

```
FROM ubuntu:18.04
RUN mkdir /app
WORKDIR /app
COPY out /app
ENTRYPOINT ["./hello"]
```

Build the image:

    docker build --pull -t dotnetapp.ubuntu -f Dockerfile.ubuntu .

Give a try to the image and compare with the execution outside of container:

```sh
pi@raspberrypi:~/tmp $ docker run --rm dotnetapp.ubuntu
Hello World!
Duration to schedule 100000 async tasks: 00:00:00.2684313

pi@raspberrypi:~/tmp $ out/tmp
Hello World!
Duration to schedule 100000 async tasks: 00:00:00.2351646
```

Besides Ubuntu, 18.04 I tried other images as well. Here is what I found:

- Debian 10 Slim image works similarly as Ubuntu 18.04, the size is about 3 MB larger.
- Default Alpine image doesn't have glibc, which is required by the bootstrapper. The packaging works but the image
  doesn't run even the runtime identifier is set to Alpine specifically.
- Google image `gcr.io/distroless/dotnet` works, but the base image is 134 MB already since it ships the entire runtime.
- The base image `gcr.io/distroless/base` has glibc, the base  image is only 13 MB (Ubuntu is 45.8 MB). However, I
  didn't figure out how to fix image build problem. It seems missing `/bin/sh` is problematic.
- The base image of busybox with glibc is only 2.68 MB. Seems promising, but it doesn't have required libs
  arm-linux-gnueabihf (both at /lib and /usr/lib). I guess it can be resolved by copying some files but in real work
  this would be unmaintainable.

By the way, other than new apps many things haven't changed much on Linux, for instance [font
rendering](https://pandasauce.org/post/linux-fonts/) is still miserable and requires heavy modification. Practically WSL
seems to be more productive from development perspective.
