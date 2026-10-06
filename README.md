<img width="1376" height="2817" alt="Frame 3" src="https://github.com/user-attachments/assets/ed949d52-56df-4c1f-ac0f-6d7666a0aaf2" />
LegacyAI
LegacyAI is an AI character chatbot for iOS 5 and iOS 6. Create custom characters, chat with them individually, or bring them together in group conversations.
Features include:
- Custom character personalities and avatars
- Individual and group chats
- Manual character turns—tap an avatar to choose who speaks
- Narrator mode to direct scenes without joining the conversation
- Read-aloud voices
- Message editing, deletion, and regeneration
- Chat and character transfers between devices
- IPA and DEB installation packages
Server
The default server address is https://ai.ios6.xyz.
The AI runs on a Mac using Ollama. A Cloudflare tunnel connects the public address to the local Python server on port 8765. The iOS app sends conversation context to the server and displays the generated replies.
The hosted service is available while the server’s Mac is awake and connected to the internet. You can also run your own compatible server and enter its address in the app’s settings.
