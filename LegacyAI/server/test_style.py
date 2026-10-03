import unittest
import server
class StyleTests(unittest.TestCase):
    def test_single_character_style_and_history(self):
        history=[{'role':'user','content':'Where is the broken seat?'}]
        messages=server.validate({'character':'Peter','persona':'A foul-mouthed man','messages':history})
        self.assertIn(server.ROLEPLAY_STYLE,messages[0]['content'])
        self.assertIn('third person',messages[0]['content'])
        self.assertIn('uncensored profanity',messages[0]['content'])
        self.assertEqual(messages[1:],history)
    def test_generation_budget_and_repetition(self):
        self.assertEqual(server.generation_options(True)['num_predict'],384)
        self.assertGreater(server.generation_options()['repeat_penalty'],1)
        self.assertEqual(server.generation_options()['num_ctx'],8192)
