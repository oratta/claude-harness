import argparse
import json
import hashlib
import sys
import tempfile
import unittest
from pathlib import Path
from poc import run

FAKE = '''import sys,json
started=0
interrupted=0
for line in sys.stdin:
 m=json.loads(line); method=m.get('method'); rid=m.get('id')
 if rid is None: continue
 if method=='turn/start': started+=1
 if method=='turn/interrupt': interrupted+=1
 with open('calls.json','w') as f: json.dump({'started':started,'interrupted':interrupted},f)
 if method=='turn/start' and STATUS in ('auth_error','quota_error'):
  print(json.dumps({'id':rid,'error':{'code':401 if STATUS=='auth_error' else 429,'message':'SECRET DO NOT LOG'}}),flush=True)
  continue
 r={}
 if method=='account/read': r={'account':{'type':'chatgpt','email':'fixture@example.invalid'}}
 if method=='thread/start': r={'thread':{'id':'t'}}
 if method=='turn/start': r={'turn':{'id':'u'}}
 if method=='thread/read': r={'thread':{'turns':[{'id':'u','items':[{'type':'agentMessage','text':'READY'}]}]}}
 print(json.dumps({'id':rid,'result':r}),flush=True)
 if method=='turn/start' and STATUS=='flood':
  for n in range(100000): print(json.dumps({'method':'item/started','params':{'threadId':'other','turnId':'other'}}),flush=True)
 if method=='turn/start' and STATUS=='disconnect': sys.exit(0)
 if method=='turn/start' and STATUS=='server_request':
  print(json.dumps({'id':999,'method':'item/tool/requestUserInput','params':{}}),flush=True)
 if method=='turn/start':
  print(json.dumps({'method':'item/started','params':{'threadId':'t','turnId':'u'}}),flush=True)
 if method=='turn/interrupt' or (method=='turn/start' and STATUS=='auto_complete'):
  STATUS = 'completed' if STATUS=='auto_complete' else 'interrupted' if STATUS=='server_request' else STATUS
  print(json.dumps({'method':'turn/completed','params':{'threadId':'t','turn':{'id':'u','status':STATUS,'items':[]}}}),flush=True)
'''

class ProtocolTest(unittest.TestCase):
 def execute(self,status,expected=None,mode='interrupt'):
  with tempfile.TemporaryDirectory() as d:
   script=Path(d)/'server.py';script.write_text('STATUS='+repr(status)+'\n'+FAKE)
   args=argparse.Namespace(cwd=d,mode=mode,model='fixture',timeout=.1,
      expected_account=expected or hashlib.sha256(b'chatgpt:fixture@example.invalid').hexdigest())
   result=run(args,[sys.executable,str(script)])
   result['calls']=json.loads((Path(d)/'calls.json').read_text())
   return result
 def test_timeout_does_not_resubmit(self):
  r=self.execute('stall',mode='complete')
  self.assertEqual(r['status'],'attention_required')
  self.assertEqual(r['calls']['started'],1)
 def test_progress_flood_cannot_extend_deadline(self):
  r=self.execute('flood',mode='complete')
  self.assertEqual(r['status'],'attention_required')
  self.assertEqual(r['calls']['started'],1)
 def test_disconnect_is_unknown(self):
  r=self.execute('disconnect',mode='complete')
  self.assertEqual(r['status'],'unknown')
  self.assertEqual(r['calls']['started'],1)
 def test_auth_and_quota_are_not_timeout(self):
  for case,code in [('auth_error','401'),('quota_error','429')]:
   r=self.execute(case,mode='complete')
   self.assertEqual(r['rpc_error_code'],code)
   self.assertEqual(r['status'],'unknown')
   self.assertNotIn('SECRET',json.dumps(r))
   self.assertEqual(r['calls']['started'],1)
 def test_server_request_without_thread_id_interrupts(self):
  r=self.execute('server_request',mode='complete')
  self.assertTrue(r['unsupported_request'])
  self.assertEqual(r['status'],'interrupted')
  self.assertEqual(r['calls']['interrupted'],1)
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
