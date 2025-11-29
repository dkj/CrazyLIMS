from http import HTTPStatus
from typing import Any, Optional, Union, cast

import httpx

from ...client import AuthenticatedClient, Client
from ...types import Response, UNSET
from ... import errors

from ...models.delete_scope_memberships_prefer import DeleteScopeMembershipsPrefer
from ...types import UNSET, Unset
from typing import Union



def _get_kwargs(
    *,
    scope_membership_id: Union[Unset, str] = UNSET,
    scope_id: Union[Unset, str] = UNSET,
    user_id: Union[Unset, str] = UNSET,
    role_name: Union[Unset, str] = UNSET,
    granted_by: Union[Unset, str] = UNSET,
    granted_at: Union[Unset, str] = UNSET,
    expires_at: Union[Unset, str] = UNSET,
    is_active: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    prefer: Union[Unset, DeleteScopeMembershipsPrefer] = UNSET,

) -> dict[str, Any]:
    headers: dict[str, Any] = {}
    if not isinstance(prefer, Unset):
        headers["Prefer"] = str(prefer)




    

    params: dict[str, Any] = {}

    params["scope_membership_id"] = scope_membership_id

    params["scope_id"] = scope_id

    params["user_id"] = user_id

    params["role_name"] = role_name

    params["granted_by"] = granted_by

    params["granted_at"] = granted_at

    params["expires_at"] = expires_at

    params["is_active"] = is_active

    params["metadata"] = metadata


    params = {k: v for k, v in params.items() if v is not UNSET and v is not None}


    _kwargs: dict[str, Any] = {
        "method": "delete",
        "url": "/scope_memberships",
        "params": params,
    }


    _kwargs["headers"] = headers
    return _kwargs



def _parse_response(*, client: Union[AuthenticatedClient, Client], response: httpx.Response) -> Optional[Any]:
    if response.status_code == 204:
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
    scope_membership_id: Union[Unset, str] = UNSET,
    scope_id: Union[Unset, str] = UNSET,
    user_id: Union[Unset, str] = UNSET,
    role_name: Union[Unset, str] = UNSET,
    granted_by: Union[Unset, str] = UNSET,
    granted_at: Union[Unset, str] = UNSET,
    expires_at: Union[Unset, str] = UNSET,
    is_active: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    prefer: Union[Unset, DeleteScopeMembershipsPrefer] = UNSET,

) -> Response[Any]:
    """ 
    Args:
        scope_membership_id (Union[Unset, str]):
        scope_id (Union[Unset, str]):
        user_id (Union[Unset, str]):
        role_name (Union[Unset, str]):
        granted_by (Union[Unset, str]):
        granted_at (Union[Unset, str]):
        expires_at (Union[Unset, str]):
        is_active (Union[Unset, str]):
        metadata (Union[Unset, str]):
        prefer (Union[Unset, DeleteScopeMembershipsPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        scope_membership_id=scope_membership_id,
scope_id=scope_id,
user_id=user_id,
role_name=role_name,
granted_by=granted_by,
granted_at=granted_at,
expires_at=expires_at,
is_active=is_active,
metadata=metadata,
prefer=prefer,

    )

    response = client.get_httpx_client().request(
        **kwargs,
    )

    return _build_response(client=client, response=response)


async def asyncio_detailed(
    *,
    client: Union[AuthenticatedClient, Client],
    scope_membership_id: Union[Unset, str] = UNSET,
    scope_id: Union[Unset, str] = UNSET,
    user_id: Union[Unset, str] = UNSET,
    role_name: Union[Unset, str] = UNSET,
    granted_by: Union[Unset, str] = UNSET,
    granted_at: Union[Unset, str] = UNSET,
    expires_at: Union[Unset, str] = UNSET,
    is_active: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    prefer: Union[Unset, DeleteScopeMembershipsPrefer] = UNSET,

) -> Response[Any]:
    """ 
    Args:
        scope_membership_id (Union[Unset, str]):
        scope_id (Union[Unset, str]):
        user_id (Union[Unset, str]):
        role_name (Union[Unset, str]):
        granted_by (Union[Unset, str]):
        granted_at (Union[Unset, str]):
        expires_at (Union[Unset, str]):
        is_active (Union[Unset, str]):
        metadata (Union[Unset, str]):
        prefer (Union[Unset, DeleteScopeMembershipsPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        scope_membership_id=scope_membership_id,
scope_id=scope_id,
user_id=user_id,
role_name=role_name,
granted_by=granted_by,
granted_at=granted_at,
expires_at=expires_at,
is_active=is_active,
metadata=metadata,
prefer=prefer,

    )

    response = await client.get_async_httpx_client().request(
        **kwargs
    )

    return _build_response(client=client, response=response)

