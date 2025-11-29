from http import HTTPStatus
from typing import Any, Optional, Union, cast

import httpx

from ...client import AuthenticatedClient, Client
from ...types import Response, UNSET
from ... import errors

from ...models.get_v_labware_contents_prefer import GetVLabwareContentsPrefer
from ...models.v_labware_contents import VLabwareContents
from ...types import UNSET, Unset
from typing import cast
from typing import Union



def _get_kwargs(
    *,
    labware_id: Union[Unset, str] = UNSET,
    barcode: Union[Unset, str] = UNSET,
    display_name: Union[Unset, str] = UNSET,
    status: Union[Unset, str] = UNSET,
    position_label: Union[Unset, str] = UNSET,
    sample_id: Union[Unset, str] = UNSET,
    sample_name: Union[Unset, str] = UNSET,
    sample_status: Union[Unset, str] = UNSET,
    volume: Union[Unset, str] = UNSET,
    volume_unit: Union[Unset, str] = UNSET,
    current_storage_sublocation_id: Union[Unset, str] = UNSET,
    storage_path: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVLabwareContentsPrefer] = UNSET,

) -> dict[str, Any]:
    headers: dict[str, Any] = {}
    if not isinstance(range_, Unset):
        headers["Range"] = range_

    if not isinstance(range_unit, Unset):
        headers["Range-Unit"] = range_unit

    if not isinstance(prefer, Unset):
        headers["Prefer"] = str(prefer)




    

    params: dict[str, Any] = {}

    params["labware_id"] = labware_id

    params["barcode"] = barcode

    params["display_name"] = display_name

    params["status"] = status

    params["position_label"] = position_label

    params["sample_id"] = sample_id

    params["sample_name"] = sample_name

    params["sample_status"] = sample_status

    params["volume"] = volume

    params["volume_unit"] = volume_unit

    params["current_storage_sublocation_id"] = current_storage_sublocation_id

    params["storage_path"] = storage_path

    params["select"] = select

    params["order"] = order

    params["offset"] = offset

    params["limit"] = limit


    params = {k: v for k, v in params.items() if v is not UNSET and v is not None}


    _kwargs: dict[str, Any] = {
        "method": "get",
        "url": "/v_labware_contents",
        "params": params,
    }


    _kwargs["headers"] = headers
    return _kwargs



def _parse_response(*, client: Union[AuthenticatedClient, Client], response: httpx.Response) -> Optional[Union[Any, list['VLabwareContents']]]:
    if response.status_code == 200:
        response_200 = []
        _response_200 = response.json()
        for response_200_item_data in (_response_200):
            response_200_item = VLabwareContents.from_dict(response_200_item_data)



            response_200.append(response_200_item)

        return response_200

    if response.status_code == 206:
        response_206 = cast(Any, None)
        return response_206

    if client.raise_on_unexpected_status:
        raise errors.UnexpectedStatus(response.status_code, response.content)
    else:
        return None


def _build_response(*, client: Union[AuthenticatedClient, Client], response: httpx.Response) -> Response[Union[Any, list['VLabwareContents']]]:
    return Response(
        status_code=HTTPStatus(response.status_code),
        content=response.content,
        headers=response.headers,
        parsed=_parse_response(client=client, response=response),
    )


