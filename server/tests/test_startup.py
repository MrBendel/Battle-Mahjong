import os
import unittest

from server.config import get_startup_config

try:
    from fastapi.testclient import TestClient
    from server.main import app, HAS_FASTAPI
except ImportError:
    HAS_FASTAPI = False
    TestClient = None


class TestStartupConfig(unittest.TestCase):
    def setUp(self):
        # Save original env
        self.original_env = os.environ.copy()

    def tearDown(self):
        # Restore original env
        os.environ.clear()
        os.environ.update(self.original_env)

    def test_default_config(self):
        # Clear specific env vars
        for key in ["LATEST_VERSION_CODE", "LATEST_VERSION_NAME", "MAINTENANCE_ACTIVE"]:
            os.environ.pop(key, None)

        cfg = get_startup_config("android")
        self.assertEqual(cfg["status"], "ok")
        self.assertFalse(cfg["maintenance"]["active"])
        self.assertEqual(cfg["maintenance"]["message"], "")
        self.assertEqual(cfg["version"]["latest_version_code"], 8)
        self.assertEqual(cfg["version"]["latest_version_name"], "0.1.7")
        self.assertIn("play.google.com", cfg["version"]["store_url"])
        self.assertTrue(cfg["features"]["show_arcade_callouts"])

    def test_environment_overrides(self):
        os.environ["LATEST_VERSION_CODE"] = "12"
        os.environ["LATEST_VERSION_NAME"] = "0.2.5"
        os.environ["MIN_VERSION_CODE"] = "10"
        os.environ["MAINTENANCE_ACTIVE"] = "true"
        os.environ["MAINTENANCE_MESSAGE"] = "Server upgrade in progress"
        os.environ["FORCE_UPDATE"] = "true"

        cfg = get_startup_config("android")
        self.assertTrue(cfg["maintenance"]["active"])
        self.assertEqual(cfg["maintenance"]["message"], "Server upgrade in progress")
        self.assertEqual(cfg["version"]["latest_version_code"], 12)
        self.assertEqual(cfg["version"]["latest_version_name"], "0.2.5")
        self.assertEqual(cfg["version"]["min_version_code"], 10)
        self.assertTrue(cfg["version"]["force_update"])

    def test_platform_store_urls(self):
        os.environ["STORE_URL_ANDROID"] = "https://play.google.com/store/apps/details?id=com.platypus.battlemahjong"
        os.environ["STORE_URL_IOS"] = "https://apps.apple.com/app/id123456789"

        android_cfg = get_startup_config("android")
        self.assertEqual(android_cfg["version"]["store_url"], "https://play.google.com/store/apps/details?id=com.platypus.battlemahjong")

        ios_cfg = get_startup_config("ios")
        self.assertEqual(ios_cfg["version"]["store_url"], "https://apps.apple.com/app/id123456789")

    def test_fastapi_endpoints_if_installed(self):
        if not HAS_FASTAPI or TestClient is None or app is None:
            self.skipTest("FastAPI not installed in local environment; skipping HTTP test")

        client = TestClient(app)
        res_health = client.get("/health")
        self.assertEqual(res_health.status_code, 200)
        self.assertEqual(res_health.json()["status"], "healthy")

        res_startup = client.get("/v1/startup?platform=android&version_code=8&version_name=0.1.7")
        self.assertEqual(res_startup.status_code, 200)
        data = res_startup.json()
        self.assertEqual(data["status"], "ok")
        self.assertIn("version", data)
        self.assertIn("maintenance", data)
        self.assertEqual(data["client_request"]["version_code"], 8)


if __name__ == "__main__":
    unittest.main()
