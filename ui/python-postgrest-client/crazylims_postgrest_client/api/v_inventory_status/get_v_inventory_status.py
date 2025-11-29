from http import HTTPStatus
from typing import Any, Optional, Union, cast

import httpx

from ...client import AuthenticatedClient, Client
from ...types import Response, UNSET
from ... import errors

from ...models.get_v_inventory_status_prefer import GetVInventoryStatusPrefer
from ...models.v_inventory_status import VInventoryStatus
from ...types import UNSET, Unset
from typing import cast
from typing import Union



def _get_kwargs(
    *,
    id: Union[Unset, str] = UNSET,
    name: Union[Unset, str] = UNSET,
    barcode: Union[Unset, str] = UNSET,
    quantity: Union[Unset, str] = UNSET,
    unit: Union[Unset, str] = UNSET,
    minimum_quantity: Union[Unset, str] = UNSET,
    below_threshold: Union[Unset, str] = UNSET,
    expires_at: Union[Unset, str] = UNSET,
    storage_sublocation_id: Union[Unset, str] = UNSET,
    storage_path: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVInventoryStatusPrefer] = UNSET,

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

    params["name"] = name

    params["barcode"] = barcode

    params["quantity"] = quantity

    params["unit"] = unit

    params["minimum_quantity"] = minimum_quantity

    params["below_threshold"] = below_threshold

    params["expires_at"] = expires_at

    params["storage_sublocation_id"] = storage_sublocation_id

    params["storage_path"] = storage_path

    params["select"] = select

    params["order"] = order

    params["offset"] = offset

    params["limit"] = limit


    params = {k: v for k, v in params.items() if v is not UNSET and v is not None}


    _kwargs: dict[str, Any] = {
        "method": "get",
        "url": "/v_inventory_status",
        "params": params,
    }


    _kwargs["headers"] = headers
    return _kwargs



def _parse_response(*, client: Union[AuthenticatedClient, Client], response: httpx.Response) -> Optional[Union[Any, list['VInventoryStatus']]]:
    if response.status_code == 200:
        response_200 = []
        _response_200 = response.json()
        for response_200_item_data in (_response_200):
            response_200_item = VInventoryStatus.from_dict(response_200_item_data)



            response_200.append(response_200_item)

        return response_200

    if response.status_code == 206:
        response_206 = cast(Any, None)
        return response_206

    if client.raise_on_unexpected_status:
        raise errors.UnexpectedStatus(response.status_code, response.content)
    else:
        return None


