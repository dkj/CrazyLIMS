from http import HTTPStatus
from typing import Any, Optional, Union, cast

import httpx

from ...client import AuthenticatedClient, Client
from ...types import Response, UNSET
from ... import errors

from ...models.notebook_entries import NotebookEntries
from ...models.patch_notebook_entries_prefer import PatchNotebookEntriesPrefer
from ...types import UNSET, Unset
from typing import cast
from typing import Union



def _get_kwargs(
    *,
    body: Union[
        NotebookEntries,
        NotebookEntries,
        NotebookEntries,
    ],
    entry_id: Union[Unset, str] = UNSET,
    entry_key: Union[Unset, str] = UNSET,
    title: Union[Unset, str] = UNSET,
    description: Union[Unset, str] = UNSET,
    primary_scope_id: Union[Unset, str] = UNSET,
    status: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    submitted_at: Union[Unset, str] = UNSET,
    submitted_by: Union[Unset, str] = UNSET,
    locked_at: Union[Unset, str] = UNSET,
    locked_by: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    updated_at: Union[Unset, str] = UNSET,
    updated_by: Union[Unset, str] = UNSET,
    prefer: Union[Unset, PatchNotebookEntriesPrefer] = UNSET,

) -> dict[str, Any]:
    headers: dict[str, Any] = {}
    if not isinstance(prefer, Unset):
        headers["Prefer"] = str(prefer)




    

    params: dict[str, Any] = {}

    params["entry_id"] = entry_id

    params["entry_key"] = entry_key

    params["title"] = title

    params["description"] = description

    params["primary_scope_id"] = primary_scope_id

    params["status"] = status

    params["metadata"] = metadata

    params["submitted_at"] = submitted_at

    params["submitted_by"] = submitted_by

    params["locked_at"] = locked_at

    params["locked_by"] = locked_by

    params["created_at"] = created_at

    params["created_by"] = created_by

    params["updated_at"] = updated_at

    params["updated_by"] = updated_by


    params = {k: v for k, v in params.items() if v is not UNSET and v is not None}


    _kwargs: dict[str, Any] = {
        "method": "patch",
        "url": "/notebook_entries",
        "params": params,
    }

    if isinstance(body, NotebookEntries):
        _kwargs["json"] = body.to_dict()


        headers["Content-Type"] = "application/json"
    if isinstance(body, NotebookEntries):
        _kwargs["json"] = body.to_dict()


        headers["Content-Type"] = "application/vnd.pgrst.object+json;nulls=stripped"
    if isinstance(body, NotebookEntries):
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
        NotebookEntries,
        NotebookEntries,
        NotebookEntries,
    ],
    entry_id: Union[Unset, str] = UNSET,
    entry_key: Union[Unset, str] = UNSET,
    title: Union[Unset, str] = UNSET,
    description: Union[Unset, str] = UNSET,
    primary_scope_id: Union[Unset, str] = UNSET,
    status: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    submitted_at: Union[Unset, str] = UNSET,
    submitted_by: Union[Unset, str] = UNSET,
    locked_at: Union[Unset, str] = UNSET,
    locked_by: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    updated_at: Union[Unset, str] = UNSET,
    updated_by: Union[Unset, str] = UNSET,
    prefer: Union[Unset, PatchNotebookEntriesPrefer] = UNSET,

) -> Response[Any]:
    """ @omit

    Args:
        entry_id (Union[Unset, str]):
        entry_key (Union[Unset, str]):
        title (Union[Unset, str]):
        description (Union[Unset, str]):
        primary_scope_id (Union[Unset, str]):
        status (Union[Unset, str]):
        metadata (Union[Unset, str]):
        submitted_at (Union[Unset, str]):
        submitted_by (Union[Unset, str]):
        locked_at (Union[Unset, str]):
        locked_by (Union[Unset, str]):
        created_at (Union[Unset, str]):
        created_by (Union[Unset, str]):
        updated_at (Union[Unset, str]):
        updated_by (Union[Unset, str]):
        prefer (Union[Unset, PatchNotebookEntriesPrefer]):
        body (NotebookEntries): @omit
        body (NotebookEntries): @omit
        body (NotebookEntries): @omit

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        body=body,
entry_id=entry_id,
entry_key=entry_key,
title=title,
description=description,
primary_scope_id=primary_scope_id,
status=status,
metadata=metadata,
submitted_at=submitted_at,
submitted_by=submitted_by,
locked_at=locked_at,
locked_by=locked_by,
created_at=created_at,
created_by=created_by,
updated_at=updated_at,
updated_by=updated_by,
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
        NotebookEntries,
        NotebookEntries,
        NotebookEntries,
    ],
    entry_id: Union[Unset, str] = UNSET,
    entry_key: Union[Unset, str] = UNSET,
    title: Union[Unset, str] = UNSET,
    description: Union[Unset, str] = UNSET,
    primary_scope_id: Union[Unset, str] = UNSET,
    status: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    submitted_at: Union[Unset, str] = UNSET,
    submitted_by: Union[Unset, str] = UNSET,
    locked_at: Union[Unset, str] = UNSET,
    locked_by: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    updated_at: Union[Unset, str] = UNSET,
    updated_by: Union[Unset, str] = UNSET,
    prefer: Union[Unset, PatchNotebookEntriesPrefer] = UNSET,

) -> Response[Any]:
    """ @omit

    Args:
        entry_id (Union[Unset, str]):
        entry_key (Union[Unset, str]):
        title (Union[Unset, str]):
        description (Union[Unset, str]):
        primary_scope_id (Union[Unset, str]):
        status (Union[Unset, str]):
        metadata (Union[Unset, str]):
        submitted_at (Union[Unset, str]):
        submitted_by (Union[Unset, str]):
        locked_at (Union[Unset, str]):
        locked_by (Union[Unset, str]):
        created_at (Union[Unset, str]):
        created_by (Union[Unset, str]):
        updated_at (Union[Unset, str]):
        updated_by (Union[Unset, str]):
        prefer (Union[Unset, PatchNotebookEntriesPrefer]):
        body (NotebookEntries): @omit
        body (NotebookEntries): @omit
        body (NotebookEntries): @omit

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        body=body,
entry_id=entry_id,
entry_key=entry_key,
title=title,
description=description,
primary_scope_id=primary_scope_id,
status=status,
metadata=metadata,
submitted_at=submitted_at,
submitted_by=submitted_by,
locked_at=locked_at,
locked_by=locked_by,
created_at=created_at,
created_by=created_by,
updated_at=updated_at,
updated_by=updated_by,
prefer=prefer,

    )

    response = await client.get_async_httpx_client().request(
        **kwargs
    )

    return _build_response(client=client, response=response)

