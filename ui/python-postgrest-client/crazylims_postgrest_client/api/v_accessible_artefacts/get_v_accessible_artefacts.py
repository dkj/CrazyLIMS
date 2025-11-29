from http import HTTPStatus
from typing import Any, Optional, Union, cast

import httpx

from ...client import AuthenticatedClient, Client
from ...types import Response, UNSET
from ... import errors

from ...models.get_v_accessible_artefacts_prefer import GetVAccessibleArtefactsPrefer
from ...models.v_accessible_artefacts import VAccessibleArtefacts
from ...types import UNSET, Unset
from typing import cast
from typing import Union



def _get_kwargs(
    *,
    artefact_id: Union[Unset, str] = UNSET,
    name: Union[Unset, str] = UNSET,
    status: Union[Unset, str] = UNSET,
    is_virtual: Union[Unset, str] = UNSET,
    quantity: Union[Unset, str] = UNSET,
    quantity_unit: Union[Unset, str] = UNSET,
    type_key: Union[Unset, str] = UNSET,
    artefact_type: Union[Unset, str] = UNSET,
    artefact_kind: Union[Unset, str] = UNSET,
    primary_scope_id: Union[Unset, str] = UNSET,
    primary_scope_name: Union[Unset, str] = UNSET,
    primary_scope_type: Union[Unset, str] = UNSET,
    storage_node_id: Union[Unset, str] = UNSET,
    storage_display_name: Union[Unset, str] = UNSET,
    storage_node_type: Union[Unset, str] = UNSET,
    last_event_type: Union[Unset, str] = UNSET,
    last_event_at: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVAccessibleArtefactsPrefer] = UNSET,

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

    params["name"] = name

    params["status"] = status

    params["is_virtual"] = is_virtual

    params["quantity"] = quantity

    params["quantity_unit"] = quantity_unit

    params["type_key"] = type_key

    params["artefact_type"] = artefact_type

    params["artefact_kind"] = artefact_kind

    params["primary_scope_id"] = primary_scope_id

    params["primary_scope_name"] = primary_scope_name

    params["primary_scope_type"] = primary_scope_type

    params["storage_node_id"] = storage_node_id

    params["storage_display_name"] = storage_display_name

    params["storage_node_type"] = storage_node_type

    params["last_event_type"] = last_event_type

    params["last_event_at"] = last_event_at

    params["select"] = select

    params["order"] = order

    params["offset"] = offset

    params["limit"] = limit


    params = {k: v for k, v in params.items() if v is not UNSET and v is not None}


    _kwargs: dict[str, Any] = {
        "method": "get",
        "url": "/v_accessible_artefacts",
        "params": params,
    }


    _kwargs["headers"] = headers
    return _kwargs



def _parse_response(*, client: Union[AuthenticatedClient, Client], response: httpx.Response) -> Optional[Union[Any, list['VAccessibleArtefacts']]]:
    if response.status_code == 200:
        response_200 = []
        _response_200 = response.json()
        for response_200_item_data in (_response_200):
            response_200_item = VAccessibleArtefacts.from_dict(response_200_item_data)



            response_200.append(response_200_item)

        return response_200

    if response.status_code == 206:
        response_206 = cast(Any, None)
        return response_206

    if client.raise_on_unexpected_status:
        raise errors.UnexpectedStatus(response.status_code, response.content)
    else:
        return None


