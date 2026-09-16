# Privacy

PowerTools AI is a local-first Mac app. Its utilities run on your Mac. Its AI
runs on your Mac when your Mac supports it. Anything that leaves your Mac goes
only where you send it — never to a PowerTools AI server, because there isn't
one.

This policy applies to PowerTools AI from its first public release. AI text
actions — rewrite, shorten, proofread, summarise, translate — are in the
Command Bar, working with a provider you install and connect yourself. Until
you install the feature and choose a provider, the app makes no AI requests
of any kind.

## The short version

- **No account.** There is nothing to sign up for.
- **No servers.** PowerTools AI runs no service that receives your data.
- **No telemetry.** No usage statistics, crash reports, analytics, advertising,
  tracking or device identifiers.
- **No selling or sharing** of anything about you.
- **AI is off until you turn it on.** On a Mac that supports it, AI runs on
  device. Cloud AI uses a provider and API key you choose, and you see what will
  be sent before it is sent.
- **Your settings stay on your Mac.** Settings exports never include API keys.

## What stays on your Mac

Everything the app shows you — CPU, GPU and memory load, temperatures, battery
details, network rates, the window list, per-app volume, files on the Shelf — is
read through macOS and shown on your Mac. None of it is sent anywhere.

- **Clipboard history**, including copied images and files, is kept in the
  app's local storage. Automatic clearing only empties the system clipboard;
  it does not touch saved history.
- **Copy text from screen** recognises text on device with Apple's Vision
  framework. The temporary capture is deleted as soon as the text is read.
- **Recent captures** keeps up to 12 screenshots, within 256 MB, in a private
  local cache. Recordings are not copied; only their location and a small
  thumbnail are kept. A screenshot copied as a file keeps a private PNG briefly
  so other apps can read it, removed once it is older than 24 hours or when the
  cache fills.
- **Scratchpad notes, snippets and Shelf items** are stored locally.
- **Permissions** such as Accessibility, Screen Recording or Microphone are used
  only by the feature that asked for them. See [permissions](PERMISSIONS.md).

## AI

### Off until you turn it on

AI features are installed and switched on by you. Until then they load no
model, make no connection and use no energy.

### On this Mac

On macOS 26 or later, with Apple Intelligence switched on, PowerTools AI can
use Apple's on-device model through Apple's Foundation Models framework. These
requests are processed on your Mac, and PowerTools AI makes no network
connection for them. macOS, not PowerTools AI, downloads and updates the model
under Apple's terms.

The optional setup suggestion during onboarding (macOS 26 or later) processes the
sentence you type on device, uses it only to suggest features, and does not keep
it after setup.

### With a cloud provider you connect

On macOS 14 or later you can connect a cloud AI provider, such as DeepSeek,
OpenAI, Anthropic or another compatible service.

- **Your key, your account.** You supply your own API key. It is stored in the
  macOS Keychain and sent only to that provider, to authenticate your requests.
  It never appears in settings, exports or logs. The provider bills your account
  directly.
- **Direct connection.** Requests go from your Mac to the provider over HTTPS.
  PowerTools AI has no server in between.
- **Only what you chose.** A request contains the content you selected for it —
  such as highlighted text — and the instructions PowerTools AI adds to describe
  the task. When an AI plan is involved, it also includes the names of the
  actions it may propose. No account details, device identifiers or other
  content are added.
- **You see it first.** Before the first request that sends a kind of content
  (selected text, a clipboard item, a screenshot, a file), PowerTools AI shows
  exactly what will be sent and to which provider.
- **The provider's terms apply.** Retention, logging and model training for your
  requests are governed by the provider you chose. Settings links to its
  privacy policy and shows the address requests are sent to.

### With a model server on this Mac

You can use a model server running on your own Mac, such as Ollama or LM Studio.
PowerTools AI accepts only a local (loopback) address, so these requests do not
leave your Mac.

### What AI never reads on its own

AI never reads your clipboard history, screen, recordings, microphone, camera,
files, window titles or contents, browser content, installed apps or usage
history unless you choose that content for a request.

Content is treated as data, not instructions. Text inside a clipboard item,
file, screenshot or webpage cannot make AI take an action.

### What AI can do

- **Answers and drafts** are shown to you. Nothing is replaced or sent until you
  choose to.
- **Command Bar text actions** (rewrite, shorten, proofread, summarise,
  translate) show their answer in a small panel with Copy and Replace.
  Nothing is copied or replaces your selection until you press one of those
  buttons; pressing Escape or clicking away closes the panel and does nothing
  else.
- **Actions**, such as arranging windows or starting a timer, are proposed as a
  plan. Nothing runs until you approve it.
- **Anything that deletes, shares, installs or leaves your Mac** asks for your
  approval of that specific item, separately.
- AI never grants itself a macOS permission and never works around one.

### AI history

PowerTools AI does not collect your prompts or responses, and does not train any
model. If you turn on the AI activity log, it is stored only on your Mac, never
contains API keys, and can be cleared at any time.

## Network connections

This is the complete list. Each connection belongs to a feature you can see.

1. **Update check — automatic, and you can turn it off.** The app asks GitHub's
   releases API at `api.github.com` whether a newer PowerTools AI release
   exists, a short while after launch and occasionally while open. The request
   carries only the app's name and version. Turn it off in Settings › About. If
   you install an update, the disk image downloads from GitHub.

2. **Speed test — only when you start one.** The network speed test measures
   latency and throughput against `speed.cloudflare.com`.

3. **Homebrew manager — only when you use it.** Searching, installing and
   removing packages runs your local `brew` command, which contacts Homebrew,
   GitHub and package hosts. Popularity badges use Homebrew's public analytics
   from `formulae.brew.sh`. The Homebrew install command the app offers
   downloads Homebrew's official installer from `raw.githubusercontent.com` when
   run. PowerTools AI never captures passwords or runs `brew` as root.

4. **App updates — only when switched on.** Checking which apps are out of date
   uses the sources you leave enabled, each with its own switch:
   - *Homebrew* runs your local `brew` command, as above.
   - *App Store* sends store identifiers, or bundle identifiers as a fallback,
     and your region to `uclient-api.itunes.apple.com` or `itunes.apple.com`.
   - *Online* requests the update addresses that installed apps declare, on the
     developer's server or release host such as `github.com`. That server sees
     your IP address and the address requested, which can reveal which app is
     being checked. It also downloads Homebrew's public app catalog from
     `formulae.brew.sh`, which sends nothing about your apps.

   Checks run when you open the list, press Check now, or on a schedule you set.

5. **Website icons in the Radial Menu — only when you ask.** Fetching the icon
   for a website link requests that site's `/favicon.ico`, with a small size
   limit. The site sees your IP address.

6. **AI providers — only when you connect one and make a request.** Requests go
   to the provider address shown in Settings, as described in
   [With a cloud provider you connect](#with-a-cloud-provider-you-connect).

Apple's on-device model and model servers on your own Mac make no connection
beyond your Mac.

## Sharing and feedback

PowerTools AI runs no sharing or feedback service. The app never uploads your
screenshots, recordings or feedback. When you use the macOS share menu, the app
or service you pick handles the item under its own terms.

## Security

To report a security problem privately, see [SECURITY.md](../SECURITY.md).

## Changes to this policy

This page changes in the same update as the behaviour it describes. Its history
is in the project repository.

## Questions

Open an issue in the project repository.
