#!/usr/bin/env python3
import unittest
import sys
import os
import json
import tarfile
import hashlib
from unittest.mock import patch, MagicMock, mock_open
import importlib.util

# Dynamic import for file with dashes
AGENT_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../bin/headunit-update-agent.py'))
spec = importlib.util.spec_from_file_location("headunit_update_agent", AGENT_PATH)
agent = importlib.util.module_from_spec(spec)
sys.modules["headunit_update_agent"] = agent
spec.loader.exec_module(agent)

class TestUpdateAgent(unittest.TestCase):

    def setUp(self):
        # Reset globals if needed, though mostly using mocks
        pass

    @patch('os.path.exists')
    @patch('headunit_update_agent.fail')
    def test_validate_package_missing_file(self, mock_fail, mock_exists):
        mock_exists.return_value = False
        # Configure fail to raise SystemExit so we catch it
        mock_fail.side_effect = SystemExit(1)

        with self.assertRaises(SystemExit):
            agent.validate_package("/tmp/missing.tar.gz")

        mock_fail.assert_called_with("File not found.")

    @patch('os.path.exists')
    @patch('headunit_update_agent.fail')
    def test_validate_package_missing_checksum(self, mock_fail, mock_exists):
        mock_fail.side_effect = SystemExit(1)
        # File exists, sha missing
        mock_exists.side_effect = lambda p: p == "/tmp/pkg.tar.gz"

        with self.assertRaises(SystemExit):
            agent.validate_package("/tmp/pkg.tar.gz")

        mock_fail.assert_called_with("Checksum file missing: /tmp/pkg.tar.gz.sha256")

    @patch('os.path.exists')
    @patch('builtins.open', new_callable=mock_open, read_data="hash123  filename")
    @patch('headunit_update_agent.calculate_sha256')
    @patch('headunit_update_agent.fail')
    def test_validate_package_checksum_mismatch(self, mock_fail, mock_calc, mock_file, mock_exists):
        mock_fail.side_effect = SystemExit(1)
        mock_exists.return_value = True
        mock_calc.return_value = "hash999" # Mismatch

        with self.assertRaises(SystemExit):
            agent.validate_package("/tmp/pkg.tar.gz")

        mock_fail.assert_called_with("Checksum mismatch! Expected: hash123, Actual: hash999")

    @patch('os.path.exists')
    @patch('builtins.open', new_callable=mock_open, read_data="hash123  filename")
    @patch('headunit_update_agent.calculate_sha256')
    @patch('tarfile.open')
    def test_validate_package_success(self, mock_tar, mock_calc, mock_file, mock_exists):
        mock_exists.return_value = True
        mock_calc.return_value = "hash123"

        # Mock Tar file content
        mock_tar_obj = MagicMock()
        mock_tar.return_value.__enter__.return_value = mock_tar_obj

        member = tarfile.TarInfo(name="manifest.json")
        mock_tar_obj.getmembers.return_value = [member]

        # Mock manifest content
        manifest_data = json.dumps({"component": "app", "version": "1.0.0"}).encode('utf-8')
        mock_file_obj = MagicMock()
        mock_file_obj.read.return_value = manifest_data

        # Since json.load reads from the file object returned by extractfile
        mock_tar_obj.extractfile.return_value = mock_file_obj

        comp, ver = agent.validate_package("/tmp/pkg.tar.gz")

        self.assertEqual(comp, "app")
        self.assertEqual(ver, "1.0.0")

    @patch('headunit_update_agent.log')
    @patch('tarfile.open')
    @patch('os.makedirs')
    @patch('shutil.rmtree')
    @patch('os.path.exists')
    @patch('os.listdir')
    @patch('os.path.isdir')
    def test_install_package(self, mock_isdir, mock_listdir, mock_exists, mock_rm, mock_mkdirs, mock_tar, mock_log):
        # Setup
        mock_exists.return_value = False # Target dir doesn't exist

        mock_tar_obj = MagicMock()
        mock_tar.return_value.__enter__.return_value = mock_tar_obj

        # Mock members
        m1 = tarfile.TarInfo(name="file1.txt")
        m2 = tarfile.TarInfo(name="manifest.json")
        mock_tar_obj.getmembers.return_value = [m1, m2]

        # Mock listdir to return empty list so we don't try to recurse into structure
        mock_listdir.return_value = []

        agent.install_package("/tmp/pkg.tar.gz", "app", "1.0.0")

        mock_mkdirs.assert_called_with("/data/components/app/1.0.0", exist_ok=True)
        mock_tar_obj.extractall.assert_called()

if __name__ == '__main__':
    unittest.main()
