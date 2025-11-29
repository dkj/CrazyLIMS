from http import HTTPStatus
from typing import Any, Optional, Union, cast

import httpx

from ...client import AuthenticatedClient, Client
from ...types import Response, UNSET
from ... import errors

from ...models.get_v_sample_lineage_prefer import GetVSampleLineagePrefer
from ...models.v_sample_lineage import VSampleLineage
from ...types import UNSET, Unset
from typing import cast
from typing import Union



def _get_kwargs(
    *,
    parent_sample_id: Union[Unset, str] = UNSET,
    parent_sample_name: Union[Unset, str] = UNSET,
    parent_sample_type_code: Union[Unset, str] = UNSET,
    parent_project_id: Union[Unset, str] = UNSET,
    parent_labware_id: Union[Unset, str] = UNSET,
    parent_labware_barcode: Union[Unset, str] = UNSET,
    parent_labware_name: Union[Unset, str] = UNSET,
    parent_storage_path: Union[Unset, str] = UNSET,
    child_sample_id: Union[Unset, str] = UNSET,
    child_sample_name: Union[Unset, str] = UNSET,
    child_sample_type_code: Union[Unset, str] = UNSET,
    child_project_id: Union[Unset, str] = UNSET,
    child_labware_id: Union[Unset, str] = UNSET,
    child_labware_barcode: Union[Unset, str] = UNSET,
    child_labware_name: Union[Unset, str] = UNSET,
    child_storage_path: Union[Unset, str] = UNSET,
    method: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVSampleLineagePrefer] = UNSET,

) -> dict[str, Any]:
    headers: dict[str, Any] = {}
    if not isinstance(range_, Unset):
        headers["Range"] = range_

    if not isinstance(range_unit, Unset):
        headers["Range-Unit"] = range_unit

    if not isinstance(prefer, Unset):
        headers["Prefer"] = str(prefer)




    

    params: dict[str, Any] = {}

    params["parent_sample_id"] = parent_sample_id

    params["parent_sample_name"] = parent_sample_name

    params["parent_sample_type_code"] = parent_sample_type_code

    params["parent_project_id"] = parent_project_id

    params["parent_labware_id"] = parent_labware_id

    params["parent_labware_barcode"] = parent_labware_barcode

    params["parent_labware_name"] = parent_labware_name

    params["parent_storage_path"] = parent_storage_path

    params["child_sample_id"] = child_sample_id

    params["child_sample_name"] = child_sample_name

    params["child_sample_type_code"] = child_sample_type_code

    params["child_project_id"] = child_project_id

    params["child_labware_id"] = child_labware_id

    params["child_labware_barcode"] = child_labware_barcode

    params["child_labware_name"] = child_labware_name

    params["child_storage_path"] = child_storage_path

    params["method"] = method

    params["created_at"] = created_at

    params["created_by"] = created_by

    params["select"] = select

    params["order"] = order

    params["offset"] = offset

    params["limit"] = limit


    params = {k: v for k, v in params.items() if v is not UNSET and v is not None}


    _kwargs: dict[str, Any] = {
        "method": "get",
        "url": "/v_sample_lineage",
        "params": params,
    }


    _kwargs["headers"] = headers
    return _kwargs



def _parse_response(*, client: Union[AuthenticatedClient, Client], response: httpx.Response) -> Optional[Union[Any, list['VSampleLineage']]]:
    if response.status_code == 200:
        response_200 = []
        _response_200 = response.json()
        for response_200_item_data in (_response_200):
            response_200_item = VSampleLineage.from_dict(response_200_item_data)



            response_200.append(response_200_item)

        return response_200

    if response.status_code == 206:
        response_206 = cast(Any, None)
        return response_206

    if client.raise_on_unexpected_status:
        raise errors.UnexpectedStatus(response.status_code, response.content)
    else:
        return None


def _build_response(*, client: Union[AuthenticatedClient, Client], response: httpx.Response) -> Response[Union[Any, list['VSampleLineage']]]:
    return Response(
        status_code=HTTPStatus(response.status_code),
        content=response.content,
        headers=response.headers,
        parsed=_parse_response(client=client, response=response),
    )


