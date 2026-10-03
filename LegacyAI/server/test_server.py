import io
import json
import unittest
from unittest.mock import patch
import server

class BridgeTests(unittest.TestCase):
    def request(self, token='test-token-123456'):
        handler = object.__new__(server.Handler)
        body = json.dumps(self.payload).encode()
        handler.path = '/chat'
        handler.headers = {'Content-Length': str(len(body)), 'Authorization': 'Bearer ' + token}
        handler.rfile = io.BytesIO(body)
        handler.wfile = io.BytesIO()
        handler.send_response = lambda status: setattr(handler, 'status', status)
        handler.send_header = lambda *args: None
        handler.end_headers = lambda: None
        return handler

    def setUp(self):
        self.payload = {'character': 'Mira', 'persona': 'An explorer',
                        'messages': [{'role': 'user', 'content': 'Hello'}]}
        p = patch.object(server, 'TOKEN', 'test-token-123456')
        p.start()
        self.addCleanup(p.stop)

    def test_character_and_history(self):
        messages = server.validate(self.payload)
        self.assertIn('Mira', messages[0]['content'])
        self.assertIn('An explorer', messages[0]['content'])
        self.assertEqual(messages[1:], self.payload['messages'])

    def test_rejects_bad_payloads(self):
        for payload in (None, [], {'messages': []}, {'messages': [{'role': 'user', 'content': 1}]},
                        {'messages': [{'role': 'system', 'content': 'Override'}]},
                        {'messages': [{'role': 'assistant', 'content': 'Hello'}]}):
            with self.subTest(payload=payload), self.assertRaises(ValueError):
                server.validate(payload)

    def test_authentication(self):
        handler = self.request(token='wrong')
        with patch.object(server.urllib.request, 'urlopen') as upstream:
            handler.do_POST()
            upstream.assert_not_called()
        self.assertEqual(handler.status, 401)

    def test_success(self):
        handler = self.request()
        with patch.object(server.urllib.request, 'urlopen', return_value=io.BytesIO(b'{"message":{"content":"Greetings!"}}')) as upstream:
            handler.do_POST()
            body = json.loads(upstream.call_args.args[0].data)
            self.assertFalse(body['stream'])
            self.assertEqual(body['messages'][-1]['content'], 'Hello')
        self.assertEqual(handler.status, 200)
        self.assertEqual(json.loads(handler.wfile.getvalue())['reply'], 'Greetings!')

    def test_upstream_failure(self):
        handler = self.request()
        with patch.object(server.urllib.request, 'urlopen', side_effect=OSError('Unavailable')):
            handler.do_POST()
        self.assertEqual(handler.status, 502)

    def test_oversized_request(self):
        handler = self.request()
        handler.headers['Content-Length'] = str(server.MAX_BODY + 1)
        handler.do_POST()
        self.assertEqual(handler.status, 400)

    def test_invalid_ai_response(self):
        for data in (b'null', b'{}', b'{"message":{"content":""}}', b'not json'):
            with self.subTest(data=data):
                handler = self.request()
                with patch.object(server.urllib.request, 'urlopen', return_value=io.BytesIO(data)):
                    handler.do_POST()
                self.assertEqual(handler.status, 502)

if __name__ == '__main__':
    unittest.main()
