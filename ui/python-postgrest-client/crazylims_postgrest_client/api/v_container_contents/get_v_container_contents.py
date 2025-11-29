from http import HTTPStatus
from typing import Any, Optional, Union, cast

import httpx

from ...client import AuthenticatedClient, Client
from ...types import Response, UNSET
from ... import errors

from ...models.get_v_container_contents_prefer import GetVContainerContentsPrefer
from ...models.v_container_contents import VContainerContents
from ...types import UNSET, Unset
from typing import cast
from typing import Union



def _get_kwargs(
    *,
    container_artefact_id: Union[Unset, str] = UNSET,
    container_name: Union[Unset, str] = UNSET,
    container_status: Union[Unset, str] = UNSET,
    container_slot_id: Union[Unset, str] = UNSET,
    slot_name: Union[Unset, str] = UNSET,
    slot_display_name: Union[Unset, str] = UNSET,
    position: Union[Unset, str] = UNSET,
    artefact_id: Union[Unset, str] = UNSET,
    artefact_name: Union[Unset, str] = UNSET,
    artefact_status: Union[Unset, str] = UNSET,
    quantity: Union[Unset, str] = UNSET,
    quantity_unit: Union[Unset, str] = UNSET,
    occupied_at: Union[Unset, str] = UNSET,
    last_updated_at: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVContainerContentsPrefer] = UNSET,

) -> dict[str, Any]:
    headers: dict[str, Any] = {}
    if not isinstance(range_, Unset):
        headers["Range"] = range_

    if not isinstance(range_unit, Unset):
        headers["Range-Unit"] = range_unit

    if not isinstance(prefer, Unset):
        headers["Prefer"] = str(prefer)




    

    params: dict[str, Any] = {}

    params["container_artefact_id"] = container_artefact_id

    params["container_name"] = container_name

    params["container_status"] = container_status

    params["container_slot_id"] = container_slot_id

    params["slot_name"] = slot_name

    params["slot_display_name"] = slot_display_name

    params["position"] = position

    params["artefact_id"] = artefact_id

    params["artefact_name"] = artefact_name

    params["artefact_status"] = artefact_status

    params["quantity"] = quantity

    params["quantity_unit"] = quantity_unit

    params["occupied_at"] = occupied_at

    params["last_updated_at"] = last_updated_at

    params["select"] = select

    params["order"] = order

    params["offset"] = offset

    params["limit"] = limit


    params = {k: v for k, v in params.items() if v is not UNSET and v is not None}


    _kwargs: dict[str, Any] = {
        "method": "get",
        "url": "/v_container_contents",
        "params": params,
    }


    _kwargs["headers"] = headers
    return _kwargs



def _parse_response(*, client: Union[AuthenticatedClient, Client], response: httpx.Response) -> Optional[Union[Any, list['VContainerContents']]]:
    if response.status_code == 200:
        response_200 = []
        _response_200 = response.json()
        for response_200_item_data in (_response_200):
            response_200_item = VContainerContents.from_dict(response_200_item_data)



            response_200.append(response_200_item)

        return response_200

    if response.status_code == 206:
        response_206 = cast(Any, None)
        return response_206

    if client.raise_on_unexpected_status:
        raise errors.UnexpectedStatus(response.status_code, response.content)
    else:
        return None


def _build_response(*, client: Union[AuthenticatedClient, Client], response: httpx.Response) -> Response[Union[Any, list['VContainerContents']]]:
    return Response(
        status_code=HTTPStatus(response.status_code),
        content=response.content,
        headers=response.headers,
        parsed=_parse_response(client=client, response=response),
    )


