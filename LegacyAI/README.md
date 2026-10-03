# LegacyAI 3.0

One jailbreak ARMv7 build for iOS 5.0 and later: iPhone 3GS, 4, 4S, and 5. ARMv6 is unsupported. Install LegacyAI.deb or use the IPA with a compatible jailbreak installer; these are not Apple distribution signed.

Open the app and chat: https://ai.ios6.xyz is selected automatically. No server address or token setup is required. Settings → Custom server accepts an optional HTTP/HTTPS address; clear it to restore the default. A custom server must provide token-free /chat and /group-chat endpoints. The official public service uses /public-chat and /public-group-chat.

The build retains the iOS 6 bundle/package identity to preserve existing conversations. If that library is absent, the app imports character/group libraries and theme/voice settings from the earlier iOS 5 preference domain. The DEB replaces the older iOS 5 package; IPA users should avoid installing both builds simultaneously. Back up chats before upgrading.

Groups support eight members, four visible icons, horizontal scrolling, and manually selected speakers. Reply refresh keeps all other messages. Speech releases its audio session afterward to allow music to resume.

The public server is enabled with ROLEPLAY_PUBLIC=1. It allows six requests per client per minute, thirty total per minute, two simultaneous public requests, 64 KiB request bodies, and one speaker per group request. Private endpoints retain token authentication for older clients. Public limits apply per server process; this setup is intended for a small release, not an unlimited service.

The default server runs on the maintainer's Mac through Cloudflare. Keep the Mac awake with Ollama, the Python bridge, and the tunnel running. Public traffic uses the Mac's resources. The app stores conversation history locally and sends the most recent 24 messages plus character descriptions to the selected server for generation. No conversation database is maintained by the bridge.

Validation: ARMv7 build succeeded, iOS 5.0 minimum OS verified, IPA layout verified, 26 server tests and controller regressions passed, and the public HTTPS endpoint returned a live AI response without a token. Physical iOS 5/6 HTTPS, upgrade migration, photo picking, and audio behavior still require testing before broad distribution.
