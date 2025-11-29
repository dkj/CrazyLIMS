from http import HTTPStatus
from typing import Any, Optional, Union, cast

import httpx

from ...client import AuthenticatedClient, Client
from ...types import Response, UNSET
from ... import errors

from ...models.get_v_scope_transfer_overview_prefer import GetVScopeTransferOverviewPrefer
from ...models.v_scope_transfer_overview import VScopeTransferOverview
from ...types import UNSET, Unset
from typing import cast
from typing import Union



def _get_kwargs(
    *,
    source_artefact_id: Union[Unset, str] = UNSET,
    source_artefact_name: Union[Unset, str] = UNSET,
    source_scopes: Union[Unset, str] = UNSET,
    target_artefact_id: Union[Unset, str] = UNSET,
    target_artefact_name: Union[Unset, str] = UNSET,
    target_scopes: Union[Unset, str] = UNSET,
    source_transfer_state: Union[Unset, str] = UNSET,
    target_transfer_state: Union[Unset, str] = UNSET,
    propagation_whitelist: Union[Unset, str] = UNSET,
    allowed_roles: Union[Unset, str] = UNSET,
    relationship_type: Union[Unset, str] = UNSET,
    handover_at: Union[Unset, str] = UNSET,
    returned_at: Union[Unset, str] = UNSET,
    handover_by: Union[Unset, str] = UNSET,
    returned_by: Union[Unset, str] = UNSET,
    relationship_metadata: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVScopeTransferOverviewPrefer] = UNSET,

) -> dict[str, Any]:
    headers: dict[str, Any] = {}
    if not isinstance(range_, Unset):
        headers["Range"] = range_

    if not isinstance(range_unit, Unset):
        headers["Range-Unit"] = range_unit

    if not isinstance(prefer, Unset):
        headers["Prefer"] = str(prefer)




    

    params: dict[str, Any] = {}

    params["source_artefact_id"] = source_artefact_id

    params["source_artefact_name"] = source_artefact_name

    params["source_scopes"] = source_scopes

    params["target_artefact_id"] = target_artefact_id

    params["target_artefact_name"] = target_artefact_name

    params["target_scopes"] = target_scopes

    params["source_transfer_state"] = source_transfer_state

    params["target_transfer_state"] = target_transfer_state

    params["propagation_whitelist"] = propagation_whitelist

    params["allowed_roles"] = allowed_roles

    params["relationship_type"] = relationship_type

    params["handover_at"] = handover_at

    params["returned_at"] = returned_at

    params["handover_by"] = handover_by

    params["returned_by"] = returned_by

    params["relationship_metadata"] = relationship_metadata

    params["select"] = select

    params["order"] = order

    params["offset"] = offset

    params["limit"] = limit


    params = {k: v for k, v in params.items() if v is not UNSET and v is not None}


    _kwargs: dict[str, Any] = {
        "method": "get",
        "url": "/v_scope_transfer_overview",
        "params": params,
    }


    _kwargs["headers"] = headers
    return _kwargs



def _parse_response(*, client: Union[AuthenticatedClient, Client], response: httpx.Response) -> Optional[Union[Any, list['VScopeTransferOverview']]]:
    if response.status_code == 200:
        response_200 = []
        _response_200 = response.json()
        for response_200_item_data in (_response_200):
            response_200_item = VScopeTransferOverview.from_dict(response_200_item_data)



            response_200.append(response_200_item)

        return response_200

    if response.status_code == 206:
        response_206 = cast(Any, None)
        return response_206

    if client.raise_on_unexpected_status:
        raise errors.UnexpectedStatus(response.status_code, response.content)
    else:
        return None


def _build_response(*, client: Union[AuthenticatedClient, Client], response: httpx.Response) -> Response[Union[Any, list['VScopeTransferOverview']]]:
    return Response(
        status_code=HTTPStatus(response.status_code),
        content=response.content,
        headers=response.headers,
        parsed=_parse_response(client=client, response=response),
    )


