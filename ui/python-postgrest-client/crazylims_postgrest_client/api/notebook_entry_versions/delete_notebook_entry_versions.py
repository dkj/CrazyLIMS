from http import HTTPStatus
from typing import Any, Optional, Union, cast

import httpx

from ...client import AuthenticatedClient, Client
from ...types import Response, UNSET
from ... import errors

from ...models.delete_notebook_entry_versions_prefer import DeleteNotebookEntryVersionsPrefer
from ...types import UNSET, Unset
from typing import Union



def _get_kwargs(
    *,
    version_id: Union[Unset, str] = UNSET,
    entry_id: Union[Unset, str] = UNSET,
    version_number: Union[Unset, str] = UNSET,
    notebook_json: Union[Unset, str] = UNSET,
    checksum: Union[Unset, str] = UNSET,
    note: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    prefer: Union[Unset, DeleteNotebookEntryVersionsPrefer] = UNSET,

) -> dict[str, Any]:
    headers: dict[str, Any] = {}
    if not isinstance(prefer, Unset):
        headers["Prefer"] = str(prefer)




    

    params: dict[str, Any] = {}

    params["version_id"] = version_id

    params["entry_id"] = entry_id

    params["version_number"] = version_number

    params["notebook_json"] = notebook_json

    params["checksum"] = checksum

    params["note"] = note

    params["metadata"] = metadata

    params["created_at"] = created_at

    params["created_by"] = created_by


    params = {k: v for k, v in params.items() if v is not UNSET and v is not None}


    _kwargs: dict[str, Any] = {
        "method": "delete",
        "url": "/notebook_entry_versions",
        "params": params,
    }


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
    version_id: Union[Unset, str] = UNSET,
    entry_id: Union[Unset, str] = UNSET,
    version_number: Union[Unset, str] = UNSET,
    notebook_json: Union[Unset, str] = UNSET,
    checksum: Union[Unset, str] = UNSET,
    note: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    prefer: Union[Unset, DeleteNotebookEntryVersionsPrefer] = UNSET,

) -> Response[Any]:
    """ @omit

    Args:
        version_id (Union[Unset, str]):
        entry_id (Union[Unset, str]):
        version_number (Union[Unset, str]):
        notebook_json (Union[Unset, str]):
        checksum (Union[Unset, str]):
        note (Union[Unset, str]):
        metadata (Union[Unset, str]):
        created_at (Union[Unset, str]):
        created_by (Union[Unset, str]):
        prefer (Union[Unset, DeleteNotebookEntryVersionsPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        version_id=version_id,
entry_id=entry_id,
version_number=version_number,
notebook_json=notebook_json,
checksum=checksum,
note=note,
metadata=metadata,
created_at=created_at,
created_by=created_by,
prefer=prefer,

    )

    response = client.get_httpx_client().request(
        **kwargs,
    )

    return _build_response(client=client, response=response)


async def asyncio_detailed(
    *,
    client: Union[AuthenticatedClient, Client],
    version_id: Union[Unset, str] = UNSET,
    entry_id: Union[Unset, str] = UNSET,
    version_number: Union[Unset, str] = UNSET,
    notebook_json: Union[Unset, str] = UNSET,
    checksum: Union[Unset, str] = UNSET,
    note: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    prefer: Union[Unset, DeleteNotebookEntryVersionsPrefer] = UNSET,

) -> Response[Any]:
    """ @omit

    Args:
        version_id (Union[Unset, str]):
        entry_id (Union[Unset, str]):
        version_number (Union[Unset, str]):
        notebook_json (Union[Unset, str]):
        checksum (Union[Unset, str]):
        note (Union[Unset, str]):
        metadata (Union[Unset, str]):
        created_at (Union[Unset, str]):
        created_by (Union[Unset, str]):
        prefer (Union[Unset, DeleteNotebookEntryVersionsPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        version_id=version_id,
entry_id=entry_id,
version_number=version_number,
notebook_json=notebook_json,
checksum=checksum,
note=note,
metadata=metadata,
created_at=created_at,
created_by=created_by,
prefer=prefer,

    )

    response = await client.get_async_httpx_client().request(
        **kwargs
    )

    return _build_response(client=client, response=response)

