from http import HTTPStatus
from typing import Any, Optional, Union, cast

import httpx

from ...client import AuthenticatedClient, Client
from ...types import Response, UNSET
from ... import errors

from ...models.delete_artefact_relationships_prefer import DeleteArtefactRelationshipsPrefer
from ...types import UNSET, Unset
from typing import Union



def _get_kwargs(
    *,
    relationship_id: Union[Unset, str] = UNSET,
    parent_artefact_id: Union[Unset, str] = UNSET,
    child_artefact_id: Union[Unset, str] = UNSET,
    relationship_type: Union[Unset, str] = UNSET,
    process_instance_id: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    prefer: Union[Unset, DeleteArtefactRelationshipsPrefer] = UNSET,

) -> dict[str, Any]:
    headers: dict[str, Any] = {}
    if not isinstance(prefer, Unset):
        headers["Prefer"] = str(prefer)




    

    params: dict[str, Any] = {}

    params["relationship_id"] = relationship_id

    params["parent_artefact_id"] = parent_artefact_id

    params["child_artefact_id"] = child_artefact_id

    params["relationship_type"] = relationship_type

    params["process_instance_id"] = process_instance_id

    params["metadata"] = metadata

    params["created_at"] = created_at

    params["created_by"] = created_by


    params = {k: v for k, v in params.items() if v is not UNSET and v is not None}


    _kwargs: dict[str, Any] = {
        "method": "delete",
        "url": "/artefact_relationships",
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
    relationship_id: Union[Unset, str] = UNSET,
    parent_artefact_id: Union[Unset, str] = UNSET,
    child_artefact_id: Union[Unset, str] = UNSET,
    relationship_type: Union[Unset, str] = UNSET,
    process_instance_id: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    prefer: Union[Unset, DeleteArtefactRelationshipsPrefer] = UNSET,

) -> Response[Any]:
    """ 
    Args:
        relationship_id (Union[Unset, str]):
        parent_artefact_id (Union[Unset, str]):
        child_artefact_id (Union[Unset, str]):
        relationship_type (Union[Unset, str]):
        process_instance_id (Union[Unset, str]):
        metadata (Union[Unset, str]):
        created_at (Union[Unset, str]):
        created_by (Union[Unset, str]):
        prefer (Union[Unset, DeleteArtefactRelationshipsPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        relationship_id=relationship_id,
parent_artefact_id=parent_artefact_id,
child_artefact_id=child_artefact_id,
relationship_type=relationship_type,
process_instance_id=process_instance_id,
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
    relationship_id: Union[Unset, str] = UNSET,
    parent_artefact_id: Union[Unset, str] = UNSET,
    child_artefact_id: Union[Unset, str] = UNSET,
    relationship_type: Union[Unset, str] = UNSET,
    process_instance_id: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    prefer: Union[Unset, DeleteArtefactRelationshipsPrefer] = UNSET,

) -> Response[Any]:
    """ 
    Args:
        relationship_id (Union[Unset, str]):
        parent_artefact_id (Union[Unset, str]):
        child_artefact_id (Union[Unset, str]):
        relationship_type (Union[Unset, str]):
        process_instance_id (Union[Unset, str]):
        metadata (Union[Unset, str]):
        created_at (Union[Unset, str]):
        created_by (Union[Unset, str]):
        prefer (Union[Unset, DeleteArtefactRelationshipsPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        relationship_id=relationship_id,
parent_artefact_id=parent_artefact_id,
child_artefact_id=child_artefact_id,
relationship_type=relationship_type,
process_instance_id=process_instance_id,
metadata=metadata,
created_at=created_at,
created_by=created_by,
prefer=prefer,

    )

    response = await client.get_async_httpx_client().request(
        **kwargs
    )

    return _build_response(client=client, response=response)

