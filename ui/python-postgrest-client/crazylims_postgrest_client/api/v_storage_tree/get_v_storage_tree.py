from http import HTTPStatus
from typing import Any, Optional, Union, cast

import httpx

from ...client import AuthenticatedClient, Client
from ...types import Response, UNSET
from ... import errors

from ...models.get_v_storage_tree_prefer import GetVStorageTreePrefer
from ...models.v_storage_tree import VStorageTree
from ...types import UNSET, Unset
from typing import cast
from typing import Union



def _get_kwargs(
    *,
    facility_id: Union[Unset, str] = UNSET,
    facility_name: Union[Unset, str] = UNSET,
    unit_id: Union[Unset, str] = UNSET,
    unit_name: Union[Unset, str] = UNSET,
    storage_type: Union[Unset, str] = UNSET,
    sublocation_id: Union[Unset, str] = UNSET,
    sublocation_name: Union[Unset, str] = UNSET,
    parent_sublocation_id: Union[Unset, str] = UNSET,
    capacity: Union[Unset, str] = UNSET,
    storage_path: Union[Unset, str] = UNSET,
    labware_count: Union[Unset, str] = UNSET,
    sample_count: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVStorageTreePrefer] = UNSET,

) -> dict[str, Any]:
    headers: dict[str, Any] = {}
    if not isinstance(range_, Unset):
        headers["Range"] = range_

    if not isinstance(range_unit, Unset):
        headers["Range-Unit"] = range_unit

    if not isinstance(prefer, Unset):
        headers["Prefer"] = str(prefer)




    

    params: dict[str, Any] = {}

    params["facility_id"] = facility_id

    params["facility_name"] = facility_name

    params["unit_id"] = unit_id

    params["unit_name"] = unit_name

    params["storage_type"] = storage_type

    params["sublocation_id"] = sublocation_id

    params["sublocation_name"] = sublocation_name

    params["parent_sublocation_id"] = parent_sublocation_id

    params["capacity"] = capacity

    params["storage_path"] = storage_path

    params["labware_count"] = labware_count

    params["sample_count"] = sample_count

    params["select"] = select

    params["order"] = order

    params["offset"] = offset

    params["limit"] = limit


    params = {k: v for k, v in params.items() if v is not UNSET and v is not None}


    _kwargs: dict[str, Any] = {
        "method": "get",
        "url": "/v_storage_tree",
        "params": params,
    }


    _kwargs["headers"] = headers
    return _kwargs



def _parse_response(*, client: Union[AuthenticatedClient, Client], response: httpx.Response) -> Optional[Union[Any, list['VStorageTree']]]:
    if response.status_code == 200:
        response_200 = []
        _response_200 = response.json()
        for response_200_item_data in (_response_200):
            response_200_item = VStorageTree.from_dict(response_200_item_data)



            response_200.append(response_200_item)

        return response_200

    if response.status_code == 206:
        response_206 = cast(Any, None)
        return response_206

    if client.raise_on_unexpected_status:
        raise errors.UnexpectedStatus(response.status_code, response.content)
    else:
        return None


def _build_response(*, client: Union[AuthenticatedClient, Client], response: httpx.Response) -> Response[Union[Any, list['VStorageTree']]]:
    return Response(
        status_code=HTTPStatus(response.status_code),
        content=response.content,
        headers=response.headers,
        parsed=_parse_response(client=client, response=response),
    )


