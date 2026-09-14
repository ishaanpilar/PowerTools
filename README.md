<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/assets/readme/logo-dark.svg">
    <img src="docs/assets/readme/logo.svg" width="220" alt="PowerTools AI logo">
  </picture>
</p>

<h1 align="center">PowerTools AI</h1>

<p align="center">
  The Mac utilities I wished macOS had, in one menu bar app, with AI built in.<br>
  Free and open source. No account, no registration, no sign-in.
</p>

<p align="center">
  <a href="#why-i-built-this">Story</a> ·
  <a href="#my-apps-inside-powertools-ai">My apps</a> ·
  <a href="#what-it-does">Features</a> ·
  <a href="#ai-built-in">AI</a> ·
  <a href="#private-by-default">Privacy</a> ·
  <a href="#install">Install</a> ·
  <a href="#build-it">Build</a> ·
  <a href="#credits">Credits</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B%20Apple%20Silicon-black" alt="macOS 14 and newer, Apple Silicon">
  <img src="https://img.shields.io/badge/on--device%20AI-macOS%2026%2B-4c8dff" alt="On-device AI on macOS 26 and newer">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0--or--later-blue" alt="License GPL 3.0 or later"></a>
</p>

<!-- Screenshots: capture them to the shot list in docs/AI-PRODUCT-ROADMAP.md (milestone M0), then add them here. -->

## Why I built this

When I switched from Windows to macOS, I kept hitting roadblocks: small things
Windows simply did better. Every time I hit one, I built a tool to get past it —
apps like CloseQuit, MacTelemetry and CopyWatch. Over time those tools became a
collection of apps that made my Mac work the way I wanted.