def sync_detailed(
    *,
    client: Union[AuthenticatedClient, Client],
    labware_id: Union[Unset, str] = UNSET,
    barcode: Union[Unset, str] = UNSET,
    display_name: Union[Unset, str] = UNSET,
    status: Union[Unset, str] = UNSET,
    position_label: Union[Unset, str] = UNSET,
    sample_id: Union[Unset, str] = UNSET,
    sample_name: Union[Unset, str] = UNSET,
    sample_status: Union[Unset, str] = UNSET,
    volume: Union[Unset, str] = UNSET,
    volume_unit: Union[Unset, str] = UNSET,
    current_storage_sublocation_id: Union[Unset, str] = UNSET,
    storage_path: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVLabwareContentsPrefer] = UNSET,

) -> Response[Union[Any, list['VLabwareContents']]]:
    """ 
    Args:
        labware_id (Union[Unset, str]):
        barcode (Union[Unset, str]):
        display_name (Union[Unset, str]):
        status (Union[Unset, str]):
        position_label (Union[Unset, str]):
        sample_id (Union[Unset, str]):
        sample_name (Union[Unset, str]):
        sample_status (Union[Unset, str]):
        volume (Union[Unset, str]):
        volume_unit (Union[Unset, str]):
        current_storage_sublocation_id (Union[Unset, str]):
        storage_path (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVLabwareContentsPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Union[Any, list['VLabwareContents']]]
     """


    kwargs = _get_kwargs(
        labware_id=labware_id,
barcode=barcode,
display_name=display_name,
status=status,
position_label=position_label,
sample_id=sample_id,
sample_name=sample_name,
sample_status=sample_status,
volume=volume,
volume_unit=volume_unit,
current_storage_sublocation_id=current_storage_sublocation_id,
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
    labware_id: Union[Unset, str] = UNSET,
    barcode: Union[Unset, str] = UNSET,
    display_name: Union[Unset, str] = UNSET,
    status: Union[Unset, str] = UNSET,
    position_label: Union[Unset, str] = UNSET,
    sample_id: Union[Unset, str] = UNSET,
    sample_name: Union[Unset, str] = UNSET,
    sample_status: Union[Unset, str] = UNSET,
    volume: Union[Unset, str] = UNSET,
    volume_unit: Union[Unset, str] = UNSET,
    current_storage_sublocation_id: Union[Unset, str] = UNSET,
    storage_path: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVLabwareContentsPrefer] = UNSET,

) -> Optional[Union[Any, list['VLabwareContents']]]:
    """ 
    Args:
        labware_id (Union[Unset, str]):
        barcode (Union[Unset, str]):
        display_name (Union[Unset, str]):
        status (Union[Unset, str]):
        position_label (Union[Unset, str]):
        sample_id (Union[Unset, str]):
        sample_name (Union[Unset, str]):
        sample_status (Union[Unset, str]):
        volume (Union[Unset, str]):
        volume_unit (Union[Unset, str]):
        current_storage_sublocation_id (Union[Unset, str]):
        storage_path (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVLabwareContentsPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Union[Any, list['VLabwareContents']]
     """


    return sync_detailed(
        client=client,
labware_id=labware_id,
barcode=barcode,
display_name=display_name,
status=status,
position_label=position_label,
sample_id=sample_id,
sample_name=sample_name,
sample_status=sample_status,
volume=volume,
volume_unit=volume_unit,
current_storage_sublocation_id=current_storage_sublocation_id,
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
    labware_id: Union[Unset, str] = UNSET,
    barcode: Union[Unset, str] = UNSET,
    display_name: Union[Unset, str] = UNSET,
    status: Union[Unset, str] = UNSET,
    position_label: Union[Unset, str] = UNSET,
    sample_id: Union[Unset, str] = UNSET,
    sample_name: Union[Unset, str] = UNSET,
    sample_status: Union[Unset, str] = UNSET,
    volume: Union[Unset, str] = UNSET,
    volume_unit: Union[Unset, str] = UNSET,
    current_storage_sublocation_id: Union[Unset, str] = UNSET,
    storage_path: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVLabwareContentsPrefer] = UNSET,

) -> Response[Union[Any, list['VLabwareContents']]]:
    """ 
    Args:
        labware_id (Union[Unset, str]):
        barcode (Union[Unset, str]):
        display_name (Union[Unset, str]):
        status (Union[Unset, str]):
        position_label (Union[Unset, str]):
        sample_id (Union[Unset, str]):
        sample_name (Union[Unset, str]):
        sample_status (Union[Unset, str]):
        volume (Union[Unset, str]):
        volume_unit (Union[Unset, str]):
        current_storage_sublocation_id (Union[Unset, str]):
        storage_path (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVLabwareContentsPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Union[Any, list['VLabwareContents']]]
     """


    kwargs = _get_kwargs(
        labware_id=labware_id,
barcode=barcode,
display_name=display_name,
status=status,
position_label=position_label,
sample_id=sample_id,
sample_name=sample_name,
sample_status=sample_status,
volume=volume,
volume_unit=volume_unit,
current_storage_sublocation_id=current_storage_sublocation_id,
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
    labware_id: Union[Unset, str] = UNSET,
    barcode: Union[Unset, str] = UNSET,
    display_name: Union[Unset, str] = UNSET,
    status: Union[Unset, str] = UNSET,
    position_label: Union[Unset, str] = UNSET,
    sample_id: Union[Unset, str] = UNSET,
    sample_name: Union[Unset, str] = UNSET,
    sample_status: Union[Unset, str] = UNSET,
    volume: Union[Unset, str] = UNSET,
    volume_unit: Union[Unset, str] = UNSET,
    current_storage_sublocation_id: Union[Unset, str] = UNSET,
    storage_path: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVLabwareContentsPrefer] = UNSET,

) -> Optional[Union[Any, list['VLabwareContents']]]:
    """ 
    Args:
        labware_id (Union[Unset, str]):
        barcode (Union[Unset, str]):
        display_name (Union[Unset, str]):
        status (Union[Unset, str]):
        position_label (Union[Unset, str]):
        sample_id (Union[Unset, str]):
        sample_name (Union[Unset, str]):
        sample_status (Union[Unset, str]):
        volume (Union[Unset, str]):
        volume_unit (Union[Unset, str]):
        current_storage_sublocation_id (Union[Unset, str]):
        storage_path (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVLabwareContentsPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Union[Any, list['VLabwareContents']]
     """


    return (await asyncio_detailed(
        client=client,
labware_id=labware_id,
barcode=barcode,
display_name=display_name,
status=status,
position_label=position_label,
sample_id=sample_id,
sample_name=sample_name,
sample_status=sample_status,
volume=volume,
volume_unit=volume_unit,
current_storage_sublocation_id=current_storage_sublocation_id,
storage_path=storage_path,
select=select,
order=order,
offset=offset,
limit=limit,
range_=range_,
range_unit=range_unit,
prefer=prefer,

    )).parsed
