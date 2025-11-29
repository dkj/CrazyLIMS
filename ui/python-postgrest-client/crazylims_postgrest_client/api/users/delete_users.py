from http import HTTPStatus
from typing import Any, Optional, Union, cast

import httpx

from ...client import AuthenticatedClient, Client
from ...types import Response, UNSET
from ... import errors

from ...models.delete_users_prefer import DeleteUsersPrefer
from ...types import UNSET, Unset
from typing import Union



def _get_kwargs(
    *,
    id: Union[Unset, str] = UNSET,
    external_id: Union[Unset, str] = UNSET,
    email: Union[Unset, str] = UNSET,
    full_name: Union[Unset, str] = UNSET,
    default_role: Union[Unset, str] = UNSET,
    is_service_account: Union[Unset, str] = UNSET,
    is_active: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    updated_at: Union[Unset, str] = UNSET,
    last_authenticated_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    updated_by: Union[Unset, str] = UNSET,
    prefer: Union[Unset, DeleteUsersPrefer] = UNSET,

) -> dict[str, Any]:
    headers: dict[str, Any] = {}
    if not isinstance(prefer, Unset):
        headers["Prefer"] = str(prefer)




    

    params: dict[str, Any] = {}

    params["id"] = id

    params["external_id"] = external_id

    params["email"] = email

    params["full_name"] = full_name

    params["default_role"] = default_role

    params["is_service_account"] = is_service_account

    params["is_active"] = is_active

    params["metadata"] = metadata

    params["created_at"] = created_at

    params["updated_at"] = updated_at

    params["last_authenticated_at"] = last_authenticated_at

    params["created_by"] = created_by

    params["updated_by"] = updated_by


    params = {k: v for k, v in params.items() if v is not UNSET and v is not None}


    _kwargs: dict[str, Any] = {
        "method": "delete",
        "url": "/users",
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
    id: Union[Unset, str] = UNSET,
    external_id: Union[Unset, str] = UNSET,
    email: Union[Unset, str] = UNSET,
    full_name: Union[Unset, str] = UNSET,
    default_role: Union[Unset, str] = UNSET,
    is_service_account: Union[Unset, str] = UNSET,
    is_active: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    updated_at: Union[Unset, str] = UNSET,
    last_authenticated_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    updated_by: Union[Unset, str] = UNSET,
    prefer: Union[Unset, DeleteUsersPrefer] = UNSET,

) -> Response[Any]:
    """ 
    Args:
        id (Union[Unset, str]):
        external_id (Union[Unset, str]):
        email (Union[Unset, str]):
        full_name (Union[Unset, str]):
        default_role (Union[Unset, str]):
        is_service_account (Union[Unset, str]):
        is_active (Union[Unset, str]):
        metadata (Union[Unset, str]):
        created_at (Union[Unset, str]):
        updated_at (Union[Unset, str]):
        last_authenticated_at (Union[Unset, str]):
        created_by (Union[Unset, str]):
        updated_by (Union[Unset, str]):
        prefer (Union[Unset, DeleteUsersPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        id=id,
external_id=external_id,
email=email,
full_name=full_name,
default_role=default_role,
is_service_account=is_service_account,
is_active=is_active,
metadata=metadata,
created_at=created_at,
updated_at=updated_at,
last_authenticated_at=last_authenticated_at,
created_by=created_by,
updated_by=updated_by,
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
    external_id: Union[Unset, str] = UNSET,
    email: Union[Unset, str] = UNSET,
    full_name: Union[Unset, str] = UNSET,
    default_role: Union[Unset, str] = UNSET,
    is_service_account: Union[Unset, str] = UNSET,
    is_active: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    updated_at: Union[Unset, str] = UNSET,
    last_authenticated_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    updated_by: Union[Unset, str] = UNSET,
    prefer: Union[Unset, DeleteUsersPrefer] = UNSET,

) -> Response[Any]:
    """ 
    Args:
        id (Union[Unset, str]):
        external_id (Union[Unset, str]):
        email (Union[Unset, str]):
        full_name (Union[Unset, str]):
        default_role (Union[Unset, str]):
        is_service_account (Union[Unset, str]):
        is_active (Union[Unset, str]):
        metadata (Union[Unset, str]):
        created_at (Union[Unset, str]):
        updated_at (Union[Unset, str]):
        last_authenticated_at (Union[Unset, str]):
        created_by (Union[Unset, str]):
        updated_by (Union[Unset, str]):
        prefer (Union[Unset, DeleteUsersPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        id=id,
external_id=external_id,
email=email,
full_name=full_name,
default_role=default_role,
is_service_account=is_service_account,
is_active=is_active,
metadata=metadata,
created_at=created_at,
updated_at=updated_at,
last_authenticated_at=last_authenticated_at,
created_by=created_by,
updated_by=updated_by,
prefer=prefer,

    )

    response = await client.get_async_httpx_client().request(
        **kwargs
    )

    return _build_response(client=client, response=response)

