import io,json,unittest
from unittest.mock import patch
import server
class PublicTests(unittest.TestCase):
    def setUp(self):
        server.PUBLIC_CLIENTS.clear();server.PUBLIC_GLOBAL.clear()
    def handler(self,path='/public-chat'):
        h=object.__new__(server.Handler);h.path=path;h.client_address=('127.0.0.1',1)
        data=json.dumps({'character':'Mira','persona':'Explorer','messages':[{'role':'user','content':'Hello'}]}).encode()
        h.headers={'Content-Length':str(len(data)),'CF-Connecting-IP':'203.0.113.1'};h.rfile=io.BytesIO(data);h.wfile=io.BytesIO()
        h.send_response=lambda code:setattr(h,'status',code);h.send_header=lambda *args:None;h.end_headers=lambda:None
        return h
    def test_no_token_required_when_enabled(self):
        h=self.handler()
        with patch.object(server,'PUBLIC_ENABLED',True),patch.object(server.urllib.request,'urlopen',return_value=io.BytesIO(b'{"message":{"content":"Hello."}}')):h.do_POST()
        self.assertEqual(h.status,200)
    def test_disabled_by_default(self):
        h=self.handler()
        with patch.object(server,'PUBLIC_ENABLED',False):h.do_POST()
        self.assertEqual(h.status,404)
    def test_rate_window(self):
        for _ in range(6):self.assertTrue(server.allow_public('a',0))
        self.assertFalse(server.allow_public('a',1));self.assertTrue(server.allow_public('a',61))
    def test_capacity_and_release(self):
        h=self.handler();server.PUBLIC_SLOTS.acquire();server.PUBLIC_SLOTS.acquire()
        try:
            with patch.object(server,'PUBLIC_ENABLED',True):h.do_POST()
            self.assertEqual(h.status,503)
        finally:server.PUBLIC_SLOTS.release();server.PUBLIC_SLOTS.release()
        h=self.handler()
        with patch.object(server,'PUBLIC_ENABLED',True),patch.object(server.urllib.request,'urlopen',side_effect=OSError()):h.do_POST()
        self.assertEqual(h.status,502)
        self.assertTrue(server.PUBLIC_SLOTS.acquire(blocking=False));server.PUBLIC_SLOTS.release()
