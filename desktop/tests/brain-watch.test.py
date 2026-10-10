#!/usr/bin/env python3
"""Exercise real watcher/queue processes in an isolated temporary vault."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest

BIN = Path(__file__).resolve().parents[1] / 'bin'


class WatchTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.raw = self.root / 'Brain/raw'
        self.raw.mkdir(parents=True)
        self.state = self.root / 'state'
        self.env = dict(os.environ, BRAIN_ROOT=str(self.raw.parent), BRAIN_CAPTURE_STATE=str(self.state),
                        BRAIN_CAPTURE_NO_RUN='1', BRAIN_WATCH_INTERVAL='.05', BRAIN_WATCH_SETTLE='.2')
        self.proc = None

    def tearDown(self):
        self.stop()
        self.temp.cleanup()

    def stop(self):
        if self.proc:
            self.proc.terminate()
            self.proc.wait(timeout=5)
            self.proc = None

    def start(self):
        self.proc = subprocess.Popen([str(BIN / 'brain-watch')], env=self.env, stdout=subprocess.DEVNULL)
        self.until(lambda: (self.state / 'watch.state').exists())

    def until(self, condition):
        deadline = time.monotonic() + 5
        while not condition():
            if self.proc:
                self.assertIsNone(self.proc.poll())
            if time.monotonic() > deadline:
                self.fail('Timed out waiting for watcher')
            time.sleep(.03)

    def items(self):
        return [json.loads(p.read_text()) for p in self.state.glob('*.json')]

    def test_baseline_settle_recursive_dedupe_and_restart(self):
        (self.raw / 'old.md').write_text('Existing archive')
        self.start()
        nested = self.raw / 'nested'; nested.mkdir()
        source = nested / 'new source.md'
        for i in range(7):
            source.write_text(f'Writing source {i}')
            time.sleep(.08)
            self.assertEqual(len(self.items()), 0)
        self.until(lambda: len(self.items()) == 1)
        (self.raw / 'duplicate.md').write_bytes(source.read_bytes())
        (self.raw / '.hidden.md').write_text('Hidden')
        (self.raw / 'download.part').write_text('Partial')
        (self.raw / 'link.md').symlink_to(source)
        time.sleep(.5)
        self.assertEqual(len(self.items()), 1)
        self.stop()
        (nested / 'offline.md').write_text('Saved while stopped')
        self.start()
        self.until(lambda: len(self.items()) == 2)
        staged = self.raw / '.atomic.tmp'
        staged.write_text('Atomic editor save')
        staged.replace(self.raw / 'old.md')
        self.until(lambda: len(self.items()) == 3)

    def test_capture_collection_is_not_queued_twice(self):
        self.start()
        subprocess.run([str(BIN / 'brain-capture')], input=json.dumps({'text': 'A grouped source'}),
                       text=True, env=self.env, check=True, stdout=subprocess.DEVNULL)
        time.sleep(.6)
        self.assertEqual(len(self.items()), 1)
        collection = Path(self.items()[0]['path'])
        (collection / 'later.md').write_text('A later addition')
        self.until(lambda: len(self.items()) == 2)

    def test_worker_system_prompt_and_completion_evidence(self):
        fake_bin = self.root / 'bin'; fake_bin.mkdir()
        grok = fake_bin / 'grok'
        grok.write_text('''#!/usr/bin/env python3
import os, pathlib, sys
vault = pathlib.Path(os.environ['BRAIN_ROOT'])
assert sys.argv[sys.argv.index('--system-prompt-override') + 1] == (vault / 'AGENTS.md').read_text()
if os.environ.get('TEST_WRITE'):
    (vault / 'Summary.md').write_text('Verified summary')
    (vault / 'index.md').write_text('[[Summary]]')
    with (vault / 'log.md').open('a') as f: f.write('Ingested source\\n')
''')
        grok.chmod(0o755)
        notify = fake_bin / 'notify-send'
        notify.write_text('#!/bin/sh\nexit 0\n'); notify.chmod(0o755)
        env = dict(self.env, PATH=str(fake_bin) + ':' + os.environ['PATH'])
        (self.raw.parent / 'AGENTS.md').write_text('Current schema contents')
        source = self.raw / 'source.md'; source.write_text('Source data')
        subprocess.run([str(BIN / 'brain-capture'), 'enqueue', str(source)], env=env, check=True, stdout=subprocess.DEVNULL)
        subprocess.run([str(BIN / 'brain-process')], env=env, check=True)
        self.assertEqual(self.items()[0]['status'], 'failed', 'Zero exit alone must not count as success')
        item = self.items()[0]; item['status'] = 'queued'
        (self.state / (item['id'] + '.json')).write_text(json.dumps(item))
        (self.raw.parent / 'AGENTS.md').write_text('Updated schema for next invocation')
        subprocess.run([str(BIN / 'brain-process')], env=dict(env, TEST_WRITE='1'), check=True)
        self.assertEqual(self.items()[0]['status'], 'processed')
        self.assertEqual(source.read_text(), 'Source data')


if __name__ == '__main__':
    unittest.main()