def sync_detailed(
    *,
    client: Union[AuthenticatedClient, Client],
    container_artefact_id: Union[Unset, str] = UNSET,
    container_name: Union[Unset, str] = UNSET,
    container_status: Union[Unset, str] = UNSET,
    container_slot_id: Union[Unset, str] = UNSET,
    slot_name: Union[Unset, str] = UNSET,
    slot_display_name: Union[Unset, str] = UNSET,
    position: Union[Unset, str] = UNSET,
    artefact_id: Union[Unset, str] = UNSET,
    artefact_name: Union[Unset, str] = UNSET,
    artefact_status: Union[Unset, str] = UNSET,
    quantity: Union[Unset, str] = UNSET,
    quantity_unit: Union[Unset, str] = UNSET,
    occupied_at: Union[Unset, str] = UNSET,
    last_updated_at: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVContainerContentsPrefer] = UNSET,

) -> Response[Union[Any, list['VContainerContents']]]:
    """ 
    Args:
        container_artefact_id (Union[Unset, str]):
        container_name (Union[Unset, str]):
        container_status (Union[Unset, str]):
        container_slot_id (Union[Unset, str]):
        slot_name (Union[Unset, str]):
        slot_display_name (Union[Unset, str]):
        position (Union[Unset, str]):
        artefact_id (Union[Unset, str]):
        artefact_name (Union[Unset, str]):
        artefact_status (Union[Unset, str]):
        quantity (Union[Unset, str]):
        quantity_unit (Union[Unset, str]):
        occupied_at (Union[Unset, str]):
        last_updated_at (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVContainerContentsPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Union[Any, list['VContainerContents']]]
     """


    kwargs = _get_kwargs(
        container_artefact_id=container_artefact_id,
container_name=container_name,
container_status=container_status,
container_slot_id=container_slot_id,
slot_name=slot_name,
slot_display_name=slot_display_name,
position=position,
artefact_id=artefact_id,
artefact_name=artefact_name,
artefact_status=artefact_status,
quantity=quantity,
quantity_unit=quantity_unit,
occupied_at=occupied_at,
last_updated_at=last_updated_at,
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
    container_artefact_id: Union[Unset, str] = UNSET,
    container_name: Union[Unset, str] = UNSET,
    container_status: Union[Unset, str] = UNSET,
    container_slot_id: Union[Unset, str] = UNSET,
    slot_name: Union[Unset, str] = UNSET,
    slot_display_name: Union[Unset, str] = UNSET,
    position: Union[Unset, str] = UNSET,
    artefact_id: Union[Unset, str] = UNSET,
    artefact_name: Union[Unset, str] = UNSET,
    artefact_status: Union[Unset, str] = UNSET,
    quantity: Union[Unset, str] = UNSET,
    quantity_unit: Union[Unset, str] = UNSET,
    occupied_at: Union[Unset, str] = UNSET,
    last_updated_at: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVContainerContentsPrefer] = UNSET,

) -> Optional[Union[Any, list['VContainerContents']]]:
    """ 
    Args:
        container_artefact_id (Union[Unset, str]):
        container_name (Union[Unset, str]):
        container_status (Union[Unset, str]):
        container_slot_id (Union[Unset, str]):
        slot_name (Union[Unset, str]):
        slot_display_name (Union[Unset, str]):
        position (Union[Unset, str]):
        artefact_id (Union[Unset, str]):
        artefact_name (Union[Unset, str]):
        artefact_status (Union[Unset, str]):
        quantity (Union[Unset, str]):
        quantity_unit (Union[Unset, str]):
        occupied_at (Union[Unset, str]):
        last_updated_at (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVContainerContentsPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Union[Any, list['VContainerContents']]
     """


    return sync_detailed(
        client=client,
container_artefact_id=container_artefact_id,
container_name=container_name,
container_status=container_status,
container_slot_id=container_slot_id,
slot_name=slot_name,
slot_display_name=slot_display_name,
position=position,
artefact_id=artefact_id,
artefact_name=artefact_name,
artefact_status=artefact_status,
quantity=quantity,
quantity_unit=quantity_unit,
occupied_at=occupied_at,
last_updated_at=last_updated_at,
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
    container_artefact_id: Union[Unset, str] = UNSET,
    container_name: Union[Unset, str] = UNSET,
    container_status: Union[Unset, str] = UNSET,
    container_slot_id: Union[Unset, str] = UNSET,
    slot_name: Union[Unset, str] = UNSET,
    slot_display_name: Union[Unset, str] = UNSET,
    position: Union[Unset, str] = UNSET,
    artefact_id: Union[Unset, str] = UNSET,
    artefact_name: Union[Unset, str] = UNSET,
    artefact_status: Union[Unset, str] = UNSET,
    quantity: Union[Unset, str] = UNSET,
    quantity_unit: Union[Unset, str] = UNSET,
    occupied_at: Union[Unset, str] = UNSET,
    last_updated_at: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVContainerContentsPrefer] = UNSET,

) -> Response[Union[Any, list['VContainerContents']]]:
    """ 
    Args:
        container_artefact_id (Union[Unset, str]):
        container_name (Union[Unset, str]):
        container_status (Union[Unset, str]):
        container_slot_id (Union[Unset, str]):
        slot_name (Union[Unset, str]):
        slot_display_name (Union[Unset, str]):
        position (Union[Unset, str]):
        artefact_id (Union[Unset, str]):
        artefact_name (Union[Unset, str]):
        artefact_status (Union[Unset, str]):
        quantity (Union[Unset, str]):
        quantity_unit (Union[Unset, str]):
        occupied_at (Union[Unset, str]):
        last_updated_at (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVContainerContentsPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Union[Any, list['VContainerContents']]]
     """


    kwargs = _get_kwargs(
        container_artefact_id=container_artefact_id,
container_name=container_name,
container_status=container_status,
container_slot_id=container_slot_id,
slot_name=slot_name,
slot_display_name=slot_display_name,
position=position,
artefact_id=artefact_id,
artefact_name=artefact_name,
artefact_status=artefact_status,
quantity=quantity,
quantity_unit=quantity_unit,
occupied_at=occupied_at,
last_updated_at=last_updated_at,
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
    container_artefact_id: Union[Unset, str] = UNSET,
    container_name: Union[Unset, str] = UNSET,
    container_status: Union[Unset, str] = UNSET,
    container_slot_id: Union[Unset, str] = UNSET,
    slot_name: Union[Unset, str] = UNSET,
    slot_display_name: Union[Unset, str] = UNSET,
    position: Union[Unset, str] = UNSET,
    artefact_id: Union[Unset, str] = UNSET,
    artefact_name: Union[Unset, str] = UNSET,
    artefact_status: Union[Unset, str] = UNSET,
    quantity: Union[Unset, str] = UNSET,
    quantity_unit: Union[Unset, str] = UNSET,
    occupied_at: Union[Unset, str] = UNSET,
    last_updated_at: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVContainerContentsPrefer] = UNSET,

) -> Optional[Union[Any, list['VContainerContents']]]:
    """ 
    Args:
        container_artefact_id (Union[Unset, str]):
        container_name (Union[Unset, str]):
        container_status (Union[Unset, str]):
        container_slot_id (Union[Unset, str]):
        slot_name (Union[Unset, str]):
        slot_display_name (Union[Unset, str]):
        position (Union[Unset, str]):
        artefact_id (Union[Unset, str]):
        artefact_name (Union[Unset, str]):
        artefact_status (Union[Unset, str]):
        quantity (Union[Unset, str]):
        quantity_unit (Union[Unset, str]):
        occupied_at (Union[Unset, str]):
        last_updated_at (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVContainerContentsPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Union[Any, list['VContainerContents']]
     """


    return (await asyncio_detailed(
        client=client,
container_artefact_id=container_artefact_id,
container_name=container_name,
container_status=container_status,
container_slot_id=container_slot_id,
slot_name=slot_name,
slot_display_name=slot_display_name,
position=position,
artefact_id=artefact_id,
artefact_name=artefact_name,
artefact_status=artefact_status,
quantity=quantity,
quantity_unit=quantity_unit,
occupied_at=occupied_at,
last_updated_at=last_updated_at,
select=select,
order=order,
offset=offset,
limit=limit,
range_=range_,
range_unit=range_unit,
prefer=prefer,

    )).parsed
