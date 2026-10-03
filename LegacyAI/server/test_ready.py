import io,json,unittest
from unittest.mock import patch
import server
class ReadinessTests(unittest.TestCase):
    def run_check(self,result):
        h=object.__new__(server.Handler);h.path='/ready';h.respond=lambda code,body:setattr(h,'result',(code,body))
        with patch.object(server.urllib.request,'urlopen',return_value=io.BytesIO(json.dumps(result).encode())):h.do_GET()
        return h.result
    def test_available_model(self):self.assertEqual(self.run_check({'models':[{'name':server.MODEL}]}),(200,{'status':'ok'}))
    def test_missing_model(self):self.assertEqual(self.run_check({'models':[]})[0],503)
    def test_offline_ollama(self):
        h=object.__new__(server.Handler);h.path='/ready';h.respond=lambda code,body:setattr(h,'code',code)
        with patch.object(server.urllib.request,'urlopen',side_effect=OSError()):h.do_GET()
        self.assertEqual(h.code,503)
