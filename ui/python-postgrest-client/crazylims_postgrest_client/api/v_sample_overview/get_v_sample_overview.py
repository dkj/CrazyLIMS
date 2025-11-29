from http import HTTPStatus
from typing import Any, Optional, Union, cast

import httpx

from ...client import AuthenticatedClient, Client
from ...types import Response, UNSET
from ... import errors

from ...models.get_v_sample_overview_prefer import GetVSampleOverviewPrefer
from ...models.v_sample_overview import VSampleOverview
from ...types import UNSET, Unset
from typing import cast
from typing import Union



def _get_kwargs(
    *,
    id: Union[Unset, str] = UNSET,
    name: Union[Unset, str] = UNSET,
    sample_type_code: Union[Unset, str] = UNSET,
    sample_status: Union[Unset, str] = UNSET,
    collected_at: Union[Unset, str] = UNSET,
    project_id: Union[Unset, str] = UNSET,
    project_code: Union[Unset, str] = UNSET,
    project_name: Union[Unset, str] = UNSET,
    current_labware_id: Union[Unset, str] = UNSET,
    current_labware_barcode: Union[Unset, str] = UNSET,
    current_labware_name: Union[Unset, str] = UNSET,
    storage_path: Union[Unset, str] = UNSET,
    derivatives: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVSampleOverviewPrefer] = UNSET,

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

    params["sample_type_code"] = sample_type_code

    params["sample_status"] = sample_status

    params["collected_at"] = collected_at

    params["project_id"] = project_id

    params["project_code"] = project_code

    params["project_name"] = project_name

    params["current_labware_id"] = current_labware_id

    params["current_labware_barcode"] = current_labware_barcode

    params["current_labware_name"] = current_labware_name

    params["storage_path"] = storage_path

    params["derivatives"] = derivatives

    params["select"] = select

    params["order"] = order

    params["offset"] = offset

    params["limit"] = limit


    params = {k: v for k, v in params.items() if v is not UNSET and v is not None}


    _kwargs: dict[str, Any] = {
        "method": "get",
        "url": "/v_sample_overview",
        "params": params,
    }


    _kwargs["headers"] = headers
    return _kwargs



def _parse_response(*, client: Union[AuthenticatedClient, Client], response: httpx.Response) -> Optional[Union[Any, list['VSampleOverview']]]:
    if response.status_code == 200:
        response_200 = []
        _response_200 = response.json()
        for response_200_item_data in (_response_200):
            response_200_item = VSampleOverview.from_dict(response_200_item_data)



            response_200.append(response_200_item)

        return response_200

    if response.status_code == 206:
        response_206 = cast(Any, None)
        return response_206

    if client.raise_on_unexpected_status:
        raise errors.UnexpectedStatus(response.status_code, response.content)
    else:
        return None


