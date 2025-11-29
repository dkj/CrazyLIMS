from http import HTTPStatus
from typing import Any, Optional, Union, cast

import httpx

from ...client import AuthenticatedClient, Client
from ...types import Response, UNSET
from ... import errors

from ...models.artefact_scopes import ArtefactScopes
from ...models.get_artefact_scopes_prefer import GetArtefactScopesPrefer
from ...types import UNSET, Unset
from typing import cast
from typing import Union



def _get_kwargs(
    *,
    artefact_id: Union[Unset, str] = UNSET,
    scope_id: Union[Unset, str] = UNSET,
    relationship: Union[Unset, str] = UNSET,
    assigned_at: Union[Unset, str] = UNSET,
    assigned_by: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetArtefactScopesPrefer] = UNSET,

) -> dict[str, Any]:
    headers: dict[str, Any] = {}
    if not isinstance(range_, Unset):
        headers["Range"] = range_

    if not isinstance(range_unit, Unset):
        headers["Range-Unit"] = range_unit

    if not isinstance(prefer, Unset):
        headers["Prefer"] = str(prefer)




    

    params: dict[str, Any] = {}

    params["artefact_id"] = artefact_id

    params["scope_id"] = scope_id

    params["relationship"] = relationship

    params["assigned_at"] = assigned_at

    params["assigned_by"] = assigned_by

    params["metadata"] = metadata

    params["select"] = select

    params["order"] = order

    params["offset"] = offset

    params["limit"] = limit


    params = {k: v for k, v in params.items() if v is not UNSET and v is not None}


    _kwargs: dict[str, Any] = {
        "method": "get",
        "url": "/artefact_scopes",
        "params": params,
    }


    _kwargs["headers"] = headers
    return _kwargs



def _parse_response(*, client: Union[AuthenticatedClient, Client], response: httpx.Response) -> Optional[Union[Any, list['ArtefactScopes']]]:
    if response.status_code == 200:
        response_200 = []
        _response_200 = response.json()
        for response_200_item_data in (_response_200):
            response_200_item = ArtefactScopes.from_dict(response_200_item_data)



            response_200.append(response_200_item)

        return response_200

    if response.status_code == 206:
        response_206 = cast(Any, None)
        return response_206

    if client.raise_on_unexpected_status:
        raise errors.UnexpectedStatus(response.status_code, response.content)
    else:
        return None


def _build_response(*, client: Union[AuthenticatedClient, Client], response: httpx.Response) -> Response[Union[Any, list['ArtefactScopes']]]:
    return Response(
        status_code=HTTPStatus(response.status_code),
        content=response.content,
        headers=response.headers,
        parsed=_parse_response(client=client, response=response),
    )


def sync_detailed(
    *,
    client: Union[AuthenticatedClient, Client],
    artefact_id: Union[Unset, str] = UNSET,
    scope_id: Union[Unset, str] = UNSET,
    relationship: Union[Unset, str] = UNSET,
    assigned_at: Union[Unset, str] = UNSET,
    assigned_by: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetArtefactScopesPrefer] = UNSET,

) -> Response[Union[Any, list['ArtefactScopes']]]:
    """ 
    Args:
        artefact_id (Union[Unset, str]):
        scope_id (Union[Unset, str]):
        relationship (Union[Unset, str]):
        assigned_at (Union[Unset, str]):
        assigned_by (Union[Unset, str]):
        metadata (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetArtefactScopesPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Union[Any, list['ArtefactScopes']]]
     """


    kwargs = _get_kwargs(
        artefact_id=artefact_id,
scope_id=scope_id,
relationship=relationship,
assigned_at=assigned_at,
assigned_by=assigned_by,
metadata=metadata,
select=select,
order=order,
offset=offset,
limit=limit,
range_=range_,
range_unit=range_unit,
prefer=prefer,

    )

    response = client.get_httpx_client().request(
        **kwargs,
    )

    return _build_response(client=client, response=response)

def sync(
    *,
    client: Union[AuthenticatedClient, Client],
    artefact_id: Union[Unset, str] = UNSET,
    scope_id: Union[Unset, str] = UNSET,
    relationship: Union[Unset, str] = UNSET,
    assigned_at: Union[Unset, str] = UNSET,
    assigned_by: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetArtefactScopesPrefer] = UNSET,

) -> Optional[Union[Any, list['ArtefactScopes']]]:
    """ 
    Args:
        artefact_id (Union[Unset, str]):
        scope_id (Union[Unset, str]):
        relationship (Union[Unset, str]):
        assigned_at (Union[Unset, str]):
        assigned_by (Union[Unset, str]):
        metadata (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetArtefactScopesPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Union[Any, list['ArtefactScopes']]
     """


    return sync_detailed(
        client=client,
artefact_id=artefact_id,
scope_id=scope_id,
relationship=relationship,
assigned_at=assigned_at,
assigned_by=assigned_by,
metadata=metadata,
select=select,
order=order,
offset=offset,
limit=limit,
range_=range_,
range_unit=range_unit,
prefer=prefer,

    ).parsed

async def asyncio_detailed(
    *,
    client: Union[AuthenticatedClient, Client],
    artefact_id: Union[Unset, str] = UNSET,
    scope_id: Union[Unset, str] = UNSET,
    relationship: Union[Unset, str] = UNSET,
    assigned_at: Union[Unset, str] = UNSET,
    assigned_by: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetArtefactScopesPrefer] = UNSET,

) -> Response[Union[Any, list['ArtefactScopes']]]:
    """ 
    Args:
        artefact_id (Union[Unset, str]):
        scope_id (Union[Unset, str]):
        relationship (Union[Unset, str]):
        assigned_at (Union[Unset, str]):
        assigned_by (Union[Unset, str]):
        metadata (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetArtefactScopesPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Union[Any, list['ArtefactScopes']]]
     """


    kwargs = _get_kwargs(
        artefact_id=artefact_id,
scope_id=scope_id,
relationship=relationship,
assigned_at=assigned_at,
assigned_by=assigned_by,
metadata=metadata,
select=select,
order=order,
offset=offset,
limit=limit,
range_=range_,
range_unit=range_unit,
prefer=prefer,

    )

    response = await client.get_async_httpx_client().request(
        **kwargs
    )

    return _build_response(client=client, response=response)

async def asyncio(
    *,
    client: Union[AuthenticatedClient, Client],
    artefact_id: Union[Unset, str] = UNSET,
    scope_id: Union[Unset, str] = UNSET,
    relationship: Union[Unset, str] = UNSET,
    assigned_at: Union[Unset, str] = UNSET,
    assigned_by: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetArtefactScopesPrefer] = UNSET,

) -> Optional[Union[Any, list['ArtefactScopes']]]:
    """ 
    Args:
        artefact_id (Union[Unset, str]):
        scope_id (Union[Unset, str]):
        relationship (Union[Unset, str]):
        assigned_at (Union[Unset, str]):
        assigned_by (Union[Unset, str]):
        metadata (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetArtefactScopesPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Union[Any, list['ArtefactScopes']]
     """


    return (await asyncio_detailed(
        client=client,
artefact_id=artefact_id,
scope_id=scope_id,
relationship=relationship,
assigned_at=assigned_at,
assigned_by=assigned_by,
metadata=metadata,
select=select,
order=order,
offset=offset,
limit=limit,
range_=range_,
range_unit=range_unit,
prefer=prefer,

    )).parsed
