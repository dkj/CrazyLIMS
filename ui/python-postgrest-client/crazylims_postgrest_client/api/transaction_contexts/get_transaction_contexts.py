from http import HTTPStatus
from typing import Any, Optional, Union, cast

import httpx

from ...client import AuthenticatedClient, Client
from ...types import Response, UNSET
from ... import errors

from ...models.get_transaction_contexts_prefer import GetTransactionContextsPrefer
from ...types import UNSET, Unset
from typing import Union



def _get_kwargs(
    *,
    txn_id: Union[Unset, str] = UNSET,
    actor_id: Union[Unset, str] = UNSET,
    actor_identity: Union[Unset, str] = UNSET,
    actor_roles: Union[Unset, str] = UNSET,
    impersonated_roles: Union[Unset, str] = UNSET,
    jwt_claims: Union[Unset, str] = UNSET,
    client_app: Union[Unset, str] = UNSET,
    client_ip: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    started_at: Union[Unset, str] = UNSET,
    finished_at: Union[Unset, str] = UNSET,
    finished_status: Union[Unset, str] = UNSET,
    finished_reason: Union[Unset, str] = UNSET,
    finished_by: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetTransactionContextsPrefer] = UNSET,

) -> dict[str, Any]:
    headers: dict[str, Any] = {}
    if not isinstance(range_, Unset):
        headers["Range"] = range_

    if not isinstance(range_unit, Unset):
        headers["Range-Unit"] = range_unit

    if not isinstance(prefer, Unset):
        headers["Prefer"] = str(prefer)




    

    params: dict[str, Any] = {}

    params["txn_id"] = txn_id

    params["actor_id"] = actor_id

    params["actor_identity"] = actor_identity

    params["actor_roles"] = actor_roles

    params["impersonated_roles"] = impersonated_roles

    params["jwt_claims"] = jwt_claims

    params["client_app"] = client_app

    params["client_ip"] = client_ip

    params["metadata"] = metadata

    params["started_at"] = started_at

    params["finished_at"] = finished_at

    params["finished_status"] = finished_status

    params["finished_reason"] = finished_reason

    params["finished_by"] = finished_by

    params["select"] = select

    params["order"] = order

    params["offset"] = offset

    params["limit"] = limit


    params = {k: v for k, v in params.items() if v is not UNSET and v is not None}


    _kwargs: dict[str, Any] = {
        "method": "get",
        "url": "/transaction_contexts",
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
    txn_id: Union[Unset, str] = UNSET,
    actor_id: Union[Unset, str] = UNSET,
    actor_identity: Union[Unset, str] = UNSET,
    actor_roles: Union[Unset, str] = UNSET,
    impersonated_roles: Union[Unset, str] = UNSET,
    jwt_claims: Union[Unset, str] = UNSET,
    client_app: Union[Unset, str] = UNSET,
    client_ip: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    started_at: Union[Unset, str] = UNSET,
    finished_at: Union[Unset, str] = UNSET,
    finished_status: Union[Unset, str] = UNSET,
    finished_reason: Union[Unset, str] = UNSET,
    finished_by: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetTransactionContextsPrefer] = UNSET,

) -> Response[Any]:
    """ 
    Args:
        txn_id (Union[Unset, str]):
        actor_id (Union[Unset, str]):
        actor_identity (Union[Unset, str]):
        actor_roles (Union[Unset, str]):
        impersonated_roles (Union[Unset, str]):
        jwt_claims (Union[Unset, str]):
        client_app (Union[Unset, str]):
        client_ip (Union[Unset, str]):
        metadata (Union[Unset, str]):
        started_at (Union[Unset, str]):
        finished_at (Union[Unset, str]):
        finished_status (Union[Unset, str]):
        finished_reason (Union[Unset, str]):
        finished_by (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetTransactionContextsPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        txn_id=txn_id,
actor_id=actor_id,
actor_identity=actor_identity,
actor_roles=actor_roles,
impersonated_roles=impersonated_roles,
jwt_claims=jwt_claims,
client_app=client_app,
client_ip=client_ip,
metadata=metadata,
started_at=started_at,
finished_at=finished_at,
finished_status=finished_status,
finished_reason=finished_reason,
finished_by=finished_by,
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
    txn_id: Union[Unset, str] = UNSET,
    actor_id: Union[Unset, str] = UNSET,
    actor_identity: Union[Unset, str] = UNSET,
    actor_roles: Union[Unset, str] = UNSET,
    impersonated_roles: Union[Unset, str] = UNSET,
    jwt_claims: Union[Unset, str] = UNSET,
    client_app: Union[Unset, str] = UNSET,
    client_ip: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    started_at: Union[Unset, str] = UNSET,
    finished_at: Union[Unset, str] = UNSET,
    finished_status: Union[Unset, str] = UNSET,
    finished_reason: Union[Unset, str] = UNSET,
    finished_by: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetTransactionContextsPrefer] = UNSET,

) -> Response[Any]:
    """ 
    Args:
        txn_id (Union[Unset, str]):
        actor_id (Union[Unset, str]):
        actor_identity (Union[Unset, str]):
        actor_roles (Union[Unset, str]):
        impersonated_roles (Union[Unset, str]):
        jwt_claims (Union[Unset, str]):
        client_app (Union[Unset, str]):
        client_ip (Union[Unset, str]):
        metadata (Union[Unset, str]):
        started_at (Union[Unset, str]):
        finished_at (Union[Unset, str]):
        finished_status (Union[Unset, str]):
        finished_reason (Union[Unset, str]):
        finished_by (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetTransactionContextsPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        txn_id=txn_id,
actor_id=actor_id,
actor_identity=actor_identity,
actor_roles=actor_roles,
impersonated_roles=impersonated_roles,
jwt_claims=jwt_claims,
client_app=client_app,
client_ip=client_ip,
metadata=metadata,
started_at=started_at,
finished_at=finished_at,
finished_status=finished_status,
finished_reason=finished_reason,
finished_by=finished_by,
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

