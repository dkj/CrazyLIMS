from http import HTTPStatus
from typing import Any, Optional, Union, cast

import httpx

from ...client import AuthenticatedClient, Client
from ...types import Response, UNSET
from ... import errors

from ...models.get_v_handover_overview_prefer import GetVHandoverOverviewPrefer
from ...models.v_handover_overview import VHandoverOverview
from ...types import UNSET, Unset
from typing import cast
from typing import Union



def _get_kwargs(
    *,
    research_artefact_id: Union[Unset, str] = UNSET,
    research_artefact_name: Union[Unset, str] = UNSET,
    research_scope_keys: Union[Unset, str] = UNSET,
    ops_artefact_id: Union[Unset, str] = UNSET,
    ops_artefact_name: Union[Unset, str] = UNSET,
    ops_scope_keys: Union[Unset, str] = UNSET,
    research_transfer_state: Union[Unset, str] = UNSET,
    ops_transfer_state: Union[Unset, str] = UNSET,
    propagation_whitelist: Union[Unset, str] = UNSET,
    handover_at: Union[Unset, str] = UNSET,
    returned_at: Union[Unset, str] = UNSET,
    handover_by: Union[Unset, str] = UNSET,
    returned_by: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVHandoverOverviewPrefer] = UNSET,

) -> dict[str, Any]:
    headers: dict[str, Any] = {}
    if not isinstance(range_, Unset):
        headers["Range"] = range_

    if not isinstance(range_unit, Unset):
        headers["Range-Unit"] = range_unit

    if not isinstance(prefer, Unset):
        headers["Prefer"] = str(prefer)




    

    params: dict[str, Any] = {}

    params["research_artefact_id"] = research_artefact_id

    params["research_artefact_name"] = research_artefact_name

    params["research_scope_keys"] = research_scope_keys

    params["ops_artefact_id"] = ops_artefact_id

    params["ops_artefact_name"] = ops_artefact_name

    params["ops_scope_keys"] = ops_scope_keys

    params["research_transfer_state"] = research_transfer_state

    params["ops_transfer_state"] = ops_transfer_state

    params["propagation_whitelist"] = propagation_whitelist

    params["handover_at"] = handover_at

    params["returned_at"] = returned_at

    params["handover_by"] = handover_by

    params["returned_by"] = returned_by

    params["select"] = select

    params["order"] = order

    params["offset"] = offset

    params["limit"] = limit


    params = {k: v for k, v in params.items() if v is not UNSET and v is not None}


    _kwargs: dict[str, Any] = {
        "method": "get",
        "url": "/v_handover_overview",
        "params": params,
    }


    _kwargs["headers"] = headers
    return _kwargs



def _parse_response(*, client: Union[AuthenticatedClient, Client], response: httpx.Response) -> Optional[Union[Any, list['VHandoverOverview']]]:
    if response.status_code == 200:
        response_200 = []
        _response_200 = response.json()
        for response_200_item_data in (_response_200):
            response_200_item = VHandoverOverview.from_dict(response_200_item_data)



            response_200.append(response_200_item)

        return response_200

    if response.status_code == 206:
        response_206 = cast(Any, None)
        return response_206

    if client.raise_on_unexpected_status:
        raise errors.UnexpectedStatus(response.status_code, response.content)
    else:
        return None


def _build_response(*, client: Union[AuthenticatedClient, Client], response: httpx.Response) -> Response[Union[Any, list['VHandoverOverview']]]:
    return Response(
        status_code=HTTPStatus(response.status_code),
        content=response.content,
        headers=response.headers,
        parsed=_parse_response(client=client, response=response),
    )


