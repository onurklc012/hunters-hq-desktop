# Hunters HQ for Windows

Desktop app for the members of the **101st Hunter Squadron**, a DCS World virtual flying club (https://101huntersqn.com).
It opens the squadron's web panel, **Hunters HQ** (https://hq.101huntersqn.com), as a normal Windows program
instead of a browser tab. HQ provides text channels, voice and video rooms, screen sharing, events and pilot records.

**Download:** [latest release](../../releases/latest) (`HuntersHQ-Setup.exe`, Windows 10/11 64-bit, no admin rights needed).
To use HQ you need a squadron account; apply on https://101huntersqn.com.

## What it does

- Opens `https://hq.101huntersqn.com/` in its own window with its own icon and taskbar button.
  It uses the Microsoft Edge WebView2 engine that ships with Windows.
- Stays signed in and remembers the window size and position. Only one copy runs at a time.
- **Locked to HQ.** The window only shows `hq.101huntersqn.com` and `101huntersqn.com`, plus Discord's sign-in pages
  if HQ's "Login with Discord" is used. Any other link, redirect or popup opens in your default browser (http/https only).
- **Microphone, camera and notifications** are allowed without asking each time, for HQ's own origin only.
  Every other site is denied. Screen sharing shows Windows' "choose what to share" picker every time.
- There are no developer tools and no browser menus. The right-click menu only offers cut, copy, paste and select all.
- If the WebView2 Runtime is missing, the app and the installer offer Microsoft's official download.
  The app never falls back to the old Internet Explorer engine.

## Install and uninstall

Run `HuntersHQ-Setup.exe`. It installs for the current user only, into `%LOCALAPPDATA%\Programs\Hunters HQ`,
with Start menu and optional desktop shortcuts. For a silent install, use `HuntersHQ-Setup.exe /VERYSILENT`.
To uninstall, go to **Settings → Apps → Installed apps → Hunters HQ → Uninstall**. The uninstaller asks whether to
also delete the saved sign-in and window settings in `%LOCALAPPDATA%\HuntersHQ`.

## Privacy

The app itself collects nothing and sends nothing anywhere. It is a window onto Hunters HQ.
- It connects only to the addresses you open in it: Hunters HQ and the squadron website.
  What you do there falls under the squadron's [privacy policy](https://101huntersqn.com/privacy).
- Links to any other site open in your own browser.
- The page content is shown by Microsoft Edge WebView2, a Windows component. Microsoft's handling of WebView2
  diagnostic data follows your Windows settings and the
  [Microsoft Privacy Statement](https://privacy.microsoft.com/privacystatement).

This program will not transfer any information to other networked systems unless specifically requested by the user
or the person installing or operating it.

## Code signing policy

Free code signing provided by [SignPath.io](https://about.signpath.io), certificate by [SignPath Foundation](https://signpath.org).

Release builds are built from this repository by the [release workflow](.github/workflows/release.yml) on
GitHub-hosted runners and signed through SignPath. Every signing request is approved by hand.

| Role | Members |
| --- | --- |
| Committers and reviewers | [@onurklc012](https://github.com/onurklc012) |
| Approvers | [@onurklc012](https://github.com/onurklc012) |

All team members use multi-factor authentication for GitHub and SignPath.
Changes from anyone outside the team (pull requests) are reviewed by a committer before they are merged.

## Build from source

Requirements: Windows, Python 3.12, and Inno Setup 6 (`winget install JRSoftware.InnoSetup`).

```
powershell -ExecutionPolicy Bypass -File build.ps1 -Version 1.0.0
```

The result is `out\HuntersHQ-Setup.exe`. `VERSION` in `hunters_hq.py` must match `-Version`.
To run from source with dev tools, use `out\build\venv\Scripts\python.exe hunters_hq.py --debug`.
`--debug` only works from source, never in the built exe.

Release: bump `VERSION`, commit, then push a tag `vX.Y.Z`. The workflow builds, signs and publishes the release.

## License

[MIT](LICENSE). The squadron's name and emblem are not covered by the license.
Third-party components keep their own licenses: [pywebview](https://github.com/r0x0r/pywebview) (BSD-3-Clause),
including the Microsoft WebView2 SDK interop DLLs (BSD-3-Clause), [pythonnet](https://github.com/pythonnet/pythonnet) (MIT),
Python (PSF), [PyInstaller](https://pyinstaller.org) (GPL with bootloader exception), and
[Inno Setup](https://jrsoftware.org/isinfo.php) (Inno Setup License).

---

### Türkçe

101st Hunter Squadron üyeleri için Hunters HQ'nun Windows uygulamasıdır. [Son sürümden](../../releases/latest)
`HuntersHQ-Setup.exe` dosyasını indirip çalıştırın; yönetici izni gerekmez. Uygulama yalnızca hq.101huntersqn.com'u açar.
Başka bağlantılar tarayıcınızda açılır. Mikrofon ve kamera izni yalnızca HQ için verilir.
Kaldırmak için: Ayarlar → Uygulamalar → Hunters HQ → Kaldır.