def _build_response(*, client: Union[AuthenticatedClient, Client], response: httpx.Response) -> Response[Union[Any, list['VAccessibleArtefacts']]]:
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
    name: Union[Unset, str] = UNSET,
    status: Union[Unset, str] = UNSET,
    is_virtual: Union[Unset, str] = UNSET,
    quantity: Union[Unset, str] = UNSET,
    quantity_unit: Union[Unset, str] = UNSET,
    type_key: Union[Unset, str] = UNSET,
    artefact_type: Union[Unset, str] = UNSET,
    artefact_kind: Union[Unset, str] = UNSET,
    primary_scope_id: Union[Unset, str] = UNSET,
    primary_scope_name: Union[Unset, str] = UNSET,
    primary_scope_type: Union[Unset, str] = UNSET,
    storage_node_id: Union[Unset, str] = UNSET,
    storage_display_name: Union[Unset, str] = UNSET,
    storage_node_type: Union[Unset, str] = UNSET,
    last_event_type: Union[Unset, str] = UNSET,
    last_event_at: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVAccessibleArtefactsPrefer] = UNSET,

) -> Response[Union[Any, list['VAccessibleArtefacts']]]:
    """ 
    Args:
        artefact_id (Union[Unset, str]):
        name (Union[Unset, str]):
        status (Union[Unset, str]):
        is_virtual (Union[Unset, str]):
        quantity (Union[Unset, str]):
        quantity_unit (Union[Unset, str]):
        type_key (Union[Unset, str]):
        artefact_type (Union[Unset, str]):
        artefact_kind (Union[Unset, str]):
        primary_scope_id (Union[Unset, str]):
        primary_scope_name (Union[Unset, str]):
        primary_scope_type (Union[Unset, str]):
        storage_node_id (Union[Unset, str]):
        storage_display_name (Union[Unset, str]):
        storage_node_type (Union[Unset, str]):
        last_event_type (Union[Unset, str]):
        last_event_at (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVAccessibleArtefactsPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Union[Any, list['VAccessibleArtefacts']]]
     """


    kwargs = _get_kwargs(
        artefact_id=artefact_id,
name=name,
status=status,
is_virtual=is_virtual,
quantity=quantity,
quantity_unit=quantity_unit,
type_key=type_key,
artefact_type=artefact_type,
artefact_kind=artefact_kind,
primary_scope_id=primary_scope_id,
primary_scope_name=primary_scope_name,
primary_scope_type=primary_scope_type,
storage_node_id=storage_node_id,
storage_display_name=storage_display_name,
storage_node_type=storage_node_type,
last_event_type=last_event_type,
last_event_at=last_event_at,
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
    name: Union[Unset, str] = UNSET,
    status: Union[Unset, str] = UNSET,
    is_virtual: Union[Unset, str] = UNSET,
    quantity: Union[Unset, str] = UNSET,
    quantity_unit: Union[Unset, str] = UNSET,
    type_key: Union[Unset, str] = UNSET,
    artefact_type: Union[Unset, str] = UNSET,
    artefact_kind: Union[Unset, str] = UNSET,
    primary_scope_id: Union[Unset, str] = UNSET,
    primary_scope_name: Union[Unset, str] = UNSET,
    primary_scope_type: Union[Unset, str] = UNSET,
    storage_node_id: Union[Unset, str] = UNSET,
    storage_display_name: Union[Unset, str] = UNSET,
    storage_node_type: Union[Unset, str] = UNSET,
    last_event_type: Union[Unset, str] = UNSET,
    last_event_at: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVAccessibleArtefactsPrefer] = UNSET,

) -> Optional[Union[Any, list['VAccessibleArtefacts']]]:
    """ 
    Args:
        artefact_id (Union[Unset, str]):
        name (Union[Unset, str]):
        status (Union[Unset, str]):
        is_virtual (Union[Unset, str]):
        quantity (Union[Unset, str]):
        quantity_unit (Union[Unset, str]):
        type_key (Union[Unset, str]):
        artefact_type (Union[Unset, str]):
        artefact_kind (Union[Unset, str]):
        primary_scope_id (Union[Unset, str]):
        primary_scope_name (Union[Unset, str]):
        primary_scope_type (Union[Unset, str]):
        storage_node_id (Union[Unset, str]):
        storage_display_name (Union[Unset, str]):
        storage_node_type (Union[Unset, str]):
        last_event_type (Union[Unset, str]):
        last_event_at (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVAccessibleArtefactsPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Union[Any, list['VAccessibleArtefacts']]
     """


    return sync_detailed(
        client=client,
artefact_id=artefact_id,
name=name,
status=status,
is_virtual=is_virtual,
quantity=quantity,
quantity_unit=quantity_unit,
type_key=type_key,
artefact_type=artefact_type,
artefact_kind=artefact_kind,
primary_scope_id=primary_scope_id,
primary_scope_name=primary_scope_name,
primary_scope_type=primary_scope_type,
storage_node_id=storage_node_id,
storage_display_name=storage_display_name,
storage_node_type=storage_node_type,
last_event_type=last_event_type,
last_event_at=last_event_at,
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
    name: Union[Unset, str] = UNSET,
    status: Union[Unset, str] = UNSET,
    is_virtual: Union[Unset, str] = UNSET,
    quantity: Union[Unset, str] = UNSET,
    quantity_unit: Union[Unset, str] = UNSET,
    type_key: Union[Unset, str] = UNSET,
    artefact_type: Union[Unset, str] = UNSET,
    artefact_kind: Union[Unset, str] = UNSET,
    primary_scope_id: Union[Unset, str] = UNSET,
    primary_scope_name: Union[Unset, str] = UNSET,
    primary_scope_type: Union[Unset, str] = UNSET,
    storage_node_id: Union[Unset, str] = UNSET,
    storage_display_name: Union[Unset, str] = UNSET,
    storage_node_type: Union[Unset, str] = UNSET,
    last_event_type: Union[Unset, str] = UNSET,
    last_event_at: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVAccessibleArtefactsPrefer] = UNSET,

) -> Response[Union[Any, list['VAccessibleArtefacts']]]:
    """ 
    Args:
        artefact_id (Union[Unset, str]):
        name (Union[Unset, str]):
        status (Union[Unset, str]):
        is_virtual (Union[Unset, str]):
        quantity (Union[Unset, str]):
        quantity_unit (Union[Unset, str]):
        type_key (Union[Unset, str]):
        artefact_type (Union[Unset, str]):
        artefact_kind (Union[Unset, str]):
        primary_scope_id (Union[Unset, str]):
        primary_scope_name (Union[Unset, str]):
        primary_scope_type (Union[Unset, str]):
        storage_node_id (Union[Unset, str]):
        storage_display_name (Union[Unset, str]):
        storage_node_type (Union[Unset, str]):
        last_event_type (Union[Unset, str]):
        last_event_at (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVAccessibleArtefactsPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Union[Any, list['VAccessibleArtefacts']]]
     """


    kwargs = _get_kwargs(
        artefact_id=artefact_id,
name=name,
status=status,
is_virtual=is_virtual,
quantity=quantity,
quantity_unit=quantity_unit,
type_key=type_key,
artefact_type=artefact_type,
artefact_kind=artefact_kind,
primary_scope_id=primary_scope_id,
primary_scope_name=primary_scope_name,
primary_scope_type=primary_scope_type,
storage_node_id=storage_node_id,
storage_display_name=storage_display_name,
storage_node_type=storage_node_type,
last_event_type=last_event_type,
last_event_at=last_event_at,
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
    name: Union[Unset, str] = UNSET,
    status: Union[Unset, str] = UNSET,
    is_virtual: Union[Unset, str] = UNSET,
    quantity: Union[Unset, str] = UNSET,
    quantity_unit: Union[Unset, str] = UNSET,
    type_key: Union[Unset, str] = UNSET,
    artefact_type: Union[Unset, str] = UNSET,
    artefact_kind: Union[Unset, str] = UNSET,
    primary_scope_id: Union[Unset, str] = UNSET,
    primary_scope_name: Union[Unset, str] = UNSET,
    primary_scope_type: Union[Unset, str] = UNSET,
    storage_node_id: Union[Unset, str] = UNSET,
    storage_display_name: Union[Unset, str] = UNSET,
    storage_node_type: Union[Unset, str] = UNSET,
    last_event_type: Union[Unset, str] = UNSET,
    last_event_at: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVAccessibleArtefactsPrefer] = UNSET,

) -> Optional[Union[Any, list['VAccessibleArtefacts']]]:
    """ 
    Args:
        artefact_id (Union[Unset, str]):
        name (Union[Unset, str]):
        status (Union[Unset, str]):
        is_virtual (Union[Unset, str]):
        quantity (Union[Unset, str]):
        quantity_unit (Union[Unset, str]):
        type_key (Union[Unset, str]):
        artefact_type (Union[Unset, str]):
        artefact_kind (Union[Unset, str]):
        primary_scope_id (Union[Unset, str]):
        primary_scope_name (Union[Unset, str]):
        primary_scope_type (Union[Unset, str]):
        storage_node_id (Union[Unset, str]):
        storage_display_name (Union[Unset, str]):
        storage_node_type (Union[Unset, str]):
        last_event_type (Union[Unset, str]):
        last_event_at (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVAccessibleArtefactsPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Union[Any, list['VAccessibleArtefacts']]
     """


    return (await asyncio_detailed(
        client=client,
artefact_id=artefact_id,
name=name,
status=status,
is_virtual=is_virtual,
quantity=quantity,
quantity_unit=quantity_unit,
type_key=type_key,
artefact_type=artefact_type,
artefact_kind=artefact_kind,
primary_scope_id=primary_scope_id,
primary_scope_name=primary_scope_name,
primary_scope_type=primary_scope_type,
storage_node_id=storage_node_id,
storage_display_name=storage_display_name,
storage_node_type=storage_node_type,
last_event_type=last_event_type,
last_event_at=last_event_at,
select=select,
order=order,
offset=offset,
limit=limit,
range_=range_,
range_unit=range_unit,
prefer=prefer,

    )).parsed
