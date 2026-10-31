#!/usr/bin/env python3
import subprocess
import contextlib
import importlib.util
import io
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

SCRIPT = Path(__file__).with_name('git-update-all.py')


def run(*args, cwd=None):
  return subprocess.run(args, cwd=cwd, text=True, capture_output=True, check=True)


class UpdateTests(unittest.TestCase):
  def test_scan_continues_after_directory_errors(self):
    spec = importlib.util.spec_from_file_location('git_update_all', SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    with tempfile.TemporaryDirectory(prefix='git-update-scan-') as tmp:
      root = Path(tmp)
      def walk(path, followlinks, onerror):
        onerror(FileNotFoundError(2, 'No such file or directory', str(root / 'gone')))
        onerror(PermissionError(13, 'Permission denied', str(root / 'private')))
        yield str(root / 'remaining'), ['.git'], []
      counts = {'vanished': 0, 'scan_errors': 0}
      with patch.object(module.os, 'walk', side_effect=walk), contextlib.redirect_stderr(io.StringIO()) as stderr:
        found = list(module.repositories(root, counts))
      self.assertEqual(found, [root / 'remaining'])
      self.assertEqual(counts, {'vanished': 1, 'scan_errors': 1})
      self.assertIn('gone', stderr.getvalue())
      self.assertIn('private', stderr.getvalue())

  def test_scan_error_exit_status(self):
    spec = importlib.util.spec_from_file_location('git_update_all', SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    with tempfile.TemporaryDirectory(prefix='git-update-scan-') as tmp:
      def walk(path, followlinks, onerror):
        onerror(PermissionError(13, 'Permission denied', os.path.join(tmp, 'private')))
        return iter(())
      with patch.object(module.os, 'walk', side_effect=walk), \
           patch('sys.argv', ['git-update-all', '--dry-run', tmp]), \
           contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()) as stderr:
        self.assertEqual(module.main(), 1)
      self.assertIn('1 errors', stderr.getvalue())

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
