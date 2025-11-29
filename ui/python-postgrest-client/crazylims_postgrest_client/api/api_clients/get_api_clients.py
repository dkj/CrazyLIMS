from http import HTTPStatus
from typing import Any, Optional, Union, cast

import httpx

from ...client import AuthenticatedClient, Client
from ...types import Response, UNSET
from ... import errors

from ...models.get_api_clients_prefer import GetApiClientsPrefer
from ...types import UNSET, Unset
from typing import Union



def _get_kwargs(
    *,
    id: Union[Unset, str] = UNSET,
    client_identifier: Union[Unset, str] = UNSET,
    display_name: Union[Unset, str] = UNSET,
    description: Union[Unset, str] = UNSET,
    contact_email: Union[Unset, str] = UNSET,
    allowed_roles: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    updated_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    updated_by: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetApiClientsPrefer] = UNSET,

) -> dict[str, Any]:
    headers: dict[str, Any] = {}
    if not isinstance(range_, Unset):
        headers["Range"] = range_

    if not isinstance(range_unit, Unset):
        headers["Range-Unit"] = range_unit

    if not isinstance(prefer, Unset):
        headers["Prefer"] = str(prefer)




    

    params: dict[str, Any] = {}

    params["id"] = id

    params["client_identifier"] = client_identifier

    params["display_name"] = display_name

    params["description"] = description

    params["contact_email"] = contact_email

    params["allowed_roles"] = allowed_roles

    params["metadata"] = metadata

    params["created_at"] = created_at

    params["updated_at"] = updated_at

    params["created_by"] = created_by

    params["updated_by"] = updated_by

    params["select"] = select

    params["order"] = order

    params["offset"] = offset

    params["limit"] = limit


    params = {k: v for k, v in params.items() if v is not UNSET and v is not None}


    _kwargs: dict[str, Any] = {
        "method": "get",
        "url": "/api_clients",
        "params": params,
    }


    _kwargs["headers"] = headers
    return _kwargs



def _parse_response(*, client: Union[AuthenticatedClient, Client], response: httpx.Response) -> Optional[Any]:
    if response.status_code == 206:
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
    id: Union[Unset, str] = UNSET,
    client_identifier: Union[Unset, str] = UNSET,
    display_name: Union[Unset, str] = UNSET,
    description: Union[Unset, str] = UNSET,
    contact_email: Union[Unset, str] = UNSET,
    allowed_roles: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    updated_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    updated_by: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetApiClientsPrefer] = UNSET,

) -> Response[Any]:
    """ 
    Args:
        id (Union[Unset, str]):
        client_identifier (Union[Unset, str]):
        display_name (Union[Unset, str]):
        description (Union[Unset, str]):
        contact_email (Union[Unset, str]):
        allowed_roles (Union[Unset, str]):
        metadata (Union[Unset, str]):
        created_at (Union[Unset, str]):
        updated_at (Union[Unset, str]):
        created_by (Union[Unset, str]):
        updated_by (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetApiClientsPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        id=id,
client_identifier=client_identifier,
display_name=display_name,
description=description,
contact_email=contact_email,
allowed_roles=allowed_roles,
metadata=metadata,
created_at=created_at,
updated_at=updated_at,
created_by=created_by,
updated_by=updated_by,
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


async def asyncio_detailed(
    *,
    client: Union[AuthenticatedClient, Client],
    id: Union[Unset, str] = UNSET,
    client_identifier: Union[Unset, str] = UNSET,
    display_name: Union[Unset, str] = UNSET,
    description: Union[Unset, str] = UNSET,
    contact_email: Union[Unset, str] = UNSET,
    allowed_roles: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    updated_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    updated_by: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetApiClientsPrefer] = UNSET,

) -> Response[Any]:
    """ 
    Args:
        id (Union[Unset, str]):
        client_identifier (Union[Unset, str]):
        display_name (Union[Unset, str]):
        description (Union[Unset, str]):
        contact_email (Union[Unset, str]):
        allowed_roles (Union[Unset, str]):
        metadata (Union[Unset, str]):
        created_at (Union[Unset, str]):
        updated_at (Union[Unset, str]):
        created_by (Union[Unset, str]):
        updated_by (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetApiClientsPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        id=id,
client_identifier=client_identifier,
display_name=display_name,
description=description,
contact_email=contact_email,
allowed_roles=allowed_roles,
metadata=metadata,
created_at=created_at,
updated_at=updated_at,
created_by=created_by,
updated_by=updated_by,
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

