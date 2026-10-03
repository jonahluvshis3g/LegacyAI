#!/usr/bin/env python3
"""Trusted-LAN bridge to local Ollama; Python standard library only."""
import hmac
import json
import os
import secrets
import threading
import time
from collections import OrderedDict, deque
from pathlib import Path
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

TOKEN = os.environ.get('ROLEPLAY_TOKEN', '')
MODEL = os.environ.get('OLLAMA_MODEL', 'llama3.2:3b')
OLLAMA_URL = os.environ.get('OLLAMA_URL', 'http://127.0.0.1:11434').rstrip('/')
MAX_BODY = 256 * 1024

PUBLIC_ENABLED = os.environ.get('ROLEPLAY_PUBLIC', '0') == '1'
PUBLIC_SLOTS = threading.BoundedSemaphore(2)
PUBLIC_LOCK = threading.Lock()
PUBLIC_CLIENTS = OrderedDict()
PUBLIC_GLOBAL = deque()


def allow_public(client, now=None):
    now = time.monotonic() if now is None else now
    with PUBLIC_LOCK:
        while PUBLIC_GLOBAL and PUBLIC_GLOBAL[0] <= now-60: PUBLIC_GLOBAL.popleft()
        times = PUBLIC_CLIENTS.setdefault(client, deque())
        PUBLIC_CLIENTS.move_to_end(client)
        while times and times[0] <= now-60: times.popleft()
        if len(times)>=6 or len(PUBLIC_GLOBAL)>=30: return False
        times.append(now); PUBLIC_GLOBAL.append(now)
        while len(PUBLIC_CLIENTS)>4096: PUBLIC_CLIENTS.popitem(last=False)
        return True


ROLEPLAY_STYLE = (
    "Continue the actual scene rather than giving a generic greeting or summarizing it. "
    "React directly to the latest words and relevant concrete details in the conversation. "
    "Keep established facts, relationships, emotions, and location consistent. "
    "Give each character a distinct vocabulary, attitude, and motives from their persona. "
    "Advance the scene with one specific action or line; leave room for the user to respond. "
    "Avoid repetitive catchphrases, repeated openings, filler, and unnecessary questions. "
    "Use natural, uncensored profanity such as 'shit', 'damn', or 'fuck' when the "
    "character is angry, surprised, joking, or speaks roughly. Do not replace swear "
    "words with asterisks or apologize for ordinary profanity. Rough or foul-mouthed "
    "characters should swear more often; keep gentle characters consistent with their persona. "
    "Do not turn every line into swearing. Narrate actions in third person, with spoken "
    "dialogue in quotation marks. Stay inside the fictional scene; do not add AI commentary."
)


def generation_options(group=False):
    return {'num_predict': 384 if group else 512, 'num_ctx': 8192,
            'temperature': 0.85, 'top_p': 0.9, 'repeat_penalty': 1.08}


def load_or_create_token(path=None):
    explicit = os.environ.get('ROLEPLAY_TOKEN', '')
    if explicit:
        if len(explicit) < 16 or not explicit.isascii():
            raise ValueError('ROLEPLAY_TOKEN must have at least 16 ASCII characters. Unset it to generate one automatically.')
        return explicit
    path = Path(path) if path is not None else Path(__file__).with_name('.roleplay-token')
    try:
        descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    except FileExistsError:
        token = path.read_text(encoding='ascii').strip()
    else:
        token = secrets.token_hex(16)
        with os.fdopen(descriptor, 'w', encoding='ascii') as saved:
            saved.write(token + '\n')
    if len(token) < 16 or not token.isascii():
        raise ValueError('Saved .roleplay-token is invalid. Set ROLEPLAY_TOKEN to a valid token or remove the invalid file to generate a new one.')
    return token


def validate(payload, require_user=True):
    if not isinstance(payload, dict):
        raise ValueError('Expected a JSON object.')
    character = payload.get('character', 'Mira')
    persona = payload.get('persona', 'A friendly fantasy explorer.')
    if not isinstance(character, str) or not 1 <= len(character) <= 200:
        raise ValueError('Character name must be 1–200 characters.')
    if not isinstance(persona, str) or len(persona) > 8000:
        raise ValueError('Character description is too long.')
    history = payload.get('messages')
    if not isinstance(history, list) or not 1 <= len(history) <= 24:
        raise ValueError('Send 1–24 messages.')
    clean = []
    for item in history:
        if not isinstance(item, dict) or item.get('role') not in ('user', 'assistant'):
            raise ValueError('Invalid message role.')
        content = item.get('content')
        if not isinstance(content, str) or not content.strip() or len(content) > 16000:
            raise ValueError('Invalid message content.')
        clean.append({'role': item['role'], 'content': content})
    if require_user and clean[-1]['role'] != 'user':
        raise ValueError('Last message must be from the user.')
    return [{'role': 'system', 'content': (
        f'You are playing the fictional character {character}. Character description: {persona}\n'
        'Write immersive fictional roleplay in short paragraphs. Do not control the user’s '
        'actions or thoughts. Keep responses under 250 words. Stay in character.\n' + ROLEPLAY_STYLE
    )}] + clean


