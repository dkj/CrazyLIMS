from http import HTTPStatus
from typing import Any, Optional, Union, cast

import httpx

from ...client import AuthenticatedClient, Client
from ...types import Response, UNSET
from ... import errors

from ...models.get_api_tokens_prefer import GetApiTokensPrefer
from ...types import UNSET, Unset
from typing import Union



def _get_kwargs(
    *,
    id: Union[Unset, str] = UNSET,
    api_client_id: Union[Unset, str] = UNSET,
    user_id: Union[Unset, str] = UNSET,
    token_digest: Union[Unset, str] = UNSET,
    token_hint: Union[Unset, str] = UNSET,
    allowed_roles: Union[Unset, str] = UNSET,
    expires_at: Union[Unset, str] = UNSET,
    revoked_at: Union[Unset, str] = UNSET,
    revoked_by: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetApiTokensPrefer] = UNSET,

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

    params["api_client_id"] = api_client_id

    params["user_id"] = user_id

    params["token_digest"] = token_digest

    params["token_hint"] = token_hint

    params["allowed_roles"] = allowed_roles

    params["expires_at"] = expires_at

    params["revoked_at"] = revoked_at

    params["revoked_by"] = revoked_by

    params["metadata"] = metadata

    params["created_at"] = created_at

    params["created_by"] = created_by

    params["select"] = select

    params["order"] = order

    params["offset"] = offset

    params["limit"] = limit


    params = {k: v for k, v in params.items() if v is not UNSET and v is not None}


    _kwargs: dict[str, Any] = {
        "method": "get",
        "url": "/api_tokens",
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
    id: Union[Unset, str] = UNSET,
    api_client_id: Union[Unset, str] = UNSET,
    user_id: Union[Unset, str] = UNSET,
    token_digest: Union[Unset, str] = UNSET,
    token_hint: Union[Unset, str] = UNSET,
    allowed_roles: Union[Unset, str] = UNSET,
    expires_at: Union[Unset, str] = UNSET,
    revoked_at: Union[Unset, str] = UNSET,
    revoked_by: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetApiTokensPrefer] = UNSET,

) -> Response[Any]:
    """ 
    Args:
        id (Union[Unset, str]):
        api_client_id (Union[Unset, str]):
        user_id (Union[Unset, str]):
        token_digest (Union[Unset, str]):
        token_hint (Union[Unset, str]):
        allowed_roles (Union[Unset, str]):
        expires_at (Union[Unset, str]):
        revoked_at (Union[Unset, str]):
        revoked_by (Union[Unset, str]):
        metadata (Union[Unset, str]):
        created_at (Union[Unset, str]):
        created_by (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetApiTokensPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        id=id,
api_client_id=api_client_id,
user_id=user_id,
token_digest=token_digest,
token_hint=token_hint,
allowed_roles=allowed_roles,
expires_at=expires_at,
revoked_at=revoked_at,
revoked_by=revoked_by,
metadata=metadata,
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


async def asyncio_detailed(
    *,
    client: Union[AuthenticatedClient, Client],
    id: Union[Unset, str] = UNSET,
    api_client_id: Union[Unset, str] = UNSET,
    user_id: Union[Unset, str] = UNSET,
    token_digest: Union[Unset, str] = UNSET,
    token_hint: Union[Unset, str] = UNSET,
    allowed_roles: Union[Unset, str] = UNSET,
    expires_at: Union[Unset, str] = UNSET,
    revoked_at: Union[Unset, str] = UNSET,
    revoked_by: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetApiTokensPrefer] = UNSET,

) -> Response[Any]:
    """ 
    Args:
        id (Union[Unset, str]):
        api_client_id (Union[Unset, str]):
        user_id (Union[Unset, str]):
        token_digest (Union[Unset, str]):
        token_hint (Union[Unset, str]):
        allowed_roles (Union[Unset, str]):
        expires_at (Union[Unset, str]):
        revoked_at (Union[Unset, str]):
        revoked_by (Union[Unset, str]):
        metadata (Union[Unset, str]):
        created_at (Union[Unset, str]):
        created_by (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetApiTokensPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        id=id,
api_client_id=api_client_id,
user_id=user_id,
token_digest=token_digest,
token_hint=token_hint,
allowed_roles=allowed_roles,
expires_at=expires_at,
revoked_at=revoked_at,
revoked_by=revoked_by,
metadata=metadata,
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

