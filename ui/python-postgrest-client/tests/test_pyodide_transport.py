import importlib
import sys
import types
import unittest
from unittest import mock
import importlib.util


class PyodideTransportTests(unittest.TestCase):
    def setUp(self) -> None:
        self._js_original = sys.modules.get("js")
        sys.modules["js"] = types.SimpleNamespace(
            undefined=None,
            window=types.SimpleNamespace(location=types.SimpleNamespace(origin="http://example.com")),
            parent=None,
            globalThis=types.SimpleNamespace(),
        )

        self._pyodide_http_original = sys.modules.get("pyodide_http")
        self._pyodide_http_mock = types.SimpleNamespace(patch_all=mock.Mock())
        sys.modules["pyodide_http"] = self._pyodide_http_mock

    def tearDown(self) -> None:
        if self._js_original is None:
            sys.modules.pop("js", None)
        else:
            sys.modules["js"] = self._js_original

        if self._pyodide_http_original is None:
            sys.modules.pop("pyodide_http", None)
        else:
            sys.modules["pyodide_http"] = self._pyodide_http_original

    def test_prefers_fetch_transport_when_available(self) -> None:
        module = importlib.reload(importlib.import_module("crazylims_postgrest_client.pyodide"))

        transport_instance = object()
        with mock.patch.object(
            module.httpx, "FetchTransport", return_value=transport_instance, create=True
        ):
            client = module.build_authenticated_client(
                base_url="http://example.com/api", token="abc123"
            )

        self.assertIs(client._httpx_args.get("transport"), transport_instance)
        self._pyodide_http_mock.patch_all.assert_not_called()

    def test_client_import_skips_ssl_when_unavailable(self) -> None:
        """The generated client should still import when the stdlib ssl module is missing."""

        original_ssl = sys.modules.get("ssl")
        if "ssl" in sys.modules:
            sys.modules.pop("ssl")

        def _restore_ssl() -> None:
            if original_ssl is not None:
                sys.modules["ssl"] = original_ssl

        self.addCleanup(_restore_ssl)
        self.addCleanup(
            importlib.reload, importlib.import_module("crazylims_postgrest_client.client")
        )

        with mock.patch("importlib.util.find_spec", return_value=None):
            module = importlib.reload(
                importlib.import_module("crazylims_postgrest_client.client")
            )

        self.assertTrue(hasattr(module, "Client"))


if __name__ == "__main__":
    unittest.main()
