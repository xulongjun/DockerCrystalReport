# Build application with Dotnet Framework 4.8 sdk as build stage
FROM mcr.microsoft.com/dotnet/framework/sdk:4.8 AS build
WORKDIR /app

COPY *.sln .
COPY CRdockerTest/. ./CRdockerTest/
RUN nuget restore
WORKDIR /app/CRdockerTest
RUN msbuild /p:Configuration=Release -r:False

# Write installation process and copy the site web to the IIS default folder as runtime stage
FROM mcr.microsoft.com/windows/servercore/iis AS runtime
# FROM mcr.microsoft.com/dotnet/framework/aspnet:4.8 AS runtime
# FROM mcr.microsoft.com/dotnet/framework/aspnet:4.8-windowsservercore-ltsc2019 AS runtime

################################################################################
# Preparation installations files
################################################################################
WORKDIR c:/temp

# Preparation installations files from storage account
# ADD https://saathfrshareddev.blob.core.windows.net/crystalReport-docker/INSTALL.zip c:/temp/INSTALL.zip
# RUN unzip INSTALL.zip

# Preparation installations files from repo Git

COPY Install/32/* . c:/temp/32/
COPY Install/64/* . c:/temp/64/
COPY Install/Add-Font.ps1 . 
COPY Install/Fonts/*.TTF c:/temp/Fonts/

# SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]
RUN powershell.exe c:/temp/Add-Font.ps1

################################################################################
# install features we need
################################################################################
RUN ["powershell.exe", "Install-WindowsFeature NET-Framework-45-ASPNET"]
RUN ["powershell.exe", "Install-WindowsFeature Web-Asp-Net45"]

# Download asp.net 4.8 and install. This section can be done with storage account too.
#RUN C:\temp\ndp48-x86-x64-allos-enu.exe /quiet /install
ADD https://go.microsoft.com/fwlink/?linkid=2088631 /ndp48-x86-x64-allos-enu.exe
RUN C:\ndp48-x86-x64-allos-enu.exe /quiet /install

##hack in oledlg dll so that Crystal Runtime will install
RUN powershell.exe Copy-Item "c:\temp\32\oledlg.dll" -Destination "C:\windows\system32"
RUN powershell.exe Copy-Item "c:\temp\64\oledlg.dll" -Destination "C:\windows\syswow64"

# # copy in Crystal MSI and install. Note it's 32bit and 64bit version
RUN powershell.exe Start-Process -FilePath 'c:\temp\32\CR13SP31MSI32_0-10010309.MSI' -ArgumentList '/quiet' -Wait
RUN powershell.exe Start-Process -FilePath 'c:\temp\64\CR13SP31MSI64_0-10010309.MSI' -ArgumentList '/quiet' -Wait

WORKDIR /inetpub/wwwroot
COPY --from=build /app/CRdockerTest/. ./

# Create the website, application pool etc.
RUN powershell.exe Remove-Website -Name 'Default Web Site'
RUN powershell.exe New-Website -Name 'web-cr' -Port 80 -PhysicalPath 'c:\inetpub\wwwroot\' -ApplicationPool '.NET v4.5'

# Delete the temporary folder
RUN powershell.exe Remove-Item -Force -Recurse -Path "c:\temp\*"

EXPOSE 80