def _build_response(*, client: Union[AuthenticatedClient, Client], response: httpx.Response) -> Response[Union[Any, list['VInventoryStatus']]]:
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
    name: Union[Unset, str] = UNSET,
    barcode: Union[Unset, str] = UNSET,
    quantity: Union[Unset, str] = UNSET,
    unit: Union[Unset, str] = UNSET,
    minimum_quantity: Union[Unset, str] = UNSET,
    below_threshold: Union[Unset, str] = UNSET,
    expires_at: Union[Unset, str] = UNSET,
    storage_sublocation_id: Union[Unset, str] = UNSET,
    storage_path: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVInventoryStatusPrefer] = UNSET,

) -> Response[Union[Any, list['VInventoryStatus']]]:
    """ 
    Args:
        id (Union[Unset, str]):
        name (Union[Unset, str]):
        barcode (Union[Unset, str]):
        quantity (Union[Unset, str]):
        unit (Union[Unset, str]):
        minimum_quantity (Union[Unset, str]):
        below_threshold (Union[Unset, str]):
        expires_at (Union[Unset, str]):
        storage_sublocation_id (Union[Unset, str]):
        storage_path (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVInventoryStatusPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Union[Any, list['VInventoryStatus']]]
     """


    kwargs = _get_kwargs(
        id=id,
name=name,
barcode=barcode,
quantity=quantity,
unit=unit,
minimum_quantity=minimum_quantity,
below_threshold=below_threshold,
expires_at=expires_at,
storage_sublocation_id=storage_sublocation_id,
storage_path=storage_path,
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
    id: Union[Unset, str] = UNSET,
    name: Union[Unset, str] = UNSET,
    barcode: Union[Unset, str] = UNSET,
    quantity: Union[Unset, str] = UNSET,
    unit: Union[Unset, str] = UNSET,
    minimum_quantity: Union[Unset, str] = UNSET,
    below_threshold: Union[Unset, str] = UNSET,
    expires_at: Union[Unset, str] = UNSET,
    storage_sublocation_id: Union[Unset, str] = UNSET,
    storage_path: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVInventoryStatusPrefer] = UNSET,

) -> Optional[Union[Any, list['VInventoryStatus']]]:
    """ 
    Args:
        id (Union[Unset, str]):
        name (Union[Unset, str]):
        barcode (Union[Unset, str]):
        quantity (Union[Unset, str]):
        unit (Union[Unset, str]):
        minimum_quantity (Union[Unset, str]):
        below_threshold (Union[Unset, str]):
        expires_at (Union[Unset, str]):
        storage_sublocation_id (Union[Unset, str]):
        storage_path (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVInventoryStatusPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Union[Any, list['VInventoryStatus']]
     """


    return sync_detailed(
        client=client,
id=id,
name=name,
barcode=barcode,
quantity=quantity,
unit=unit,
minimum_quantity=minimum_quantity,
below_threshold=below_threshold,
expires_at=expires_at,
storage_sublocation_id=storage_sublocation_id,
storage_path=storage_path,
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
    id: Union[Unset, str] = UNSET,
    name: Union[Unset, str] = UNSET,
    barcode: Union[Unset, str] = UNSET,
    quantity: Union[Unset, str] = UNSET,
    unit: Union[Unset, str] = UNSET,
    minimum_quantity: Union[Unset, str] = UNSET,
    below_threshold: Union[Unset, str] = UNSET,
    expires_at: Union[Unset, str] = UNSET,
    storage_sublocation_id: Union[Unset, str] = UNSET,
    storage_path: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVInventoryStatusPrefer] = UNSET,

) -> Response[Union[Any, list['VInventoryStatus']]]:
    """ 
    Args:
        id (Union[Unset, str]):
        name (Union[Unset, str]):
        barcode (Union[Unset, str]):
        quantity (Union[Unset, str]):
        unit (Union[Unset, str]):
        minimum_quantity (Union[Unset, str]):
        below_threshold (Union[Unset, str]):
        expires_at (Union[Unset, str]):
        storage_sublocation_id (Union[Unset, str]):
        storage_path (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVInventoryStatusPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Union[Any, list['VInventoryStatus']]]
     """


    kwargs = _get_kwargs(
        id=id,
name=name,
barcode=barcode,
quantity=quantity,
unit=unit,
minimum_quantity=minimum_quantity,
below_threshold=below_threshold,
expires_at=expires_at,
storage_sublocation_id=storage_sublocation_id,
storage_path=storage_path,
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
    id: Union[Unset, str] = UNSET,
    name: Union[Unset, str] = UNSET,
    barcode: Union[Unset, str] = UNSET,
    quantity: Union[Unset, str] = UNSET,
    unit: Union[Unset, str] = UNSET,
    minimum_quantity: Union[Unset, str] = UNSET,
    below_threshold: Union[Unset, str] = UNSET,
    expires_at: Union[Unset, str] = UNSET,
    storage_sublocation_id: Union[Unset, str] = UNSET,
    storage_path: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVInventoryStatusPrefer] = UNSET,

) -> Optional[Union[Any, list['VInventoryStatus']]]:
    """ 
    Args:
        id (Union[Unset, str]):
        name (Union[Unset, str]):
        barcode (Union[Unset, str]):
        quantity (Union[Unset, str]):
        unit (Union[Unset, str]):
        minimum_quantity (Union[Unset, str]):
        below_threshold (Union[Unset, str]):
        expires_at (Union[Unset, str]):
        storage_sublocation_id (Union[Unset, str]):
        storage_path (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVInventoryStatusPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Union[Any, list['VInventoryStatus']]
     """


    return (await asyncio_detailed(
        client=client,
id=id,
name=name,
barcode=barcode,
quantity=quantity,
unit=unit,
minimum_quantity=minimum_quantity,
below_threshold=below_threshold,
expires_at=expires_at,
storage_sublocation_id=storage_sublocation_id,
storage_path=storage_path,
select=select,
order=order,
offset=offset,
limit=limit,
range_=range_,
range_unit=range_unit,
prefer=prefer,

    )).parsed