def _build_response(*, client: Union[AuthenticatedClient, Client], response: httpx.Response) -> Response[Union[Any, list['VSampleOverview']]]:
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
    sample_type_code: Union[Unset, str] = UNSET,
    sample_status: Union[Unset, str] = UNSET,
    collected_at: Union[Unset, str] = UNSET,
    project_id: Union[Unset, str] = UNSET,
    project_code: Union[Unset, str] = UNSET,
    project_name: Union[Unset, str] = UNSET,
    current_labware_id: Union[Unset, str] = UNSET,
    current_labware_barcode: Union[Unset, str] = UNSET,
    current_labware_name: Union[Unset, str] = UNSET,
    storage_path: Union[Unset, str] = UNSET,
    derivatives: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVSampleOverviewPrefer] = UNSET,

) -> Response[Union[Any, list['VSampleOverview']]]:
    """ 
    Args:
        id (Union[Unset, str]):
        name (Union[Unset, str]):
        sample_type_code (Union[Unset, str]):
        sample_status (Union[Unset, str]):
        collected_at (Union[Unset, str]):
        project_id (Union[Unset, str]):
        project_code (Union[Unset, str]):
        project_name (Union[Unset, str]):
        current_labware_id (Union[Unset, str]):
        current_labware_barcode (Union[Unset, str]):
        current_labware_name (Union[Unset, str]):
        storage_path (Union[Unset, str]):
        derivatives (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVSampleOverviewPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Union[Any, list['VSampleOverview']]]
     """


    kwargs = _get_kwargs(
        id=id,
name=name,
sample_type_code=sample_type_code,
sample_status=sample_status,
collected_at=collected_at,
project_id=project_id,
project_code=project_code,
project_name=project_name,
current_labware_id=current_labware_id,
current_labware_barcode=current_labware_barcode,
current_labware_name=current_labware_name,
storage_path=storage_path,
derivatives=derivatives,
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
    sample_type_code: Union[Unset, str] = UNSET,
    sample_status: Union[Unset, str] = UNSET,
    collected_at: Union[Unset, str] = UNSET,
    project_id: Union[Unset, str] = UNSET,
    project_code: Union[Unset, str] = UNSET,
    project_name: Union[Unset, str] = UNSET,
    current_labware_id: Union[Unset, str] = UNSET,
    current_labware_barcode: Union[Unset, str] = UNSET,
    current_labware_name: Union[Unset, str] = UNSET,
    storage_path: Union[Unset, str] = UNSET,
    derivatives: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVSampleOverviewPrefer] = UNSET,

) -> Optional[Union[Any, list['VSampleOverview']]]:
    """ 
    Args:
        id (Union[Unset, str]):
        name (Union[Unset, str]):
        sample_type_code (Union[Unset, str]):
        sample_status (Union[Unset, str]):
        collected_at (Union[Unset, str]):
        project_id (Union[Unset, str]):
        project_code (Union[Unset, str]):
        project_name (Union[Unset, str]):
        current_labware_id (Union[Unset, str]):
        current_labware_barcode (Union[Unset, str]):
        current_labware_name (Union[Unset, str]):
        storage_path (Union[Unset, str]):
        derivatives (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVSampleOverviewPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Union[Any, list['VSampleOverview']]
     """


    return sync_detailed(
        client=client,
id=id,
name=name,
sample_type_code=sample_type_code,
sample_status=sample_status,
collected_at=collected_at,
project_id=project_id,
project_code=project_code,
project_name=project_name,
current_labware_id=current_labware_id,
current_labware_barcode=current_labware_barcode,
current_labware_name=current_labware_name,
storage_path=storage_path,
derivatives=derivatives,
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
    sample_type_code: Union[Unset, str] = UNSET,
    sample_status: Union[Unset, str] = UNSET,
    collected_at: Union[Unset, str] = UNSET,
    project_id: Union[Unset, str] = UNSET,
    project_code: Union[Unset, str] = UNSET,
    project_name: Union[Unset, str] = UNSET,
    current_labware_id: Union[Unset, str] = UNSET,
    current_labware_barcode: Union[Unset, str] = UNSET,
    current_labware_name: Union[Unset, str] = UNSET,
    storage_path: Union[Unset, str] = UNSET,
    derivatives: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVSampleOverviewPrefer] = UNSET,

) -> Response[Union[Any, list['VSampleOverview']]]:
    """ 
    Args:
        id (Union[Unset, str]):
        name (Union[Unset, str]):
        sample_type_code (Union[Unset, str]):
        sample_status (Union[Unset, str]):
        collected_at (Union[Unset, str]):
        project_id (Union[Unset, str]):
        project_code (Union[Unset, str]):
        project_name (Union[Unset, str]):
        current_labware_id (Union[Unset, str]):
        current_labware_barcode (Union[Unset, str]):
        current_labware_name (Union[Unset, str]):
        storage_path (Union[Unset, str]):
        derivatives (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVSampleOverviewPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Union[Any, list['VSampleOverview']]]
     """


    kwargs = _get_kwargs(
        id=id,
name=name,
sample_type_code=sample_type_code,
sample_status=sample_status,
collected_at=collected_at,
project_id=project_id,
project_code=project_code,
project_name=project_name,
current_labware_id=current_labware_id,
current_labware_barcode=current_labware_barcode,
current_labware_name=current_labware_name,
storage_path=storage_path,
derivatives=derivatives,
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
    sample_type_code: Union[Unset, str] = UNSET,
    sample_status: Union[Unset, str] = UNSET,
    collected_at: Union[Unset, str] = UNSET,
    project_id: Union[Unset, str] = UNSET,
    project_code: Union[Unset, str] = UNSET,
    project_name: Union[Unset, str] = UNSET,
    current_labware_id: Union[Unset, str] = UNSET,
    current_labware_barcode: Union[Unset, str] = UNSET,
    current_labware_name: Union[Unset, str] = UNSET,
    storage_path: Union[Unset, str] = UNSET,
    derivatives: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVSampleOverviewPrefer] = UNSET,

) -> Optional[Union[Any, list['VSampleOverview']]]:
    """ 
    Args:
        id (Union[Unset, str]):
        name (Union[Unset, str]):
        sample_type_code (Union[Unset, str]):
        sample_status (Union[Unset, str]):
        collected_at (Union[Unset, str]):
        project_id (Union[Unset, str]):
        project_code (Union[Unset, str]):
        project_name (Union[Unset, str]):
        current_labware_id (Union[Unset, str]):
        current_labware_barcode (Union[Unset, str]):
        current_labware_name (Union[Unset, str]):
        storage_path (Union[Unset, str]):
        derivatives (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVSampleOverviewPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Union[Any, list['VSampleOverview']]
     """


    return (await asyncio_detailed(
        client=client,
id=id,
name=name,
sample_type_code=sample_type_code,
sample_status=sample_status,
collected_at=collected_at,
project_id=project_id,
project_code=project_code,
project_name=project_name,
current_labware_id=current_labware_id,
current_labware_barcode=current_labware_barcode,
current_labware_name=current_labware_name,
storage_path=storage_path,
derivatives=derivatives,
select=select,
order=order,
offset=offset,
limit=limit,
range_=range_,
range_unit=range_unit,
prefer=prefer,

    )).parsed