def sync_detailed(
    *,
    client: Union[AuthenticatedClient, Client],
    facility_id: Union[Unset, str] = UNSET,
    facility_name: Union[Unset, str] = UNSET,
    unit_id: Union[Unset, str] = UNSET,
    unit_name: Union[Unset, str] = UNSET,
    storage_type: Union[Unset, str] = UNSET,
    sublocation_id: Union[Unset, str] = UNSET,
    sublocation_name: Union[Unset, str] = UNSET,
    parent_sublocation_id: Union[Unset, str] = UNSET,
    capacity: Union[Unset, str] = UNSET,
    storage_path: Union[Unset, str] = UNSET,
    labware_count: Union[Unset, str] = UNSET,
    sample_count: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVStorageTreePrefer] = UNSET,

) -> Response[Union[Any, list['VStorageTree']]]:
    """ 
    Args:
        facility_id (Union[Unset, str]):
        facility_name (Union[Unset, str]):
        unit_id (Union[Unset, str]):
        unit_name (Union[Unset, str]):
        storage_type (Union[Unset, str]):
        sublocation_id (Union[Unset, str]):
        sublocation_name (Union[Unset, str]):
        parent_sublocation_id (Union[Unset, str]):
        capacity (Union[Unset, str]):
        storage_path (Union[Unset, str]):
        labware_count (Union[Unset, str]):
        sample_count (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVStorageTreePrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Union[Any, list['VStorageTree']]]
     """


    kwargs = _get_kwargs(
        facility_id=facility_id,
facility_name=facility_name,
unit_id=unit_id,
unit_name=unit_name,
storage_type=storage_type,
sublocation_id=sublocation_id,
sublocation_name=sublocation_name,
parent_sublocation_id=parent_sublocation_id,
capacity=capacity,
storage_path=storage_path,
labware_count=labware_count,
sample_count=sample_count,
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
    facility_id: Union[Unset, str] = UNSET,
    facility_name: Union[Unset, str] = UNSET,
    unit_id: Union[Unset, str] = UNSET,
    unit_name: Union[Unset, str] = UNSET,
    storage_type: Union[Unset, str] = UNSET,
    sublocation_id: Union[Unset, str] = UNSET,
    sublocation_name: Union[Unset, str] = UNSET,
    parent_sublocation_id: Union[Unset, str] = UNSET,
    capacity: Union[Unset, str] = UNSET,
    storage_path: Union[Unset, str] = UNSET,
    labware_count: Union[Unset, str] = UNSET,
    sample_count: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVStorageTreePrefer] = UNSET,

) -> Optional[Union[Any, list['VStorageTree']]]:
    """ 
    Args:
        facility_id (Union[Unset, str]):
        facility_name (Union[Unset, str]):
        unit_id (Union[Unset, str]):
        unit_name (Union[Unset, str]):
        storage_type (Union[Unset, str]):
        sublocation_id (Union[Unset, str]):
        sublocation_name (Union[Unset, str]):
        parent_sublocation_id (Union[Unset, str]):
        capacity (Union[Unset, str]):
        storage_path (Union[Unset, str]):
        labware_count (Union[Unset, str]):
        sample_count (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVStorageTreePrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Union[Any, list['VStorageTree']]
     """


    return sync_detailed(
        client=client,
facility_id=facility_id,
facility_name=facility_name,
unit_id=unit_id,
unit_name=unit_name,
storage_type=storage_type,
sublocation_id=sublocation_id,
sublocation_name=sublocation_name,
parent_sublocation_id=parent_sublocation_id,
capacity=capacity,
storage_path=storage_path,
labware_count=labware_count,
sample_count=sample_count,
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
    facility_id: Union[Unset, str] = UNSET,
    facility_name: Union[Unset, str] = UNSET,
    unit_id: Union[Unset, str] = UNSET,
    unit_name: Union[Unset, str] = UNSET,
    storage_type: Union[Unset, str] = UNSET,
    sublocation_id: Union[Unset, str] = UNSET,
    sublocation_name: Union[Unset, str] = UNSET,
    parent_sublocation_id: Union[Unset, str] = UNSET,
    capacity: Union[Unset, str] = UNSET,
    storage_path: Union[Unset, str] = UNSET,
    labware_count: Union[Unset, str] = UNSET,
    sample_count: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVStorageTreePrefer] = UNSET,

) -> Response[Union[Any, list['VStorageTree']]]:
    """ 
    Args:
        facility_id (Union[Unset, str]):
        facility_name (Union[Unset, str]):
        unit_id (Union[Unset, str]):
        unit_name (Union[Unset, str]):
        storage_type (Union[Unset, str]):
        sublocation_id (Union[Unset, str]):
        sublocation_name (Union[Unset, str]):
        parent_sublocation_id (Union[Unset, str]):
        capacity (Union[Unset, str]):
        storage_path (Union[Unset, str]):
        labware_count (Union[Unset, str]):
        sample_count (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVStorageTreePrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Union[Any, list['VStorageTree']]]
     """


    kwargs = _get_kwargs(
        facility_id=facility_id,
facility_name=facility_name,
unit_id=unit_id,
unit_name=unit_name,
storage_type=storage_type,
sublocation_id=sublocation_id,
sublocation_name=sublocation_name,
parent_sublocation_id=parent_sublocation_id,
capacity=capacity,
storage_path=storage_path,
labware_count=labware_count,
sample_count=sample_count,
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
    facility_id: Union[Unset, str] = UNSET,
    facility_name: Union[Unset, str] = UNSET,
    unit_id: Union[Unset, str] = UNSET,
    unit_name: Union[Unset, str] = UNSET,
    storage_type: Union[Unset, str] = UNSET,
    sublocation_id: Union[Unset, str] = UNSET,
    sublocation_name: Union[Unset, str] = UNSET,
    parent_sublocation_id: Union[Unset, str] = UNSET,
    capacity: Union[Unset, str] = UNSET,
    storage_path: Union[Unset, str] = UNSET,
    labware_count: Union[Unset, str] = UNSET,
    sample_count: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVStorageTreePrefer] = UNSET,

) -> Optional[Union[Any, list['VStorageTree']]]:
    """ 
    Args:
        facility_id (Union[Unset, str]):
        facility_name (Union[Unset, str]):
        unit_id (Union[Unset, str]):
        unit_name (Union[Unset, str]):
        storage_type (Union[Unset, str]):
        sublocation_id (Union[Unset, str]):
        sublocation_name (Union[Unset, str]):
        parent_sublocation_id (Union[Unset, str]):
        capacity (Union[Unset, str]):
        storage_path (Union[Unset, str]):
        labware_count (Union[Unset, str]):
        sample_count (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVStorageTreePrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Union[Any, list['VStorageTree']]
     """


    return (await asyncio_detailed(
        client=client,
facility_id=facility_id,
facility_name=facility_name,
unit_id=unit_id,
unit_name=unit_name,
storage_type=storage_type,
sublocation_id=sublocation_id,
sublocation_name=sublocation_name,
parent_sublocation_id=parent_sublocation_id,
capacity=capacity,
storage_path=storage_path,
labware_count=labware_count,
sample_count=sample_count,
select=select,
order=order,
offset=offset,
limit=limit,
range_=range_,
range_unit=range_unit,
prefer=prefer,

    )).parsed
