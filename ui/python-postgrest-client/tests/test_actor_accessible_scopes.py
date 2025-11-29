import json
import pathlib
import sys
import unittest
from http import HTTPStatus

import httpx

# Allow importing the generated client directly from the source tree without installing the wheel
sys.path.append(str(pathlib.Path(__file__).resolve().parents[1]))

from crazylims_postgrest_client import AuthenticatedClient  # noqa: E402
from crazylims_postgrest_client.api.rpc_actor_accessible_scopes import (  # noqa: E402
    post_rpc_actor_accessible_scopes,
)
from crazylims_postgrest_client.models.post_rpc_actor_accessible_scopes_json_body import (  # noqa: E402
    PostRpcActorAccessibleScopesJsonBody,
)  # noqa: E402


class ActorAccessibleScopesClientTests(unittest.TestCase):
    def test_posts_scope_types_with_auth_header(self) -> None:
        captured = {}

        def handler(request: httpx.Request) -> httpx.Response:
            captured["method"] = request.method
            captured["url"] = str(request.url)
            captured["headers"] = dict(request.headers)
            captured["body"] = json.loads(request.content.decode())
            return httpx.Response(200, json=[])

        transport = httpx.MockTransport(handler)
        client = AuthenticatedClient(base_url="https://postgrest.test/api", token="BearerToken123")
        auth_headers = {client.auth_header_name: f"{client.prefix} {client.token}"}
        client = client.with_headers(auth_headers)
        client.set_httpx_client(
            httpx.Client(base_url="https://postgrest.test/api", headers=auth_headers, transport=transport)
        )

        body = PostRpcActorAccessibleScopesJsonBody(p_scope_types=["dataset", "project"])
        response = post_rpc_actor_accessible_scopes.sync_detailed(client=client, body=body)

        self.assertEqual(response.status_code, HTTPStatus.OK)
        self.assertEqual(captured["method"], "POST")
        self.assertTrue(captured["url"].endswith("/rpc/actor_accessible_scopes"))
        self.assertEqual(captured["headers"].get("authorization"), "Bearer BearerToken123")
        self.assertEqual(captured["headers"].get("content-type"), "application/json")
        self.assertEqual(
            captured["body"],
            {"p_scope_types": ["dataset", "project"]},
        )


if __name__ == "__main__":
    unittest.main()
