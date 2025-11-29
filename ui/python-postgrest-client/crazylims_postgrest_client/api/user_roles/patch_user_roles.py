from http import HTTPStatus
from typing import Any, Optional, Union, cast

import httpx

from ...client import AuthenticatedClient, Client
from ...types import Response, UNSET
from ... import errors

from ...models.patch_user_roles_prefer import PatchUserRolesPrefer
from ...models.user_roles import UserRoles
from ...types import UNSET, Unset
from typing import cast
from typing import Union



def _get_kwargs(
    *,
    body: Union[
        UserRoles,
        UserRoles,
        UserRoles,
    ],
    user_id: Union[Unset, str] = UNSET,
    role_name: Union[Unset, str] = UNSET,
    granted_by: Union[Unset, str] = UNSET,
    granted_at: Union[Unset, str] = UNSET,
    prefer: Union[Unset, PatchUserRolesPrefer] = UNSET,

) -> dict[str, Any]:
    headers: dict[str, Any] = {}
    if not isinstance(prefer, Unset):
        headers["Prefer"] = str(prefer)




    

    params: dict[str, Any] = {}

    params["user_id"] = user_id

    params["role_name"] = role_name

    params["granted_by"] = granted_by

    params["granted_at"] = granted_at


    params = {k: v for k, v in params.items() if v is not UNSET and v is not None}


    _kwargs: dict[str, Any] = {
        "method": "patch",
        "url": "/user_roles",
        "params": params,
    }

    if isinstance(body, UserRoles):
        _kwargs["json"] = body.to_dict()


        headers["Content-Type"] = "application/json"
    if isinstance(body, UserRoles):
        _kwargs["json"] = body.to_dict()


        headers["Content-Type"] = "application/vnd.pgrst.object+json;nulls=stripped"
    if isinstance(body, UserRoles):
        _kwargs["json"] = body.to_dict()


        headers["Content-Type"] = "application/vnd.pgrst.object+json"

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
    body: Union[
        UserRoles,
        UserRoles,
        UserRoles,
    ],
    user_id: Union[Unset, str] = UNSET,
    role_name: Union[Unset, str] = UNSET,
    granted_by: Union[Unset, str] = UNSET,
    granted_at: Union[Unset, str] = UNSET,
    prefer: Union[Unset, PatchUserRolesPrefer] = UNSET,

) -> Response[Any]:
    """ 
    Args:
        user_id (Union[Unset, str]):
        role_name (Union[Unset, str]):
        granted_by (Union[Unset, str]):
        granted_at (Union[Unset, str]):
        prefer (Union[Unset, PatchUserRolesPrefer]):
        body (UserRoles):
        body (UserRoles):
        body (UserRoles):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        body=body,
user_id=user_id,
role_name=role_name,
granted_by=granted_by,
granted_at=granted_at,
prefer=prefer,

    )

    response = client.get_httpx_client().request(
        **kwargs,
    )

    return _build_response(client=client, response=response)


async def asyncio_detailed(
    *,
    client: Union[AuthenticatedClient, Client],
    body: Union[
        UserRoles,
        UserRoles,
        UserRoles,
    ],
    user_id: Union[Unset, str] = UNSET,
    role_name: Union[Unset, str] = UNSET,
    granted_by: Union[Unset, str] = UNSET,
    granted_at: Union[Unset, str] = UNSET,
    prefer: Union[Unset, PatchUserRolesPrefer] = UNSET,

) -> Response[Any]:
    """ 
    Args:
        user_id (Union[Unset, str]):
        role_name (Union[Unset, str]):
        granted_by (Union[Unset, str]):
        granted_at (Union[Unset, str]):
        prefer (Union[Unset, PatchUserRolesPrefer]):
        body (UserRoles):
        body (UserRoles):
        body (UserRoles):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        body=body,
user_id=user_id,
role_name=role_name,
granted_by=granted_by,
granted_at=granted_at,
prefer=prefer,

    )

    response = await client.get_async_httpx_client().request(
        **kwargs
    )

    return _build_response(client=client, response=response)

