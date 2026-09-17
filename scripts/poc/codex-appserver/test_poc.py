import argparse
import hashlib
import sys
import tempfile
import unittest
from pathlib import Path
from poc import run

FAKE = '''import sys,json
for line in sys.stdin:
 m=json.loads(line); method=m.get('method'); rid=m.get('id')
 if rid is None: continue
 r={}
 if method=='account/read': r={'account':{'type':'chatgpt','email':'fixture@example.invalid'}}
 if method=='thread/start': r={'thread':{'id':'t'}}
 if method=='turn/start': r={'turn':{'id':'u'}}
 if method=='thread/read': r={'thread':{'turns':[{'id':'u','items':[{'type':'agentMessage','text':'READY'}]}]}}
 print(json.dumps({'id':rid,'result':r}),flush=True)
 if method=='turn/start':
  print(json.dumps({'method':'item/started','params':{'threadId':'t','turnId':'u'}}),flush=True)
 if method=='turn/interrupt' or (method=='turn/start' and STATUS=='auto_complete'):
  STATUS = 'completed' if STATUS=='auto_complete' else STATUS
  print(json.dumps({'method':'turn/completed','params':{'threadId':'t','turn':{'id':'u','status':STATUS,'items':[]}}}),flush=True)
'''

class ProtocolTest(unittest.TestCase):
 def execute(self,status,expected=None,mode='interrupt'):
  with tempfile.TemporaryDirectory() as d:
   script=Path(d)/'server.py';script.write_text('STATUS='+repr(status)+'\n'+FAKE)
   args=argparse.Namespace(cwd=d,mode=mode,model='fixture',timeout=.1,
      expected_account=expected or hashlib.sha256(b'chatgpt:fixture@example.invalid').hexdigest())
   return run(args,[sys.executable,str(script)])
 def test_result_read_when_notification_has_no_items(self):
  result=self.execute('auto_complete',mode='complete')
  self.assertTrue(result['result_verified'])
  self.assertEqual(result['result_text'],'READY')
 def test_interrupted_passes(self):
  self.assertTrue(self.execute('interrupted')['interruption_pass'])
 def test_completed_race_does_not_pass(self):
  self.assertFalse(self.execute('completed')['interruption_pass'])
 def test_unknown_does_not_pass(self):
  self.assertFalse(self.execute('failed')['interruption_pass'])
 def test_identity_mismatch_blocks_turn(self):
  result=self.execute('interrupted','wrong')
  self.assertEqual(result['status'],'identity_mismatch')
  self.assertNotIn('accepted',result)

if __name__=='__main__': unittest.main()