def sync_detailed(
    *,
    client: Union[AuthenticatedClient, Client],
    parent_sample_id: Union[Unset, str] = UNSET,
    parent_sample_name: Union[Unset, str] = UNSET,
    parent_sample_type_code: Union[Unset, str] = UNSET,
    parent_project_id: Union[Unset, str] = UNSET,
    parent_labware_id: Union[Unset, str] = UNSET,
    parent_labware_barcode: Union[Unset, str] = UNSET,
    parent_labware_name: Union[Unset, str] = UNSET,
    parent_storage_path: Union[Unset, str] = UNSET,
    child_sample_id: Union[Unset, str] = UNSET,
    child_sample_name: Union[Unset, str] = UNSET,
    child_sample_type_code: Union[Unset, str] = UNSET,
    child_project_id: Union[Unset, str] = UNSET,
    child_labware_id: Union[Unset, str] = UNSET,
    child_labware_barcode: Union[Unset, str] = UNSET,
    child_labware_name: Union[Unset, str] = UNSET,
    child_storage_path: Union[Unset, str] = UNSET,
    method: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVSampleLineagePrefer] = UNSET,

) -> Response[Union[Any, list['VSampleLineage']]]:
    """ 
    Args:
        parent_sample_id (Union[Unset, str]):
        parent_sample_name (Union[Unset, str]):
        parent_sample_type_code (Union[Unset, str]):
        parent_project_id (Union[Unset, str]):
        parent_labware_id (Union[Unset, str]):
        parent_labware_barcode (Union[Unset, str]):
        parent_labware_name (Union[Unset, str]):
        parent_storage_path (Union[Unset, str]):
        child_sample_id (Union[Unset, str]):
        child_sample_name (Union[Unset, str]):
        child_sample_type_code (Union[Unset, str]):
        child_project_id (Union[Unset, str]):
        child_labware_id (Union[Unset, str]):
        child_labware_barcode (Union[Unset, str]):
        child_labware_name (Union[Unset, str]):
        child_storage_path (Union[Unset, str]):
        method (Union[Unset, str]):
        created_at (Union[Unset, str]):
        created_by (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVSampleLineagePrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Union[Any, list['VSampleLineage']]]
     """


    kwargs = _get_kwargs(
        parent_sample_id=parent_sample_id,
parent_sample_name=parent_sample_name,
parent_sample_type_code=parent_sample_type_code,
parent_project_id=parent_project_id,
parent_labware_id=parent_labware_id,
parent_labware_barcode=parent_labware_barcode,
parent_labware_name=parent_labware_name,
parent_storage_path=parent_storage_path,
child_sample_id=child_sample_id,
child_sample_name=child_sample_name,
child_sample_type_code=child_sample_type_code,
child_project_id=child_project_id,
child_labware_id=child_labware_id,
child_labware_barcode=child_labware_barcode,
child_labware_name=child_labware_name,
child_storage_path=child_storage_path,
method=method,
created_at=created_at,
created_by=created_by,
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
    parent_sample_id: Union[Unset, str] = UNSET,
    parent_sample_name: Union[Unset, str] = UNSET,
    parent_sample_type_code: Union[Unset, str] = UNSET,
    parent_project_id: Union[Unset, str] = UNSET,
    parent_labware_id: Union[Unset, str] = UNSET,
    parent_labware_barcode: Union[Unset, str] = UNSET,
    parent_labware_name: Union[Unset, str] = UNSET,
    parent_storage_path: Union[Unset, str] = UNSET,
    child_sample_id: Union[Unset, str] = UNSET,
    child_sample_name: Union[Unset, str] = UNSET,
    child_sample_type_code: Union[Unset, str] = UNSET,
    child_project_id: Union[Unset, str] = UNSET,
    child_labware_id: Union[Unset, str] = UNSET,
    child_labware_barcode: Union[Unset, str] = UNSET,
    child_labware_name: Union[Unset, str] = UNSET,
    child_storage_path: Union[Unset, str] = UNSET,
    method: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVSampleLineagePrefer] = UNSET,

) -> Optional[Union[Any, list['VSampleLineage']]]:
    """ 
    Args:
        parent_sample_id (Union[Unset, str]):
        parent_sample_name (Union[Unset, str]):
        parent_sample_type_code (Union[Unset, str]):
        parent_project_id (Union[Unset, str]):
        parent_labware_id (Union[Unset, str]):
        parent_labware_barcode (Union[Unset, str]):
        parent_labware_name (Union[Unset, str]):
        parent_storage_path (Union[Unset, str]):
        child_sample_id (Union[Unset, str]):
        child_sample_name (Union[Unset, str]):
        child_sample_type_code (Union[Unset, str]):
        child_project_id (Union[Unset, str]):
        child_labware_id (Union[Unset, str]):
        child_labware_barcode (Union[Unset, str]):
        child_labware_name (Union[Unset, str]):
        child_storage_path (Union[Unset, str]):
        method (Union[Unset, str]):
        created_at (Union[Unset, str]):
        created_by (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVSampleLineagePrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Union[Any, list['VSampleLineage']]
     """


    return sync_detailed(
        client=client,
parent_sample_id=parent_sample_id,
parent_sample_name=parent_sample_name,
parent_sample_type_code=parent_sample_type_code,
parent_project_id=parent_project_id,
parent_labware_id=parent_labware_id,
parent_labware_barcode=parent_labware_barcode,
parent_labware_name=parent_labware_name,
parent_storage_path=parent_storage_path,
child_sample_id=child_sample_id,
child_sample_name=child_sample_name,
child_sample_type_code=child_sample_type_code,
child_project_id=child_project_id,
child_labware_id=child_labware_id,
child_labware_barcode=child_labware_barcode,
child_labware_name=child_labware_name,
child_storage_path=child_storage_path,
method=method,
created_at=created_at,
created_by=created_by,
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
    parent_sample_id: Union[Unset, str] = UNSET,
    parent_sample_name: Union[Unset, str] = UNSET,
    parent_sample_type_code: Union[Unset, str] = UNSET,
    parent_project_id: Union[Unset, str] = UNSET,
    parent_labware_id: Union[Unset, str] = UNSET,
    parent_labware_barcode: Union[Unset, str] = UNSET,
    parent_labware_name: Union[Unset, str] = UNSET,
    parent_storage_path: Union[Unset, str] = UNSET,
    child_sample_id: Union[Unset, str] = UNSET,
    child_sample_name: Union[Unset, str] = UNSET,
    child_sample_type_code: Union[Unset, str] = UNSET,
    child_project_id: Union[Unset, str] = UNSET,
    child_labware_id: Union[Unset, str] = UNSET,
    child_labware_barcode: Union[Unset, str] = UNSET,
    child_labware_name: Union[Unset, str] = UNSET,
    child_storage_path: Union[Unset, str] = UNSET,
    method: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVSampleLineagePrefer] = UNSET,

) -> Response[Union[Any, list['VSampleLineage']]]:
    """ 
    Args:
        parent_sample_id (Union[Unset, str]):
        parent_sample_name (Union[Unset, str]):
        parent_sample_type_code (Union[Unset, str]):
        parent_project_id (Union[Unset, str]):
        parent_labware_id (Union[Unset, str]):
        parent_labware_barcode (Union[Unset, str]):
        parent_labware_name (Union[Unset, str]):
        parent_storage_path (Union[Unset, str]):
        child_sample_id (Union[Unset, str]):
        child_sample_name (Union[Unset, str]):
        child_sample_type_code (Union[Unset, str]):
        child_project_id (Union[Unset, str]):
        child_labware_id (Union[Unset, str]):
        child_labware_barcode (Union[Unset, str]):
        child_labware_name (Union[Unset, str]):
        child_storage_path (Union[Unset, str]):
        method (Union[Unset, str]):
        created_at (Union[Unset, str]):
        created_by (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVSampleLineagePrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Union[Any, list['VSampleLineage']]]
     """


    kwargs = _get_kwargs(
        parent_sample_id=parent_sample_id,
parent_sample_name=parent_sample_name,
parent_sample_type_code=parent_sample_type_code,
parent_project_id=parent_project_id,
parent_labware_id=parent_labware_id,
parent_labware_barcode=parent_labware_barcode,
parent_labware_name=parent_labware_name,
parent_storage_path=parent_storage_path,
child_sample_id=child_sample_id,
child_sample_name=child_sample_name,
child_sample_type_code=child_sample_type_code,
child_project_id=child_project_id,
child_labware_id=child_labware_id,
child_labware_barcode=child_labware_barcode,
child_labware_name=child_labware_name,
child_storage_path=child_storage_path,
method=method,
created_at=created_at,
created_by=created_by,
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
    parent_sample_id: Union[Unset, str] = UNSET,
    parent_sample_name: Union[Unset, str] = UNSET,
    parent_sample_type_code: Union[Unset, str] = UNSET,
    parent_project_id: Union[Unset, str] = UNSET,
    parent_labware_id: Union[Unset, str] = UNSET,
    parent_labware_barcode: Union[Unset, str] = UNSET,
    parent_labware_name: Union[Unset, str] = UNSET,
    parent_storage_path: Union[Unset, str] = UNSET,
    child_sample_id: Union[Unset, str] = UNSET,
    child_sample_name: Union[Unset, str] = UNSET,
    child_sample_type_code: Union[Unset, str] = UNSET,
    child_project_id: Union[Unset, str] = UNSET,
    child_labware_id: Union[Unset, str] = UNSET,
    child_labware_barcode: Union[Unset, str] = UNSET,
    child_labware_name: Union[Unset, str] = UNSET,
    child_storage_path: Union[Unset, str] = UNSET,
    method: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVSampleLineagePrefer] = UNSET,

) -> Optional[Union[Any, list['VSampleLineage']]]:
    """ 
    Args:
        parent_sample_id (Union[Unset, str]):
        parent_sample_name (Union[Unset, str]):
        parent_sample_type_code (Union[Unset, str]):
        parent_project_id (Union[Unset, str]):
        parent_labware_id (Union[Unset, str]):
        parent_labware_barcode (Union[Unset, str]):
        parent_labware_name (Union[Unset, str]):
        parent_storage_path (Union[Unset, str]):
        child_sample_id (Union[Unset, str]):
        child_sample_name (Union[Unset, str]):
        child_sample_type_code (Union[Unset, str]):
        child_project_id (Union[Unset, str]):
        child_labware_id (Union[Unset, str]):
        child_labware_barcode (Union[Unset, str]):
        child_labware_name (Union[Unset, str]):
        child_storage_path (Union[Unset, str]):
        method (Union[Unset, str]):
        created_at (Union[Unset, str]):
        created_by (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVSampleLineagePrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Union[Any, list['VSampleLineage']]
     """


    return (await asyncio_detailed(
        client=client,
parent_sample_id=parent_sample_id,
parent_sample_name=parent_sample_name,
parent_sample_type_code=parent_sample_type_code,
parent_project_id=parent_project_id,
parent_labware_id=parent_labware_id,
parent_labware_barcode=parent_labware_barcode,
parent_labware_name=parent_labware_name,
parent_storage_path=parent_storage_path,
child_sample_id=child_sample_id,
child_sample_name=child_sample_name,
child_sample_type_code=child_sample_type_code,
child_project_id=child_project_id,
child_labware_id=child_labware_id,
child_labware_barcode=child_labware_barcode,
child_labware_name=child_labware_name,
child_storage_path=child_storage_path,
method=method,
created_at=created_at,
created_by=created_by,
select=select,
order=order,
offset=offset,
limit=limit,
range_=range_,
range_unit=range_unit,
prefer=prefer,

    )).parsed