def sync_detailed(
    *,
    client: Union[AuthenticatedClient, Client],
    source_artefact_id: Union[Unset, str] = UNSET,
    source_artefact_name: Union[Unset, str] = UNSET,
    source_scopes: Union[Unset, str] = UNSET,
    target_artefact_id: Union[Unset, str] = UNSET,
    target_artefact_name: Union[Unset, str] = UNSET,
    target_scopes: Union[Unset, str] = UNSET,
    source_transfer_state: Union[Unset, str] = UNSET,
    target_transfer_state: Union[Unset, str] = UNSET,
    propagation_whitelist: Union[Unset, str] = UNSET,
    allowed_roles: Union[Unset, str] = UNSET,
    relationship_type: Union[Unset, str] = UNSET,
    handover_at: Union[Unset, str] = UNSET,
    returned_at: Union[Unset, str] = UNSET,
    handover_by: Union[Unset, str] = UNSET,
    returned_by: Union[Unset, str] = UNSET,
    relationship_metadata: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVScopeTransferOverviewPrefer] = UNSET,

) -> Response[Union[Any, list['VScopeTransferOverview']]]:
    """ Generalised scope-to-scope transfer overview including scope metadata and allowed roles.

    Args:
        source_artefact_id (Union[Unset, str]):
        source_artefact_name (Union[Unset, str]):
        source_scopes (Union[Unset, str]):
        target_artefact_id (Union[Unset, str]):
        target_artefact_name (Union[Unset, str]):
        target_scopes (Union[Unset, str]):
        source_transfer_state (Union[Unset, str]):
        target_transfer_state (Union[Unset, str]):
        propagation_whitelist (Union[Unset, str]):
        allowed_roles (Union[Unset, str]):
        relationship_type (Union[Unset, str]):
        handover_at (Union[Unset, str]):
        returned_at (Union[Unset, str]):
        handover_by (Union[Unset, str]):
        returned_by (Union[Unset, str]):
        relationship_metadata (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVScopeTransferOverviewPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Union[Any, list['VScopeTransferOverview']]]
     """


    kwargs = _get_kwargs(
        source_artefact_id=source_artefact_id,
source_artefact_name=source_artefact_name,
source_scopes=source_scopes,
target_artefact_id=target_artefact_id,
target_artefact_name=target_artefact_name,
target_scopes=target_scopes,
source_transfer_state=source_transfer_state,
target_transfer_state=target_transfer_state,
propagation_whitelist=propagation_whitelist,
allowed_roles=allowed_roles,
relationship_type=relationship_type,
handover_at=handover_at,
returned_at=returned_at,
handover_by=handover_by,
returned_by=returned_by,
relationship_metadata=relationship_metadata,
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
    source_artefact_id: Union[Unset, str] = UNSET,
    source_artefact_name: Union[Unset, str] = UNSET,
    source_scopes: Union[Unset, str] = UNSET,
    target_artefact_id: Union[Unset, str] = UNSET,
    target_artefact_name: Union[Unset, str] = UNSET,
    target_scopes: Union[Unset, str] = UNSET,
    source_transfer_state: Union[Unset, str] = UNSET,
    target_transfer_state: Union[Unset, str] = UNSET,
    propagation_whitelist: Union[Unset, str] = UNSET,
    allowed_roles: Union[Unset, str] = UNSET,
    relationship_type: Union[Unset, str] = UNSET,
    handover_at: Union[Unset, str] = UNSET,
    returned_at: Union[Unset, str] = UNSET,
    handover_by: Union[Unset, str] = UNSET,
    returned_by: Union[Unset, str] = UNSET,
    relationship_metadata: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVScopeTransferOverviewPrefer] = UNSET,

) -> Optional[Union[Any, list['VScopeTransferOverview']]]:
    """ Generalised scope-to-scope transfer overview including scope metadata and allowed roles.

    Args:
        source_artefact_id (Union[Unset, str]):
        source_artefact_name (Union[Unset, str]):
        source_scopes (Union[Unset, str]):
        target_artefact_id (Union[Unset, str]):
        target_artefact_name (Union[Unset, str]):
        target_scopes (Union[Unset, str]):
        source_transfer_state (Union[Unset, str]):
        target_transfer_state (Union[Unset, str]):
        propagation_whitelist (Union[Unset, str]):
        allowed_roles (Union[Unset, str]):
        relationship_type (Union[Unset, str]):
        handover_at (Union[Unset, str]):
        returned_at (Union[Unset, str]):
        handover_by (Union[Unset, str]):
        returned_by (Union[Unset, str]):
        relationship_metadata (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVScopeTransferOverviewPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Union[Any, list['VScopeTransferOverview']]
     """


    return sync_detailed(
        client=client,
source_artefact_id=source_artefact_id,
source_artefact_name=source_artefact_name,
source_scopes=source_scopes,
target_artefact_id=target_artefact_id,
target_artefact_name=target_artefact_name,
target_scopes=target_scopes,
source_transfer_state=source_transfer_state,
target_transfer_state=target_transfer_state,
propagation_whitelist=propagation_whitelist,
allowed_roles=allowed_roles,
relationship_type=relationship_type,
handover_at=handover_at,
returned_at=returned_at,
handover_by=handover_by,
returned_by=returned_by,
relationship_metadata=relationship_metadata,
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
    source_artefact_id: Union[Unset, str] = UNSET,
    source_artefact_name: Union[Unset, str] = UNSET,
    source_scopes: Union[Unset, str] = UNSET,
    target_artefact_id: Union[Unset, str] = UNSET,
    target_artefact_name: Union[Unset, str] = UNSET,
    target_scopes: Union[Unset, str] = UNSET,
    source_transfer_state: Union[Unset, str] = UNSET,
    target_transfer_state: Union[Unset, str] = UNSET,
    propagation_whitelist: Union[Unset, str] = UNSET,
    allowed_roles: Union[Unset, str] = UNSET,
    relationship_type: Union[Unset, str] = UNSET,
    handover_at: Union[Unset, str] = UNSET,
    returned_at: Union[Unset, str] = UNSET,
    handover_by: Union[Unset, str] = UNSET,
    returned_by: Union[Unset, str] = UNSET,
    relationship_metadata: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVScopeTransferOverviewPrefer] = UNSET,

) -> Response[Union[Any, list['VScopeTransferOverview']]]:
    """ Generalised scope-to-scope transfer overview including scope metadata and allowed roles.

    Args:
        source_artefact_id (Union[Unset, str]):
        source_artefact_name (Union[Unset, str]):
        source_scopes (Union[Unset, str]):
        target_artefact_id (Union[Unset, str]):
        target_artefact_name (Union[Unset, str]):
        target_scopes (Union[Unset, str]):
        source_transfer_state (Union[Unset, str]):
        target_transfer_state (Union[Unset, str]):
        propagation_whitelist (Union[Unset, str]):
        allowed_roles (Union[Unset, str]):
        relationship_type (Union[Unset, str]):
        handover_at (Union[Unset, str]):
        returned_at (Union[Unset, str]):
        handover_by (Union[Unset, str]):
        returned_by (Union[Unset, str]):
        relationship_metadata (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVScopeTransferOverviewPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Union[Any, list['VScopeTransferOverview']]]
     """


    kwargs = _get_kwargs(
        source_artefact_id=source_artefact_id,
source_artefact_name=source_artefact_name,
source_scopes=source_scopes,
target_artefact_id=target_artefact_id,
target_artefact_name=target_artefact_name,
target_scopes=target_scopes,
source_transfer_state=source_transfer_state,
target_transfer_state=target_transfer_state,
propagation_whitelist=propagation_whitelist,
allowed_roles=allowed_roles,
relationship_type=relationship_type,
handover_at=handover_at,
returned_at=returned_at,
handover_by=handover_by,
returned_by=returned_by,
relationship_metadata=relationship_metadata,
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
    source_artefact_id: Union[Unset, str] = UNSET,
    source_artefact_name: Union[Unset, str] = UNSET,
    source_scopes: Union[Unset, str] = UNSET,
    target_artefact_id: Union[Unset, str] = UNSET,
    target_artefact_name: Union[Unset, str] = UNSET,
    target_scopes: Union[Unset, str] = UNSET,
    source_transfer_state: Union[Unset, str] = UNSET,
    target_transfer_state: Union[Unset, str] = UNSET,
    propagation_whitelist: Union[Unset, str] = UNSET,
    allowed_roles: Union[Unset, str] = UNSET,
    relationship_type: Union[Unset, str] = UNSET,
    handover_at: Union[Unset, str] = UNSET,
    returned_at: Union[Unset, str] = UNSET,
    handover_by: Union[Unset, str] = UNSET,
    returned_by: Union[Unset, str] = UNSET,
    relationship_metadata: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVScopeTransferOverviewPrefer] = UNSET,

) -> Optional[Union[Any, list['VScopeTransferOverview']]]:
    """ Generalised scope-to-scope transfer overview including scope metadata and allowed roles.

    Args:
        source_artefact_id (Union[Unset, str]):
        source_artefact_name (Union[Unset, str]):
        source_scopes (Union[Unset, str]):
        target_artefact_id (Union[Unset, str]):
        target_artefact_name (Union[Unset, str]):
        target_scopes (Union[Unset, str]):
        source_transfer_state (Union[Unset, str]):
        target_transfer_state (Union[Unset, str]):
        propagation_whitelist (Union[Unset, str]):
        allowed_roles (Union[Unset, str]):
        relationship_type (Union[Unset, str]):
        handover_at (Union[Unset, str]):
        returned_at (Union[Unset, str]):
        handover_by (Union[Unset, str]):
        returned_by (Union[Unset, str]):
        relationship_metadata (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVScopeTransferOverviewPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Union[Any, list['VScopeTransferOverview']]
     """


    return (await asyncio_detailed(
        client=client,
source_artefact_id=source_artefact_id,
source_artefact_name=source_artefact_name,
source_scopes=source_scopes,
target_artefact_id=target_artefact_id,
target_artefact_name=target_artefact_name,
target_scopes=target_scopes,
source_transfer_state=source_transfer_state,
target_transfer_state=target_transfer_state,
propagation_whitelist=propagation_whitelist,
allowed_roles=allowed_roles,
relationship_type=relationship_type,
handover_at=handover_at,
returned_at=returned_at,
handover_by=handover_by,
returned_by=returned_by,
relationship_metadata=relationship_metadata,
select=select,
order=order,
offset=offset,
limit=limit,
range_=range_,
range_unit=range_unit,
prefer=prefer,

    )).parsed
