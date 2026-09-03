#!/usr/bin/env python3
"""Unit tests for omastreamer scene order, mute plan, and OBS auth."""

import importlib.machinery
import unittest
from pathlib import Path

BRIDGE = Path(__file__).resolve().parents[1] / "bin" / "obs-bridge"
MOD = importlib.machinery.SourceFileLoader("obs_bridge", str(BRIDGE)).load_module()


class OrderScenes(unittest.TestCase):
    def test_top_of_dock_is_scene_one(self):
        scenes = [
            {"sceneName": "Scene 2", "sceneIndex": 0},
            {"sceneName": "Scene", "sceneIndex": 1},
        ]
        self.assertEqual(MOD.order_scenes(scenes), ["Scene", "Scene 2"])

    def test_empty(self):
        self.assertEqual(MOD.order_scenes([]), [])


class MutePlan(unittest.TestCase):
    def test_mute_when_any_live(self):
        self.assertTrue(MOD.should_mute({"mic": False, "desk": True}))

    def test_unmute_when_all_muted(self):
        self.assertFalse(MOD.should_mute({"mic": True, "desk": True}))

    def test_empty_stays_false(self):
        self.assertFalse(MOD.should_mute({}))


class Auth(unittest.TestCase):
    def test_known_vector(self):
        token = MOD.auth_token("password", "salt", "challenge")
        self.assertEqual(token, "zTM5ki6L2vVvBQiTG9ckH1Lh64AbnCf6XZ226UmnkIA=")


if __name__ == "__main__":
    unittest.main()
