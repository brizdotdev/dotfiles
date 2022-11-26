# Setup .NET Framework tooling

1. Install Visual Studio and Build Tools

    ```powershell
    winget search "Visual Studio"
    ```

1. Install NuGet

    ```powershell
    winget install Microsoft.NuGet
    ```

1. Install IIS from the Windows Optional Features
1. Install [IIS Rewrite Module](https://www.iis.net/downloads/microsoft/url-rewrite)
1. Add MSBuild and NuGet to path