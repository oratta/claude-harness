"""Temporary homes only; no private instruction bodies are fixtures."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT/'scripts/codex-shared-instructions.py'


class Shared(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.env = dict(os.environ, HOME=str(self.root), CODEX_HOME=str(self.root/'current'),
                        CLAUDE_CONFIG_DIR=str(self.root/'.claude'))
        spec = importlib.util.spec_from_file_location('shared', SCRIPT)
        self.m = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.m)

    def cli(self, *args, ok=True, script=SCRIPT):
        p = subprocess.run([sys.executable, '-B', str(script), *map(str, args)],
                           env=self.env, capture_output=True, text=True)
        self.assertEqual(p.returncode == 0, ok, p.stdout+p.stderr)
        return p

    def sync(self, *args, ok=True):
        p = subprocess.run(['sh', str(ROOT/'scripts/sync.sh'), '--no-pull', *map(str,args)],
                           env=self.env, capture_output=True, text=True)
        self.assertEqual(p.returncode == 0, ok, p.stdout+p.stderr)
        return p

    def test_generation(self):
        self.cli('check')
        data = self.m.generate(ROOT)
        rules = sorted((ROOT/'rules').glob('*.md'))
        positions = []
        for rule in rules:
            if rule.name == 'README.md':
                continue
            self.assertIn(rule.read_bytes(), data)
            positions.append(data.index(('## rules/'+rule.name+'\n').encode()))
        self.assertEqual(positions, sorted(positions))
        self.assertNotIn(b'## rules/README.md', data)
        self.assertIn((ROOT/'AGENTS.md').read_bytes(), data)
        self.assertIn('harness 配布元リポジトリを変更するときだけ'.encode(), data)
        copy = self.root/'repo'
        for sub in ('rules','generated','scripts'):
            shutil.copytree(ROOT/sub, copy/sub)
        shutil.copy(ROOT/'AGENTS.md', copy/'AGENTS.md')
        with (copy/'rules/communication-style.md').open('a') as f:
            f.write('\n鮮度の検査\n')
        tool = copy/'scripts/codex-shared-instructions.py'
        self.cli('check', script=tool, ok=False)
        self.cli('generate', script=tool)
        self.cli('check', script=tool)

    def test_sync(self):
        home = self.root/'.codex'; home.mkdir()
        old = '既存の指示\r\n二行\n三行\n四行\n五行\n六行\n七行'.encode()
        (home/'AGENTS.md').write_bytes(old)
        config = '# keep comment\nmodel="fixture"\nproject_doc_max_bytes=262144\n[profiles.small]\nproject_doc_max_bytes=4\n[mcp_servers.external]\ncommand="keep"\n'
        (home/'config.toml').write_text(config)
        self.sync()
        self.assertEqual((home/'AGENTS.md').read_bytes(), old)
        other = self.root/'registered'; other.mkdir()
        alias = self.root/'alias'; alias.symlink_to(other, target_is_directory=True)
        args = ('--codex','--account-home',f'a={other}','--account-home',f'b={alias}')
        self.sync(*args)
        snapshots = {}
        for h in (home, self.root/'current', other):
            data = (h/'AGENTS.md').read_bytes()
            self.assertTrue(data.startswith(self.m.BEGIN))
            snapshots[h] = (data, (h/'config.toml').read_bytes())
        self.assertTrue(snapshots[home][0].endswith(old))
        parsed = tomllib.loads((home/'config.toml').read_text())
        self.assertEqual(parsed['project_doc_max_bytes'],262144)
        self.assertEqual(parsed['profiles']['small']['project_doc_max_bytes'],131072)
        self.assertEqual(parsed['mcp_servers']['external']['command'],'keep')
        self.assertIn('# keep comment', (home/'config.toml').read_text())
        self.sync(*args)
        for h, expected in snapshots.items():
            self.assertEqual(((h/'AGENTS.md').read_bytes(),(h/'config.toml').read_bytes()),expected)
        table = self.root/'table.json';table.write_text(json.dumps({'a':str(other)}))
        self.sync('--codex','--account-home-file',table)

    def test_accounts(self):
        home = self.root/'registered';home.mkdir()
        table = self.root/'table.json'
        table.write_text(json.dumps({'a':str(home)}))
        invalid = [('--account-home','no-equals'),('--account-home','a=relative'),
                   ('--account-home',f'a={self.root}/absent'),
                   ('--account-home',f'a={home}','--account-home',f'a={home}'),
                   ('--account-home',f'a={home}','--account-home-file',table)]
        for args in invalid:
            self.sync('--codex',*args,ok=False)
        for raw in ('[]','{"a":{}}','{"a":0}','{"": "x"}',
                    '{"a":"'+str(home)+'","a":"'+str(home)+'"}'):
            table.write_text(raw)
            self.sync('--codex','--account-home-file',table,ok=False)

    def test_unsafe(self):
        home = self.root/'.codex';home.mkdir()
        begin,end = self.m.BEGIN,self.m.END
        for data in (begin, end, end+begin, begin+begin+end, begin+end+end):
            (home/'AGENTS.md').write_bytes(data)
            self.sync('--codex',ok=False)
            self.assertEqual((home/'AGENTS.md').read_bytes(),data)
            self.assertFalse((home/'config.toml').exists())
        (home/'AGENTS.md').write_bytes(b'old')
        (home/'AGENTS.override.md').write_text('override')
        self.sync('--codex',ok=False)
        self.assertEqual((home/'AGENTS.md').read_bytes(),b'old')
        (home/'AGENTS.override.md').unlink()
        target = self.root/'target';target.write_bytes(b'outside')
        for name in ('AGENTS.md','config.toml'):
            (home/name).unlink(missing_ok=True)
            (home/name).symlink_to(target)
            self.sync('--codex',ok=False)
            self.assertEqual(target.read_bytes(),b'outside')
            (home/name).unlink()
        (home/'config.toml').write_text('invalid toml')
        self.sync('--codex',ok=False)
        self.assertFalse((home/'AGENTS.md').exists())

    def test_overlays(self):
        claude = self.root/'.claude';claude.mkdir()
        for name in ('a','b','forbidden'):
            d = claude/'plugins/marketplaces'/name
            (d/'rules').mkdir(parents=True)
            (d/'.harness-overlay').write_text(name+'\n')
            (d/'rules/private.md').write_text('PRIVATE-'+name)
            (d/'rules/README.md').write_text('README-SECRET')
        memory = claude/'projects/fixture/memory';memory.mkdir(parents=True)
        (memory/'MEMORY.md').write_text('AUTO-MEMORY-SECRET')
        allow = claude/'harness-overlays';allow.write_text('b\na\n')
        self.sync('--codex')
        home = self.root/'.codex/AGENTS.md'
        before = home.read_bytes()
        for forbidden in (b'PRIVATE-forbidden',b'README-SECRET',b'AUTO-MEMORY-SECRET'):
            self.assertNotIn(forbidden,before)
        self.assertLess(before.index(b'PRIVATE-a'),before.index(b'PRIVATE-b'))
        allow.write_text('a\nb\n');self.sync('--codex')
        self.assertEqual(home.read_bytes(),before)
        allow.write_text('b\n');self.sync('--codex')
        self.assertNotIn(b'PRIVATE-a',home.read_bytes())
        self.assertNotIn(b'PRIVATE-',(ROOT/'generated/codex/AGENTS.md').read_bytes())

    def test_capacity(self):
        self.cli('capacity','--fixture')
        manifest = json.loads((ROOT/'tests/fixtures/codex-shared-instructions/manifest.json').read_text())
        for entry in manifest['inputs']:
            data = self.m.dummy(entry)
            self.assertEqual(len(data),entry['bytes'])
            self.assertEqual(data,self.m.dummy(entry))
            self.assertIn(b'END-FIXTURE',data)
            data.decode('utf-8')
        self.cli('capacity','--cwd',self.root/'missing','--home',self.root,ok=False)
        self.sync('--codex')
        repo = self.root/'repo';repo.mkdir()
        (repo/'.git').mkdir()
        (repo/'AGENTS.md').write_text('日本語')
        (repo/'CLAUDE.md').write_text('DO-NOT-COUNT'*100)
        child = repo/'ponta';child.mkdir()
        (child/'AGENTS.override.md').write_text('末尾')
        (child/'AGENTS.md').write_text('DO-NOT-COUNT')
        home = self.root/'.codex'
        selected = self.m.discover(repo,child)
        self.assertEqual(selected,[repo/'AGENTS.md',child/'AGENTS.override.md'])
        total = len((home/'AGENTS.md').read_bytes())+len('日本語末尾'.encode())
        self.cli('capacity','--cwd',child,'--home',home,'--limit',total)
        self.cli('capacity','--cwd',child,'--home',home,'--limit',total-1,ok=False)


if __name__ == '__main__':
    unittest.main()
