from http import HTTPStatus
from typing import Any, Optional, Union, cast

import httpx

from ...client import AuthenticatedClient, Client
from ...types import Response, UNSET
from ... import errors

from ...models.patch_roles_prefer import PatchRolesPrefer
from ...models.roles import Roles
from ...types import UNSET, Unset
from typing import cast
from typing import Union



def _get_kwargs(
    *,
    body: Union[
        Roles,
        Roles,
        Roles,
    ],
    role_name: Union[Unset, str] = UNSET,
    display_name: Union[Unset, str] = UNSET,
    description: Union[Unset, str] = UNSET,
    is_system_role: Union[Unset, str] = UNSET,
    is_assignable: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    prefer: Union[Unset, PatchRolesPrefer] = UNSET,

) -> dict[str, Any]:
    headers: dict[str, Any] = {}
    if not isinstance(prefer, Unset):
        headers["Prefer"] = str(prefer)




    

    params: dict[str, Any] = {}

    params["role_name"] = role_name

    params["display_name"] = display_name

    params["description"] = description

    params["is_system_role"] = is_system_role

    params["is_assignable"] = is_assignable

    params["created_at"] = created_at

    params["created_by"] = created_by


    params = {k: v for k, v in params.items() if v is not UNSET and v is not None}


    _kwargs: dict[str, Any] = {
        "method": "patch",
        "url": "/roles",
        "params": params,
    }

    if isinstance(body, Roles):
        _kwargs["json"] = body.to_dict()


        headers["Content-Type"] = "application/json"
    if isinstance(body, Roles):
        _kwargs["json"] = body.to_dict()


        headers["Content-Type"] = "application/vnd.pgrst.object+json;nulls=stripped"
    if isinstance(body, Roles):
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
        Roles,
        Roles,
        Roles,
    ],
    role_name: Union[Unset, str] = UNSET,
    display_name: Union[Unset, str] = UNSET,
    description: Union[Unset, str] = UNSET,
    is_system_role: Union[Unset, str] = UNSET,
    is_assignable: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    prefer: Union[Unset, PatchRolesPrefer] = UNSET,

) -> Response[Any]:
    """ 
    Args:
        role_name (Union[Unset, str]):
        display_name (Union[Unset, str]):
        description (Union[Unset, str]):
        is_system_role (Union[Unset, str]):
        is_assignable (Union[Unset, str]):
        created_at (Union[Unset, str]):
        created_by (Union[Unset, str]):
        prefer (Union[Unset, PatchRolesPrefer]):
        body (Roles):
        body (Roles):
        body (Roles):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        body=body,
role_name=role_name,
display_name=display_name,
description=description,
is_system_role=is_system_role,
is_assignable=is_assignable,
created_at=created_at,
created_by=created_by,
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
        Roles,
        Roles,
        Roles,
    ],
    role_name: Union[Unset, str] = UNSET,
    display_name: Union[Unset, str] = UNSET,
    description: Union[Unset, str] = UNSET,
    is_system_role: Union[Unset, str] = UNSET,
    is_assignable: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    prefer: Union[Unset, PatchRolesPrefer] = UNSET,

) -> Response[Any]:
    """ 
    Args:
        role_name (Union[Unset, str]):
        display_name (Union[Unset, str]):
        description (Union[Unset, str]):
        is_system_role (Union[Unset, str]):
        is_assignable (Union[Unset, str]):
        created_at (Union[Unset, str]):
        created_by (Union[Unset, str]):
        prefer (Union[Unset, PatchRolesPrefer]):
        body (Roles):
        body (Roles):
        body (Roles):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        body=body,
role_name=role_name,
display_name=display_name,
description=description,
is_system_role=is_system_role,
is_assignable=is_assignable,
created_at=created_at,
created_by=created_by,
prefer=prefer,

    )

    response = await client.get_async_httpx_client().request(
        **kwargs
    )

    return _build_response(client=client, response=response)

