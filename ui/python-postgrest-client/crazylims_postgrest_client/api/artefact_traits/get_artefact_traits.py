from http import HTTPStatus
from typing import Any, Optional, Union, cast

import httpx

from ...client import AuthenticatedClient, Client
from ...types import Response, UNSET
from ... import errors

from ...models.get_artefact_traits_prefer import GetArtefactTraitsPrefer
from ...types import UNSET, Unset
from typing import Union



def _get_kwargs(
    *,
    trait_id: Union[Unset, str] = UNSET,
    trait_key: Union[Unset, str] = UNSET,
    display_name: Union[Unset, str] = UNSET,
    description: Union[Unset, str] = UNSET,
    data_type: Union[Unset, str] = UNSET,
    allowed_values: Union[Unset, str] = UNSET,
    default_value: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    updated_at: Union[Unset, str] = UNSET,
    updated_by: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetArtefactTraitsPrefer] = UNSET,

) -> dict[str, Any]:
    headers: dict[str, Any] = {}
    if not isinstance(range_, Unset):
        headers["Range"] = range_

    if not isinstance(range_unit, Unset):
        headers["Range-Unit"] = range_unit

    if not isinstance(prefer, Unset):
        headers["Prefer"] = str(prefer)




    

    params: dict[str, Any] = {}

    params["trait_id"] = trait_id

    params["trait_key"] = trait_key

    params["display_name"] = display_name

    params["description"] = description

    params["data_type"] = data_type

    params["allowed_values"] = allowed_values

    params["default_value"] = default_value

    params["metadata"] = metadata

    params["created_at"] = created_at

    params["created_by"] = created_by

    params["updated_at"] = updated_at

    params["updated_by"] = updated_by

    params["select"] = select

    params["order"] = order

    params["offset"] = offset

    params["limit"] = limit


    params = {k: v for k, v in params.items() if v is not UNSET and v is not None}


    _kwargs: dict[str, Any] = {
        "method": "get",
        "url": "/artefact_traits",
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
    trait_id: Union[Unset, str] = UNSET,
    trait_key: Union[Unset, str] = UNSET,
    display_name: Union[Unset, str] = UNSET,
    description: Union[Unset, str] = UNSET,
    data_type: Union[Unset, str] = UNSET,
    allowed_values: Union[Unset, str] = UNSET,
    default_value: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    updated_at: Union[Unset, str] = UNSET,
    updated_by: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetArtefactTraitsPrefer] = UNSET,

) -> Response[Any]:
    """ 
    Args:
        trait_id (Union[Unset, str]):
        trait_key (Union[Unset, str]):
        display_name (Union[Unset, str]):
        description (Union[Unset, str]):
        data_type (Union[Unset, str]):
        allowed_values (Union[Unset, str]):
        default_value (Union[Unset, str]):
        metadata (Union[Unset, str]):
        created_at (Union[Unset, str]):
        created_by (Union[Unset, str]):
        updated_at (Union[Unset, str]):
        updated_by (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetArtefactTraitsPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        trait_id=trait_id,
trait_key=trait_key,
display_name=display_name,
description=description,
data_type=data_type,
allowed_values=allowed_values,
default_value=default_value,
metadata=metadata,
created_at=created_at,
created_by=created_by,
updated_at=updated_at,
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
    trait_id: Union[Unset, str] = UNSET,
    trait_key: Union[Unset, str] = UNSET,
    display_name: Union[Unset, str] = UNSET,
    description: Union[Unset, str] = UNSET,
    data_type: Union[Unset, str] = UNSET,
    allowed_values: Union[Unset, str] = UNSET,
    default_value: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    updated_at: Union[Unset, str] = UNSET,
    updated_by: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetArtefactTraitsPrefer] = UNSET,

) -> Response[Any]:
    """ 
    Args:
        trait_id (Union[Unset, str]):
        trait_key (Union[Unset, str]):
        display_name (Union[Unset, str]):
        description (Union[Unset, str]):
        data_type (Union[Unset, str]):
        allowed_values (Union[Unset, str]):
        default_value (Union[Unset, str]):
        metadata (Union[Unset, str]):
        created_at (Union[Unset, str]):
        created_by (Union[Unset, str]):
        updated_at (Union[Unset, str]):
        updated_by (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetArtefactTraitsPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        trait_id=trait_id,
trait_key=trait_key,
display_name=display_name,
description=description,
data_type=data_type,
allowed_values=allowed_values,
default_value=default_value,
metadata=metadata,
created_at=created_at,
created_by=created_by,
updated_at=updated_at,
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