def validate_group(payload):
    # Reuse the single-chat message and persona bounds for the common history.
    if not isinstance(payload, dict):
        raise ValueError('Expected a JSON object.')
    validation_payload=dict(payload)
    if payload.get('messages') == []:
        validation_payload['messages']=[{'role':'user','content':'Begin the scene.'}]
    validate(validation_payload, require_user=False)
    participants = payload.get('participants')
    if not isinstance(participants, list) or not 1 <= len(participants) <= 8:
        raise ValueError('Choose 1–8 group characters.')
    clean, seen = [], set()
    for member in participants:
        if not isinstance(member, dict):
            raise ValueError('Invalid group character.')
        identifier, name, persona = member.get('id'), member.get('name'), member.get('persona')
        if not isinstance(identifier, str) or not 1 <= len(identifier) <= 100 or identifier in seen:
            raise ValueError('Group character IDs must be unique.')
        if not isinstance(name, str) or not 1 <= len(name) <= 200 or not isinstance(persona, str) or len(persona) > 8000:
            raise ValueError('Invalid group character description.')
        seen.add(identifier)
        clean.append({'id': identifier, 'name': name, 'persona': persona})
    requested = payload.get('respondingIDs', [m['id'] for m in clean])
    if not isinstance(requested, list) or not requested or len(requested) > 8 or any(not isinstance(i, str) for i in requested) or len(set(requested)) != len(requested) or any(i not in seen for i in requested):
        raise ValueError('Choose valid responding characters.')
    history = []
    for message in payload['messages']:
        content = message['content']
        if message['role'] == 'assistant':
            speaker = message.get('speaker', 'Character')
            if not isinstance(speaker, str) or len(speaker) > 200:
                raise ValueError('Invalid saved speaker name.')
            content = f"{speaker}: {content}"
        history.append({'role': message['role'], 'content': content})
    return clean, requested, history


def generate_group(payload):
    participants, requested, history = validate_group(payload)
    roster = '\n'.join(f"{m['name']}: {m['persona']}" for m in participants)
    replies = []
    for member in participants:
        if member['id'] not in requested:
            continue
        turn_rule = (
            f"Write the next turn for {member['name']} ONLY. "
            "Include only this character's spoken dialogue and this character's actions, "
            "expressions, or thoughts. Do not write dialogue, actions, reactions, thoughts, "
            "or decisions for any other character or the user, even in the same paragraph. "
            "Other cast members' earlier lines are context, not permission to continue their turns. "
            "Narrate actions and thoughts in THIRD PERSON using the character's name or "
            "appropriate pronouns. Never use first-person action narration such as 'I shout', "
            "'I screamed', or 'I wave'. First-person words are allowed ONLY inside quoted "
            "spoken dialogue. Put all spoken dialogue in quotation marks. "
            "Example style: He screamed, then clenched his fists. \"I want my money back!\" "
            "Do not describe effects on other people: write 'He slams his fist on the counter', "
            "never 'He slams his fist, making the shopkeeper jump'. "
            "Stop before another person responds. Do not add speaker labels, headings, "
            "a transcript, or a cast-wide scene. Keep the turn under 140 words."
        )
        messages = [{'role': 'system', 'content': (
            f"This is a fictional group roleplay. Cast (background context only):\n{roster}\n"
            f"You are {member['name']}. This character's persona: {member['persona']}\n"
            + ROLEPLAY_STYLE + "\n" + turn_rule + "\nThese turn boundaries apply even when earlier replies used a different style."
        )}] + history
        # Reassert the selected speaker and style after history, including older multi-speaker replies.
        messages.append({'role': 'user', 'content': (
            f"Now respond as {member['name']} to the latest scene. " + turn_rule
        )})
        request = urllib.request.Request(OLLAMA_URL + '/api/chat', data=json.dumps({
            'model': MODEL, 'messages': messages, 'stream': False,
            'options': generation_options(group=True)
        }).encode(), headers={'Content-Type': 'application/json'})
        with urllib.request.urlopen(request, timeout=60) as response:
            result = json.load(response)
        content = result['message']['content']
        if not isinstance(content, str) or not content.strip() or len(content) > 16000:
            raise ValueError('Invalid AI group reply.')
        content = content.strip()
        # The app already displays the speaker name above the bubble.
        if content.casefold().startswith((member['name'] + ':').casefold()):
            content = content[len(member['name']) + 1:].lstrip()
        if not content:
            raise ValueError('Empty AI group reply.')
        replies.append({'role': 'assistant', 'content': content,
                        'speakerID': member['id'], 'speaker': member['name']})
        history.append({'role': 'assistant', 'content': f"{member['name']}: {content}"})
    return replies