On that journey I came across [Vorssaint](https://github.com/vorssaint/vorssaint-utils),
an amazing open-source Mac utility. Its greatest strength is that it asks nothing
of you: it runs as a standalone app, with no account, no registration and no
identity attached. That same simplicity is also its limit. It has no AI-native
features, and it lacked some things that mattered to me personally.

I believe a little AI in the right places makes software like this far more
powerful — at least for the way I work. So I built PowerTools AI as my personal
tool: my own apps and Vorssaint's tools, combined in one app, with AI built in.
It still has no account, no registration and no sign-in.

## My apps inside PowerTools AI

Before PowerTools AI, I built these as separate Mac apps. What they do now lives
here, in one place.

| App | What it does on its own | In PowerTools AI |
| --- | --- | --- |
| [CloseQuit](https://github.com/ishaanpilar/CloseQuit) | Quits an app when you close its last window, as a tiny background app with no interface | Quit on close |
| [MacTelemetry](https://github.com/ishaanpilar/MacTelemetry) | A menu bar monitor for thermal pressure, CPU and memory with live graphs | Thermal pressure, the throttling alert, the temperature sensor list and the dashboard cards |
| [CopyWatch](https://github.com/ishaanpilar/CopyWatch) | Verified, resumable file backups for filmmakers: checksummed copy jobs, Finder-copy rescue, folder compare and iPhone backup | Coming to PowerTools AI |

More of my tools are on [my GitHub](https://github.com/ishaanpilar).

## Where it stands

PowerTools AI is in active development. The first beta is out.

- **Works today:** every utility below. [Download the beta](#install) or
  [build it](#build-it).
- **Being built:** the AI features. The [roadmap](docs/AI-PRODUCT-ROADMAP.md)
  tracks progress.

## What it does

Nobody needs everything, so the Features page installs and uninstalls whole
features. An uninstalled feature stops loading and uses no CPU, memory or
energy; install it again and your settings come back. First launch offers three
bundles — Essentials, Windows, and Battery and quiet — or a picker for choosing
features one by one, and asks only for the permissions your choices need.

### Sound

- Per-app volume, including boosting a quiet app past 100%
- Per-app output: music on speakers, a call on your headset
- One-shortcut output switching, and lower volume when headphones disconnect
- Pin a preferred microphone, or mute every microphone at once
- Stop the Music app opening when headphones connect

### Know what your Mac is doing

- CPU, GPU, memory, swap and temperatures with history graphs
- Battery health, cycle count and power draw, plus optional Fan Control (beta)
- Readings in the menu bar, live network rates and a speed test
- Alerts for sustained load, heat, memory pressure, low disk and low battery

### Windows and the Dock

- An app switcher with live window thumbnails and search
- Window layouts: halves, thirds, sixths, corners, other displays, edge snapping
  and modifier-drag to move or resize
- Window previews when hovering Dock icons, and Dock click actions
- Maximize without a new Space, quit apps when their last window closes, and
  protection against accidental ⌘Q and ⌘W

### Keyboard and mouse

- Text snippets with clipboard, date and time variables
- Smooth scrolling, separate scroll directions for mouse and trackpad, and
  pointer acceleration control
- Side buttons that work, custom mouse button shortcuts, and three-finger middle
  click
- Filters for the double clicks and double letters worn hardware invents
- A Super key, and one page for every shortcut

### Clipboard, files and links

- Clipboard history with pins, search, plain-text paste and automatic clearing
- A Shelf for parking files, text and links mid-drag
- Cut and paste files in Finder, rename with F2, paste images as PNG files
- Tracking parameters stripped from copied links
- One-click installs from disk images

### Everyday tools

- **Command Bar:** one field for app actions, apps, windows, menu commands,
  snippets, clipboard history, files, sums, conversions and dates
- Quick panel, one-click quick toggles and a radial menu around the pointer
- Screenshots with an editor, scrolling capture, redaction and pinned captures
- Screen recording with system audio and microphone, and an editor for trims,
  zooms, text and blur
- Text from any part of the screen, recognised on your Mac
- Color picker, camera preview and a floating Scratchpad
- App updates, Cleaner, Uninstaller, Homebrew manager and media tools
- Cleaning Mode, which locks the keyboard while you wipe it

### Energy and display

- Keep Awake with timers, rules and closed-lid support
- Brightness for built-in and external displays, and extra XDR brightness
- Bluetooth switched off while the Mac sleeps

The app is available in 13 languages. AI features start in English.

## AI built in

> The AI features are being built now. This describes how they work; the
> [roadmap](docs/AI-PRODUCT-ROADMAP.md) tracks progress.

| Where AI runs | Needs | What leaves your Mac |
| --- | --- | --- |
| On your Mac, with Apple's on-device model | macOS 26, Apple Intelligence on | Nothing |
| A model server on your Mac, such as Ollama or LM Studio | macOS 14 | Nothing |
| A cloud provider with your own API key, such as DeepSeek, OpenAI or Anthropic | macOS 14 | Only what you choose to send, shown to you first |

- **Off until you turn it on.**
- **Your key stays yours.** It lives in the macOS Keychain, the provider bills
  you directly, and no PowerTools AI server sits in between.
- **You see it before it is sent.** The first time a kind of content would go to
  a cloud provider, you see exactly what and where.
- **AI proposes, you decide.** Nothing runs until you approve it. Deleting,
  sharing or installing asks about that specific item.
- **Nothing in the background.** AI never reads your clipboard history, screen,
  files or microphone unless you pick them for a request.

What comes first:

1. **Text actions in the Command Bar:** rewrite, shorten, proofread, summarise
   and translate whatever text you have selected.
2. **AI inside the tools you use:** summaries and action items from Scratchpad
   notes and clipboard items, release-note summaries in App updates, a plain
   answer to "why is my Mac busy?", alt text for screenshots, and a setup
   assistant on first launch (macOS 26).
3. **Plans from a sentence:** ask the Command Bar to "set up a writing session"
   and get a step-by-step plan built from the app's own tools, run only after
   you approve it.

## Private by default

- No account, no servers, no telemetry, no analytics, no tracking.
- Your settings, clipboard history, notes and captures stay on your Mac.
- The network is used only by features you can see: update checks, the speed
  test, Homebrew, App updates, website icons you ask for, and AI providers you
  connect.

The full details are in the [privacy policy](docs/PRIVACY.md).

### Permissions

Every permission is optional. The app explains each one in plain words, shows
which features use it, and tells you when one you granted is no longer needed.

| Permission | Used by | Without it |
| --- | --- | --- |
| Accessibility | Switcher, Dock features, window controls, mouse and keyboard features, snippets, cut and paste | Those features stay off |
| Screen Recording | Window previews, screenshots, text from screen, screen recordings | Those captures stay unavailable |
| System Audio Recording | Per-app volume and output routing | Apps stay on normal system audio |
| Microphone | Optional voice track in screen recordings | Recordings continue without your voice |
| Notifications | Keep Awake, battery, monitor and update alerts | The app stays silent |
| Full Disk Access, optional | Deeper Cleaner and Uninstaller scans | Only reachable places are scanned |
| Administrator, once, optional | Closed-lid toggling without a password | A password prompt each time |

The Shelf and most quick toggles need no permission. Finder cut and paste, the
Uninstaller, emptying the Trash and the Homebrew terminal handoff ask macOS for
Automation access the first time they talk to Finder or Terminal. More in
[permissions](docs/PERMISSIONS.md).

## What you need

- A Mac with Apple Silicon
- macOS 14 Sonoma or later
- For on-device AI: macOS 26 with Apple Intelligence switched on

## Install

Download the latest `.dmg` from the
[releases page](https://github.com/ishaanpilar/PowerTools/releases), open it and
drag PowerTools to Applications.

Beta builds are not yet signed with an Apple Developer ID or notarized, so macOS
blocks the first launch:

1. Open PowerTools from Applications. When macOS says it cannot verify the app,
   click **Done**.
2. Open **System Settings › Privacy & Security**, scroll to **Security** and
   click **Open Anyway** next to PowerTools. Confirm, and it opens normally from
   then on.

## Build it

You need the Xcode Command Line Tools with the macOS 26 SDK.

```sh
git clone https://github.com/ishaanpilar/PowerTools.git
cd PowerTools
./build.sh            # build and assemble the app
./build.sh --install  # build, install into Applications and launch
```

Run `./Tools/setup-signing.sh` once so rebuilds keep the permissions you grant.
The [contributing guide](CONTRIBUTING.md) covers the rest.

## Uninstall

```sh
./Tools/uninstall.sh
```

It quits the app, removes its login item, resets its privacy permissions and
deletes its settings and caches.

## Documentation

- [Privacy](docs/PRIVACY.md) — what does and does not leave your Mac
- [Permissions](docs/PERMISSIONS.md) — every macOS permission in plain words
- [Troubleshooting](docs/TROUBLESHOOTING.md) — common fixes
- [AI roadmap](docs/AI-PRODUCT-ROADMAP.md) — what is being built, and in what order
- [AI harness](docs/AI-HARNESS.md) — the rules every AI feature follows
- [Contributing](CONTRIBUTING.md) and [agent guide](AGENTS.md)
- [Support](SUPPORT.md) and [security](SECURITY.md)

## Credits

PowerTools AI is built on [Vorssaint](https://github.com/vorssaint/vorssaint-utils),
an open-source macOS utility by Vorssaint and its contributors, released under
GPL-3.0-or-later. Many of the utilities in this app began there, and this app
would not exist without that work. Thank you.

It also brings together my own apps, listed in
[My apps inside PowerTools AI](#my-apps-inside-powertools-ai).

PowerTools AI is an independent project. It is not affiliated with or endorsed
by Vorssaint. Source files that came from Vorssaint keep their original
copyright notices, as the licence requires.

## License

[GPL-3.0-or-later](LICENSE). The licence covers the source code. The PowerTools
AI name, mark and icon are covered by [TRADEMARKS.md](TRADEMARKS.md).

<p align="center">
  <sub>Made by <a href="https://github.com/ishaanpilar">@ishaanpilar</a></sub>
</p>
