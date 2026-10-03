import os
import tempfile
from pathlib import Path
import unittest
from unittest.mock import patch
import server

class TokenTests(unittest.TestCase):
    def test_generate_and_reuse(self):
        with tempfile.TemporaryDirectory() as temp, patch.dict(os.environ, {'ROLEPLAY_TOKEN': ''}):
            path=Path(temp)/'.roleplay-token'
            first=server.load_or_create_token(path)
            self.assertEqual(len(first),32)
            self.assertTrue(first.isascii())
            self.assertEqual(server.load_or_create_token(path),first)
            self.assertEqual(path.stat().st_mode & 0o777,0o600)
    def test_existing_environment_token(self):
        with patch.dict(os.environ, {'ROLEPLAY_TOKEN':'test-token-123456'}):
            self.assertEqual(server.load_or_create_token(),'test-token-123456')
    def test_invalid_environment_token(self):
        for token in ('short','é'*20):
            with self.subTest(token=token),patch.dict(os.environ,{'ROLEPLAY_TOKEN':token}),self.assertRaises(ValueError):
                server.load_or_create_token()

if __name__=='__main__': unittest.main()
