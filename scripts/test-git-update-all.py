#!/usr/bin/env python3
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).with_name('git-update-all.py')


def run(*args, cwd=None):
  return subprocess.run(args, cwd=cwd, text=True, capture_output=True, check=True)


class UpdateTests(unittest.TestCase):
  def test_preview_update_and_dirty_skip(self):
    with tempfile.TemporaryDirectory(prefix='git-update-test-') as tmp:
      root = Path(tmp)
      remote, seed, group = root / 'remote.git', root / 'seed', root / 'group'
      group.mkdir()
      run('git', 'init', '--bare', str(remote))
      run('git', 'clone', str(remote), str(seed))
      run('git', 'config', 'user.email', 'test@example.com', cwd=seed)
      run('git', 'config', 'user.name', 'Test', cwd=seed)
      (seed / 'file').write_text('first')
      run('git', 'add', 'file', cwd=seed)
      run('git', 'commit', '-m', 'first', cwd=seed)
      run('git', 'push', '-u', 'origin', 'HEAD', cwd=seed)
      clean, dirty = group / 'clean', group / 'dirty repo'
      run('git', 'clone', str(remote), str(clean))
      run('git', 'clone', str(remote), str(dirty))
      (dirty / 'untracked').write_text('keep')
      (seed / 'file').write_text('second')
      run('git', 'commit', '-am', 'second', cwd=seed)
      run('git', 'push', cwd=seed)
      preview = run('python3', str(SCRIPT), '--dry-run', str(group)).stdout
      self.assertIn('WOULD UPDATE', preview)
      self.assertIn('SKIP: local changes', preview)
      self.assertEqual((clean / 'file').read_text(), 'first')
      result = run('python3', str(SCRIPT), str(group)).stdout
      self.assertIn('1 updated', result)
      self.assertEqual((clean / 'file').read_text(), 'second')
      self.assertEqual((dirty / 'file').read_text(), 'first')
      self.assertEqual((dirty / 'untracked').read_text(), 'keep')


if __name__ == '__main__':
  unittest.main()
