from http import HTTPStatus
from typing import Any, Optional, Union, cast

import httpx

from ...client import AuthenticatedClient, Client
from ...types import Response, UNSET
from ... import errors

from ...models.artefact_scopes import ArtefactScopes
from ...models.patch_artefact_scopes_prefer import PatchArtefactScopesPrefer
from ...types import UNSET, Unset
from typing import cast
from typing import Union



def _get_kwargs(
    *,
    body: Union[
        ArtefactScopes,
        ArtefactScopes,
        ArtefactScopes,
    ],
    artefact_id: Union[Unset, str] = UNSET,
    scope_id: Union[Unset, str] = UNSET,
    relationship: Union[Unset, str] = UNSET,
    assigned_at: Union[Unset, str] = UNSET,
    assigned_by: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    prefer: Union[Unset, PatchArtefactScopesPrefer] = UNSET,

) -> dict[str, Any]:
    headers: dict[str, Any] = {}
    if not isinstance(prefer, Unset):
        headers["Prefer"] = str(prefer)




    

    params: dict[str, Any] = {}

    params["artefact_id"] = artefact_id

    params["scope_id"] = scope_id

    params["relationship"] = relationship

    params["assigned_at"] = assigned_at

    params["assigned_by"] = assigned_by

    params["metadata"] = metadata


    params = {k: v for k, v in params.items() if v is not UNSET and v is not None}


    _kwargs: dict[str, Any] = {
        "method": "patch",
        "url": "/artefact_scopes",
        "params": params,
    }

    if isinstance(body, ArtefactScopes):
        _kwargs["json"] = body.to_dict()


        headers["Content-Type"] = "application/json"
    if isinstance(body, ArtefactScopes):
        _kwargs["json"] = body.to_dict()


        headers["Content-Type"] = "application/vnd.pgrst.object+json;nulls=stripped"
    if isinstance(body, ArtefactScopes):
        _kwargs["json"] = body.to_dict()


        headers["Content-Type"] = "application/vnd.pgrst.object+json"

    _kwargs["headers"] = headers
    return _kwargs



def _parse_response(*, client: Union[AuthenticatedClient, Client], response: httpx.Response) -> Optional[Any]:
    if response.status_code == 204:
        return None

    if client.raise_on_unexpected_status:
        raise errors.UnexpectedStatus(response.status_code, response.content)
    else:
        return None


def _build_response(*, client: Union[AuthenticatedClient, Client], response: httpx.Response) -> Response[Any]:
    return Response(
        status_code=HTTPStatus(response.status_code),
        content=response.content,
        headers=response.headers,
        parsed=_parse_response(client=client, response=response),
    )


def sync_detailed(
    *,
    client: Union[AuthenticatedClient, Client],
    body: Union[
        ArtefactScopes,
        ArtefactScopes,
        ArtefactScopes,
    ],
    artefact_id: Union[Unset, str] = UNSET,
    scope_id: Union[Unset, str] = UNSET,
    relationship: Union[Unset, str] = UNSET,
    assigned_at: Union[Unset, str] = UNSET,
    assigned_by: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    prefer: Union[Unset, PatchArtefactScopesPrefer] = UNSET,

) -> Response[Any]:
    """ 
    Args:
        artefact_id (Union[Unset, str]):
        scope_id (Union[Unset, str]):
        relationship (Union[Unset, str]):
        assigned_at (Union[Unset, str]):
        assigned_by (Union[Unset, str]):
        metadata (Union[Unset, str]):
        prefer (Union[Unset, PatchArtefactScopesPrefer]):
        body (ArtefactScopes):
        body (ArtefactScopes):
        body (ArtefactScopes):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        body=body,
artefact_id=artefact_id,
scope_id=scope_id,
relationship=relationship,
assigned_at=assigned_at,
assigned_by=assigned_by,
metadata=metadata,
prefer=prefer,

    )

    response = client.get_httpx_client().request(
        **kwargs,
    )

    return _build_response(client=client, response=response)


async def asyncio_detailed(
    *,
    client: Union[AuthenticatedClient, Client],
    body: Union[
        ArtefactScopes,
        ArtefactScopes,
        ArtefactScopes,
    ],
    artefact_id: Union[Unset, str] = UNSET,
    scope_id: Union[Unset, str] = UNSET,
    relationship: Union[Unset, str] = UNSET,
    assigned_at: Union[Unset, str] = UNSET,
    assigned_by: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    prefer: Union[Unset, PatchArtefactScopesPrefer] = UNSET,

) -> Response[Any]:
    """ 
    Args:
        artefact_id (Union[Unset, str]):
        scope_id (Union[Unset, str]):
        relationship (Union[Unset, str]):
        assigned_at (Union[Unset, str]):
        assigned_by (Union[Unset, str]):
        metadata (Union[Unset, str]):
        prefer (Union[Unset, PatchArtefactScopesPrefer]):
        body (ArtefactScopes):
        body (ArtefactScopes):
        body (ArtefactScopes):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        body=body,
artefact_id=artefact_id,
scope_id=scope_id,
relationship=relationship,
assigned_at=assigned_at,
assigned_by=assigned_by,
metadata=metadata,
prefer=prefer,

    )

    response = await client.get_async_httpx_client().request(
        **kwargs
    )

    return _build_response(client=client, response=response)