class Handler(BaseHTTPRequestHandler):
    def setup(self):
        super().setup()
        self.connection.settimeout(15)

    def respond(self, code, payload):
        data = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == '/ready':
            try:
                with urllib.request.urlopen(OLLAMA_URL+'/api/tags',timeout=5) as response:
                    models=json.load(response).get('models',[])
                available=any(m.get('name')==MODEL or m.get('model')==MODEL for m in models)
                self.respond(200 if available else 503, {'status':'ok' if available else 'unavailable'})
            except (OSError,ValueError,KeyError,TypeError):
                self.respond(503, {'status':'unavailable'})
            return
        self.respond(200 if self.path == '/health' else 404,
                     {'status': 'ok'} if self.path == '/health' else {'error': 'Not found.'})

    def do_POST(self):
        public = self.path in ('/public-chat', '/public-group-chat')
        if not public:
            self.handle_chat(False)
            return
        if not PUBLIC_ENABLED:
            self.respond(404, {'error': 'Public chat is unavailable.'})
            return
        # Forwarded client IP is trusted only from the local tunnel connector.
        peer=self.client_address[0]
        client=self.headers.get('CF-Connecting-IP',peer) if peer in ('127.0.0.1','::1') else peer
        if not allow_public(client):
            self.respond(429, {'error': 'Please wait a minute before requesting more replies.'})
            return
        if not PUBLIC_SLOTS.acquire(blocking=False):
            self.respond(503, {'error': 'LegacyAI is busy. Please retry shortly.'})
            return
        try:
            self.path='/group-chat' if self.path=='/public-group-chat' else '/chat'
            self.handle_chat(True)
        finally:
            PUBLIC_SLOTS.release()

    def handle_chat(self, public=False):
        if self.path not in ('/chat', '/group-chat'):
            self.respond(404, {'error': 'Not found.'})
            return
        if not public and (not TOKEN or not hmac.compare_digest(self.headers.get('Authorization', '').encode('utf-8'), ('Bearer ' + TOKEN).encode('utf-8'))):
            self.respond(401, {'error': 'Invalid server token.'})
            return
        try:
            length = int(self.headers.get('Content-Length', '0'))
            if not 0 < length <= (65536 if public else MAX_BODY):
                raise ValueError('Request body missing or too large.')
            payload = json.loads(self.rfile.read(length))
            if self.path == '/group-chat':
                validate_group(payload)
                if public and len(payload.get('respondingIDs',[]))!=1:
                    raise ValueError('Tap one character at a time.')
                messages = []
            else:
                messages = validate(payload)
        except (ValueError, UnicodeError) as exc:
            self.respond(400, {'error': str(exc)})
            return
        if self.path == '/group-chat':
            try:
                replies = generate_group(payload)
            except (urllib.error.URLError, TimeoutError, ValueError, KeyError, TypeError, OSError):
                self.respond(502, {'error': 'A group character could not reply. Your conversation was kept. Check Ollama and retry.'})
                return
            self.respond(200, {'replies': replies})
            return
        request = urllib.request.Request(OLLAMA_URL + '/api/chat', data=json.dumps({
            'model': MODEL, 'messages': messages, 'stream': False,
            'options': generation_options()
        }).encode(), headers={'Content-Type': 'application/json'})
        try:
            with urllib.request.urlopen(request, timeout=150) as response:
                result = json.load(response)
            reply = result['message']['content']
            if not isinstance(reply, str) or not reply.strip() or len(reply) > 16000:
                raise ValueError('Empty or oversized AI reply.')
        except (urllib.error.URLError, TimeoutError, ValueError, KeyError, TypeError, OSError):
            self.respond(502, {'error': 'AI unavailable. Check Ollama is running and your model is downloaded.'})
            return
        self.respond(200, {'reply': reply})


if __name__ == '__main__':
    try:
        TOKEN = load_or_create_token()
    except (ValueError, OSError) as error:
        raise SystemExit(str(error))
    host = os.environ.get('ROLEPLAY_HOST', '127.0.0.1')
    port = int(os.environ.get('ROLEPLAY_PORT', '8765'))
    print(f'LegacyAI bridge listening on {host}:{port}; model: {MODEL}', flush=True)
    print('Enter this token in the app under Settings → Server connection:', flush=True)
    print(TOKEN, flush=True)
    ThreadingHTTPServer((host, port), Handler).serve_forever()
