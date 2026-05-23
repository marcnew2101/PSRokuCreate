# PSRokuCreate

A PowerShell module that scaffolds new Roku channel projects with generated channel icons, a splash screen, a valid manifest, and one-command sideload to a developer-enabled Roku device.

```
 ____  ____  ____       _           ____                _
|  _ \/ ___||  _ \ ___ | | ___   _ / ___|_ __ ___  __ _| |_ ___
| |_) \___ \| |_) / _ \| |/ / | | | |   | '__/ _ \/ _` | __/ _ \
|  __/ ___) |  _ < (_) |   <| |_| | |___| | |  __/ (_| | ||  __/
|_|   |____/|_| \_\___/|_|\_\\__,_|\____|_|  \___|\__,_|\__\___|
```

## Requirements

- Windows 10 / 11
- Windows PowerShell 5.1 (ships with Windows; `pwsh` 7+ also works on Windows)
- A Roku device with developer mode enabled, reachable on the same network

## Quick start

Copy or clone this folder somewhere on disk, then from a PowerShell prompt:

```powershell
cd path\to\Roku
.\createRoku.ps1
```

If PowerShell refuses to run scripts ("execution of scripts is disabled on this system"):

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\createRoku.ps1
```

The wizard will:
1. Prompt for a project name.
2. Open a folder picker for the output location.
3. Scaffold a project with `manifest`, `source/`, `components/`, and `images/`.
4. Generate FHD and HD channel icons + an FHD splash screen using the project name as the overlay text.
5. Optionally side-load to a Roku on your network (discovery via SSDP, or enter an IP manually).

## What you get

A scaffolded project that mirrors Roku's standard channel layout:

```
MyProject/
+-- manifest
+-- source/
|   +-- main.brs
+-- components/
|   +-- appScene.xml
|   +-- appScene.brs
|   +-- screens/
|       +-- welcomeScreen.xml
|       +-- welcomeScreen.brs
+-- images/
|   +-- logos/logo.png
|   +-- icons/channel-icon_FHD.png    (generated)
|   +-- icons/channel-icon_HD.png     (generated)
|   +-- splash/splash-screen_FHD.png  (generated)
+-- fonts/
    +-- Comfortaa.ttf
    +-- LICENSE-FONT.txt
```

The `.brs` / `.xml` files are minimal but functional: `main.brs` opens an `AppScene` which mounts a `WelcomeScreen` on launch.

## Public functions

The createRoku wizard calls all four modules below. They're described here so you can also use them standalone - handy for re-running `Send-RokuApp` on each edit without re-scaffolding, or for scripting your own dev loop.

```powershell
Import-Module .\PSRokuCreate.psd1
Get-Help <FunctionName> -Full     # detailed help with parameters and examples
```

### New-RokuProject

Interactive wizard. The same flow `createRoku.ps1` invokes. No parameters.

### Find-RokuDevice

Discovers Roku devices on the local network via SSDP M-SEARCH. Sends from every active IPv4 interface so multi-NIC machines don't lose multicast to virtual adapters (Hyper-V, VPN, VMware).

```powershell
Find-RokuDevice
Find-RokuDevice -SearchTimeout 5
Find-RokuDevice | Get-RokuDeviceInfo
```

### Get-RokuDeviceInfo

Presents a list of devices with model name and developer-mode status by querying each device:

```
# Model                     IP Address     Developer Mode
- -----                     ------------   --------------
1 Ultra 4850X               192.168.1.10   Enabled
2 55R635 A113X              192.168.1.11   Enabled
```

### Send-RokuApp

Side-loads a project directory to a Roku. Zips the directory, POSTs to `http://<Device>/plugin_install` with HTTP Digest auth, and parses Roku's response.

```powershell
$pw = Read-Host -AsSecureString "Dev password"
Send-RokuApp -Device 192.168.1.10 -Password $pw -ProjectPath C:\path\to\MyProject
```

Returns a `[PSCustomObject]` with `Success` (bool), `Message` (parsed Roku response), and `RawResponse` (full HTML for debugging).

## How it works

**SSDP discovery** sends an M-SEARCH multicast to `239.255.255.250:1900` from each active IPv4 interface on the machine. Replies arrive unicast. The MX header is capped at 5 per UPnP spec - Roku silently ignores requests with `MX > 5`, even though the local listen deadline can be set longer via `-SearchTimeout`.

**Sideload** builds a `multipart/form-data` body by hand with quoted field names. .NET's `MultipartFormDataContent` produces unquoted names and an RFC 5987 `filename*` parameter that Roku's parser rejects with "mysubmit Field Not Found." The zip is also constructed manually with `System.IO.Compression.ZipArchive` so entries use forward slashes - `Compress-Archive` writes backslashes which Roku rejects with "Script directory '/source' does not exist in plugin."

**Developer-mode detection** parses the `<developer-enabled>` field in the ECP `/query/device-info` response. When disabled, the wizard prints the secret remote sequence (Home x3, Up x2, Right, Left, Right, Left, Right) and waits for the user to confirm enablement before re-querying.

## Customization

Rename `psrokucreate.json.example` to `psrokucreate.json` in the module folder, then edit it to override console colors and generated-image colors:

```powershell
Rename-Item .\psrokucreate.json.example psrokucreate.json
notepad .\psrokucreate.json
```

The `psrokucreate.json` file is gitignored, so your edits survive `git pull`. Any subset of keys works - unspecified keys keep their defaults. The module reads the file on import; restart your PowerShell session (or `Import-Module ... -Force`) after editing.

```json
{
  "Error":         "DarkRed",
  "Warning":       "DarkYellow",
  "Success":       "DarkGreen",
  "Info":          "Blue",
  "Neutral":       "White",
  "Heading":       "Magenta",
  "GradientStart": [10, 20, 80],
  "GradientEnd":   [40, 120, 200],
  "TextColor":     [255, 255, 255]
}
```

| Key | Type | Default | Used for |
|---|---|---|---|
| `Error` | `ConsoleColor` | `Red` | Invalid input, failures |
| `Warning` | `ConsoleColor` | `Yellow` | Recoverable issues, advisories |
| `Success` | `ConsoleColor` | `Green` | Successful sideload, positive results |
| `Info` | `ConsoleColor` | `Cyan` | Progress messages, prompts |
| `Neutral` | `ConsoleColor` | `White` | Plain text |
| `Heading` | `ConsoleColor` | `Yellow` | Banner, device-info table |
| `GradientStart` | `[R, G, B]` 0-255 | `[42, 8, 69]` | Top-left gradient color for icons, splash, and background |
| `GradientEnd` | `[R, G, B]` 0-255 | `[100, 65, 165]` | Bottom-right gradient color |
| `TextColor` | `[R, G, B]` 0-255 | `[255, 255, 255]` | Project-name overlay on icons and splash |

Console color values are any `[System.ConsoleColor]` name (`Red`, `DarkRed`, `Cyan`, etc.). Image colors are RGB byte triplets.

## Troubleshooting

**No Roku devices found.** Usually one of:
- Your computer is on a different network than the Roku (guest Wi-Fi, corporate VPN, hotel Wi-Fi).
- The network blocks multicast traffic.
- The Roku is powered off or not connected to any network.

**Incorrect developer password.** The wizard trims leading/trailing whitespace before sending. If you're certain the password is right, reset it by toggling developer mode off and on again (Home x3 Up x2 Right Left Right Left Right).

**Install Failure: "Script directory '/source' does not exist".** You're seeing this when calling `Send-RokuApp` with a zip you built outside this module. Roku requires forward-slash separators in zip entries; `Compress-Archive` uses backslashes. Use `System.IO.Compression.ZipArchive` directly (as `Send-RokuApp` does internally), or unzip and re-zip with a tool that uses forward slashes.

**Discovery returns nothing on a machine with multiple network adapters.** This module already handles multi-NIC machines by sending from every active interface. If it still fails, run `Find-RokuDevice -Verbose` to see which interfaces it tried.

## Project layout

```
Roku/
+-- createRoku.ps1                # entry point (3 lines)
+-- PSRokuCreate.psd1             # module manifest
+-- PSRokuCreate.psm1             # dot-source loader
+-- Public/                       # 4 exported functions
+-- Private/                      # 9 helpers + GradientRenderer.cs
+-- Templates/                    # project template files (includes LICENSE-FONT.txt)
+-- README.md
+-- LICENSE
```

The module follows the conventional PowerShell "one function per file" layout. `PSRokuCreate.psm1` dot-sources `Private/` first, then `Public/`, so public functions can call private helpers.

## Limitations

- **Windows only.** The module uses COM (`Shell.Application` folder picker), `gdi32.dll` (font registration), and `System.Drawing` (image generation). None of those are available on Linux/Mac PowerShell - the manifest declares `PowerShellVersion = '5.1'` to signal this.
- **Single channel template.** The scaffold produces one specific app shape (AppScene -> WelcomeScreen). To add variants, drop new templates under `Templates/` and parameterize the selection.
- **Generated channel art is a gradient with the project name in the "Honk" font.** See [Customization](#customization) to change the gradient and text colors; swap `Templates/fonts/Honk.ttf` for another `.ttf` to change typography.

## License

MIT - see [LICENSE](LICENSE) for details.