def sync_detailed(
    *,
    client: Union[AuthenticatedClient, Client],
    research_artefact_id: Union[Unset, str] = UNSET,
    research_artefact_name: Union[Unset, str] = UNSET,
    research_scope_keys: Union[Unset, str] = UNSET,
    ops_artefact_id: Union[Unset, str] = UNSET,
    ops_artefact_name: Union[Unset, str] = UNSET,
    ops_scope_keys: Union[Unset, str] = UNSET,
    research_transfer_state: Union[Unset, str] = UNSET,
    ops_transfer_state: Union[Unset, str] = UNSET,
    propagation_whitelist: Union[Unset, str] = UNSET,
    handover_at: Union[Unset, str] = UNSET,
    returned_at: Union[Unset, str] = UNSET,
    handover_by: Union[Unset, str] = UNSET,
    returned_by: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVHandoverOverviewPrefer] = UNSET,

) -> Response[Union[Any, list['VHandoverOverview']]]:
    """ Summarises handover duplicates, scope memberships, transfer state, and propagation metadata for UI
    consumption.

    Args:
        research_artefact_id (Union[Unset, str]):
        research_artefact_name (Union[Unset, str]):
        research_scope_keys (Union[Unset, str]):
        ops_artefact_id (Union[Unset, str]):
        ops_artefact_name (Union[Unset, str]):
        ops_scope_keys (Union[Unset, str]):
        research_transfer_state (Union[Unset, str]):
        ops_transfer_state (Union[Unset, str]):
        propagation_whitelist (Union[Unset, str]):
        handover_at (Union[Unset, str]):
        returned_at (Union[Unset, str]):
        handover_by (Union[Unset, str]):
        returned_by (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVHandoverOverviewPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Union[Any, list['VHandoverOverview']]]
     """


    kwargs = _get_kwargs(
        research_artefact_id=research_artefact_id,
research_artefact_name=research_artefact_name,
research_scope_keys=research_scope_keys,
ops_artefact_id=ops_artefact_id,
ops_artefact_name=ops_artefact_name,
ops_scope_keys=ops_scope_keys,
research_transfer_state=research_transfer_state,
ops_transfer_state=ops_transfer_state,
propagation_whitelist=propagation_whitelist,
handover_at=handover_at,
returned_at=returned_at,
handover_by=handover_by,
returned_by=returned_by,
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
    research_artefact_id: Union[Unset, str] = UNSET,
    research_artefact_name: Union[Unset, str] = UNSET,
    research_scope_keys: Union[Unset, str] = UNSET,
    ops_artefact_id: Union[Unset, str] = UNSET,
    ops_artefact_name: Union[Unset, str] = UNSET,
    ops_scope_keys: Union[Unset, str] = UNSET,
    research_transfer_state: Union[Unset, str] = UNSET,
    ops_transfer_state: Union[Unset, str] = UNSET,
    propagation_whitelist: Union[Unset, str] = UNSET,
    handover_at: Union[Unset, str] = UNSET,
    returned_at: Union[Unset, str] = UNSET,
    handover_by: Union[Unset, str] = UNSET,
    returned_by: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVHandoverOverviewPrefer] = UNSET,

) -> Optional[Union[Any, list['VHandoverOverview']]]:
    """ Summarises handover duplicates, scope memberships, transfer state, and propagation metadata for UI
    consumption.

    Args:
        research_artefact_id (Union[Unset, str]):
        research_artefact_name (Union[Unset, str]):
        research_scope_keys (Union[Unset, str]):
        ops_artefact_id (Union[Unset, str]):
        ops_artefact_name (Union[Unset, str]):
        ops_scope_keys (Union[Unset, str]):
        research_transfer_state (Union[Unset, str]):
        ops_transfer_state (Union[Unset, str]):
        propagation_whitelist (Union[Unset, str]):
        handover_at (Union[Unset, str]):
        returned_at (Union[Unset, str]):
        handover_by (Union[Unset, str]):
        returned_by (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVHandoverOverviewPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Union[Any, list['VHandoverOverview']]
     """


    return sync_detailed(
        client=client,
research_artefact_id=research_artefact_id,
research_artefact_name=research_artefact_name,
research_scope_keys=research_scope_keys,
ops_artefact_id=ops_artefact_id,
ops_artefact_name=ops_artefact_name,
ops_scope_keys=ops_scope_keys,
research_transfer_state=research_transfer_state,
ops_transfer_state=ops_transfer_state,
propagation_whitelist=propagation_whitelist,
handover_at=handover_at,
returned_at=returned_at,
handover_by=handover_by,
returned_by=returned_by,
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
    research_artefact_id: Union[Unset, str] = UNSET,
    research_artefact_name: Union[Unset, str] = UNSET,
    research_scope_keys: Union[Unset, str] = UNSET,
    ops_artefact_id: Union[Unset, str] = UNSET,
    ops_artefact_name: Union[Unset, str] = UNSET,
    ops_scope_keys: Union[Unset, str] = UNSET,
    research_transfer_state: Union[Unset, str] = UNSET,
    ops_transfer_state: Union[Unset, str] = UNSET,
    propagation_whitelist: Union[Unset, str] = UNSET,
    handover_at: Union[Unset, str] = UNSET,
    returned_at: Union[Unset, str] = UNSET,
    handover_by: Union[Unset, str] = UNSET,
    returned_by: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVHandoverOverviewPrefer] = UNSET,

) -> Response[Union[Any, list['VHandoverOverview']]]:
    """ Summarises handover duplicates, scope memberships, transfer state, and propagation metadata for UI
    consumption.

    Args:
        research_artefact_id (Union[Unset, str]):
        research_artefact_name (Union[Unset, str]):
        research_scope_keys (Union[Unset, str]):
        ops_artefact_id (Union[Unset, str]):
        ops_artefact_name (Union[Unset, str]):
        ops_scope_keys (Union[Unset, str]):
        research_transfer_state (Union[Unset, str]):
        ops_transfer_state (Union[Unset, str]):
        propagation_whitelist (Union[Unset, str]):
        handover_at (Union[Unset, str]):
        returned_at (Union[Unset, str]):
        handover_by (Union[Unset, str]):
        returned_by (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVHandoverOverviewPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Union[Any, list['VHandoverOverview']]]
     """


    kwargs = _get_kwargs(
        research_artefact_id=research_artefact_id,
research_artefact_name=research_artefact_name,
research_scope_keys=research_scope_keys,
ops_artefact_id=ops_artefact_id,
ops_artefact_name=ops_artefact_name,
ops_scope_keys=ops_scope_keys,
research_transfer_state=research_transfer_state,
ops_transfer_state=ops_transfer_state,
propagation_whitelist=propagation_whitelist,
handover_at=handover_at,
returned_at=returned_at,
handover_by=handover_by,
returned_by=returned_by,
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
    research_artefact_id: Union[Unset, str] = UNSET,
    research_artefact_name: Union[Unset, str] = UNSET,
    research_scope_keys: Union[Unset, str] = UNSET,
    ops_artefact_id: Union[Unset, str] = UNSET,
    ops_artefact_name: Union[Unset, str] = UNSET,
    ops_scope_keys: Union[Unset, str] = UNSET,
    research_transfer_state: Union[Unset, str] = UNSET,
    ops_transfer_state: Union[Unset, str] = UNSET,
    propagation_whitelist: Union[Unset, str] = UNSET,
    handover_at: Union[Unset, str] = UNSET,
    returned_at: Union[Unset, str] = UNSET,
    handover_by: Union[Unset, str] = UNSET,
    returned_by: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVHandoverOverviewPrefer] = UNSET,

) -> Optional[Union[Any, list['VHandoverOverview']]]:
    """ Summarises handover duplicates, scope memberships, transfer state, and propagation metadata for UI
    consumption.

    Args:
        research_artefact_id (Union[Unset, str]):
        research_artefact_name (Union[Unset, str]):
        research_scope_keys (Union[Unset, str]):
        ops_artefact_id (Union[Unset, str]):
        ops_artefact_name (Union[Unset, str]):
        ops_scope_keys (Union[Unset, str]):
        research_transfer_state (Union[Unset, str]):
        ops_transfer_state (Union[Unset, str]):
        propagation_whitelist (Union[Unset, str]):
        handover_at (Union[Unset, str]):
        returned_at (Union[Unset, str]):
        handover_by (Union[Unset, str]):
        returned_by (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVHandoverOverviewPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Union[Any, list['VHandoverOverview']]
     """


    return (await asyncio_detailed(
        client=client,
research_artefact_id=research_artefact_id,
research_artefact_name=research_artefact_name,
research_scope_keys=research_scope_keys,
ops_artefact_id=ops_artefact_id,
ops_artefact_name=ops_artefact_name,
ops_scope_keys=ops_scope_keys,
research_transfer_state=research_transfer_state,
ops_transfer_state=ops_transfer_state,
propagation_whitelist=propagation_whitelist,
handover_at=handover_at,
returned_at=returned_at,
handover_by=handover_by,
returned_by=returned_by,
select=select,
order=order,
offset=offset,
limit=limit,
range_=range_,
range_unit=range_unit,
prefer=prefer,

    )).parsed
