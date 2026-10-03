import io
import json
import unittest
from unittest.mock import patch
import server

class GroupTests(unittest.TestCase):
    def setUp(self):
        self.payload={'character':'Campfire','persona':'Group roleplay',
            'participants':[{'id':'a','name':'Mira','persona':'Explorer'},
                            {'id':'b','name':'Pencil','persona':'Artist'}],
            'respondingIDs':['a','b'],
            'messages':[{'role':'user','content':'Tell me about this place.'}]}
    def handler(self):
        handler=object.__new__(server.Handler)
        handler.path='/group-chat'
        body=json.dumps(self.payload).encode()
        handler.headers={'Content-Length':str(len(body)),'Authorization':'Bearer test-token-123456'}
        handler.rfile=io.BytesIO(body); handler.wfile=io.BytesIO()
        handler.send_response=lambda code: setattr(handler,'status',code)
        handler.send_header=lambda *args: None; handler.end_headers=lambda: None
        return handler
    def test_two_named_replies_and_shared_context(self):
        data=[io.BytesIO(b'{"message":{"content":"A forest."}}'),io.BytesIO(b'{"message":{"content":"I will draw it."}}')]
        with patch.object(server.urllib.request,'urlopen',side_effect=data) as upstream:
            replies=server.generate_group(self.payload)
        self.assertEqual([r['speakerID'] for r in replies],['a','b'])
        first=json.loads(upstream.call_args_list[0].args[0].data)
        second=json.loads(upstream.call_args_list[1].args[0].data)
        self.assertIn('You are Mira.',first['messages'][0]['content'])
        self.assertIn('You are Pencil.',second['messages'][0]['content'])
        self.assertEqual(second['messages'][-2]['content'],'Mira: A forest.')
        self.assertEqual(second['messages'][-1]['role'],'user')
        self.assertIn('respond as Pencil',second['messages'][-1]['content'])
    def test_selected_speaker_only(self):
        self.payload['respondingIDs']=['b']
        with patch.object(server.urllib.request,'urlopen',return_value=io.BytesIO(b'{"message":{"content":"Hello."}}')) as upstream:
            replies=server.generate_group(self.payload)
        self.assertEqual(upstream.call_count,1)
        self.assertEqual(replies[0]['speakerID'],'b')
    def test_manual_turn_after_another_character(self):
        self.payload['messages'].append({'role':'assistant','speaker':'Mira','content':'A forest.'})
        self.payload['respondingIDs']=['b']
        with patch.object(server.urllib.request,'urlopen',return_value=io.BytesIO(b'{"message":{"content":"I will draw it."}}')) as upstream:
            replies=server.generate_group(self.payload)
        self.assertEqual([r['speakerID'] for r in replies],['b'])
        body=json.loads(upstream.call_args.args[0].data)
        self.assertEqual(body['messages'][-2]['content'],'Mira: A forest.')
        self.assertEqual(body['messages'][-1]['role'],'user')
    def test_manual_opening_turn(self):
        self.payload['messages']=[]
        self.payload['respondingIDs']=['a']
        with patch.object(server.urllib.request,'urlopen',return_value=io.BytesIO(b'{"message":{"content":"Welcome."}}')):
            self.assertEqual(server.generate_group(self.payload)[0]['speakerID'],'a')
    def test_turn_boundaries_override_old_style(self):
        self.payload['respondingIDs']=['b']
        self.payload['messages'].append({'role':'assistant','speaker':'Mira',
            'content':'I shout. Pencil says "Hello".'})
        reply='Pencil folded her arms. "I disagree."'
        with patch.object(server.urllib.request,'urlopen',return_value=io.BytesIO(
                json.dumps({'message':{'content':reply}}).encode())) as upstream:
            replies=server.generate_group(self.payload)
        body=json.loads(upstream.call_args.args[0].data)
        self.assertIn(server.ROLEPLAY_STYLE,body['messages'][0]['content'])
        self.assertEqual(body['options'],server.generation_options(True))
        for instruction in (body['messages'][0]['content'],body['messages'][-1]['content']):
            self.assertIn('Pencil',instruction)
            self.assertIn('THIRD PERSON',instruction)
            self.assertIn('any other character or the user',instruction)
            self.assertIn('ONLY inside quoted',instruction)
            self.assertIn('Stop before another person responds',instruction)
        self.assertEqual(replies[0]['content'],reply)
        self.assertEqual(replies[0]['speakerID'],'b')

    def test_eight_member_roster_and_ninth_rejected(self):
        self.payload['participants']=[{'id':str(i),'name':'Character '+str(i),'persona':'Explorer'} for i in range(8)]
        self.payload['respondingIDs']=['7']
        with patch.object(server.urllib.request,'urlopen',return_value=io.BytesIO(b'{"message":{"content":"Eighth character replied."}}')):
            replies=server.generate_group(self.payload)
        self.assertEqual([r['speakerID'] for r in replies],['7'])
        self.payload['participants'].append({'id':'8','name':'Ninth','persona':'Explorer'})
        with self.assertRaises(ValueError): server.validate_group(self.payload)

    def test_invalid_rosters(self):
        for participants,ids in (([],[]),([self.payload['participants'][0]]*2,['a']),
                                 (self.payload['participants'],['missing']),
                                 (self.payload['participants'],['a','a'])):
            payload=dict(self.payload,participants=participants,respondingIDs=ids)
            with self.subTest(payload=payload),self.assertRaises(ValueError):
                server.validate_group(payload)
    def test_group_http_success(self):
        handler=self.handler()
        data=[io.BytesIO(b'{"message":{"content":"First."}}'),io.BytesIO(b'{"message":{"content":"Second."}}')]
        with patch.object(server,'TOKEN','test-token-123456'),patch.object(server.urllib.request,'urlopen',side_effect=data):
            handler.do_POST()
        self.assertEqual(handler.status,200)
        self.assertEqual(len(json.loads(handler.wfile.getvalue())['replies']),2)
    def test_failure_returns_no_partial_round(self):
        handler=self.handler()
        with patch.object(server,'TOKEN','test-token-123456'),patch.object(server.urllib.request,'urlopen',side_effect=[io.BytesIO(b'{"message":{"content":"First."}}'),OSError('offline')]):
            handler.do_POST()
        self.assertEqual(handler.status,502)
        self.assertNotIn('replies',json.loads(handler.wfile.getvalue()))
    def test_speaker_names_in_saved_history(self):
        self.payload['messages'].insert(0,{'role':'assistant','speaker':'Pencil','content':'Earlier story'})
        _,_,history=server.validate_group(self.payload)
        self.assertEqual(history[0]['content'],'Pencil: Earlier story')

if __name__=='__main__': unittest.main()
