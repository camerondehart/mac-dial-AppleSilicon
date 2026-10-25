# Security Policy

## Supported versions

| Version | Supported |
|---|---|
| 2.x | ✅ |
| < 2.0 | ❌ |

Only the latest release gets security fixes.

## Reporting a vulnerability

Please **don't open a public issue** for security problems.

Report them privately through GitHub instead: go to the **Security** tab of this repository and click **Report a vulnerability**. Include what you found, how to reproduce it, and which macOS version you're on.

You should get a reply within a week. If the report is confirmed, a fix will go out in a new release and you'll be credited, unless you'd rather not be.

## What the app can access

Mac Dial asks for these permissions, and only uses them for the dial:

- **Accessibility**: to send the scroll, click, and keyboard events you set up for the dial.
- **Input Monitoring** (only if macOS asks): to read input from the Surface Dial over Bluetooth.

Mac Dial makes **no network connections**, collects no data, and has no analytics or auto-updater. Your settings are stored locally in `UserDefaults`.

## Verifying a download

Release builds are ad-hoc signed, not notarized, because the project has no paid Apple Developer account. If you'd rather not trust a prebuilt binary, build it yourself from source with `./build.sh` (see the README). It only needs Apple's free Command Line Tools.
