from http import HTTPStatus
from typing import Any, Optional, Union, cast

import httpx

from ...client import AuthenticatedClient, Client
from ...types import Response, UNSET
from ... import errors

from ...models.delete_scope_role_inheritance_prefer import DeleteScopeRoleInheritancePrefer
from ...types import UNSET, Unset
from typing import Union



def _get_kwargs(
    *,
    parent_scope_type: Union[Unset, str] = UNSET,
    child_scope_type: Union[Unset, str] = UNSET,
    parent_role_name: Union[Unset, str] = UNSET,
    child_role_name: Union[Unset, str] = UNSET,
    is_active: Union[Unset, str] = UNSET,
    prefer: Union[Unset, DeleteScopeRoleInheritancePrefer] = UNSET,

) -> dict[str, Any]:
    headers: dict[str, Any] = {}
    if not isinstance(prefer, Unset):
        headers["Prefer"] = str(prefer)




    

    params: dict[str, Any] = {}

    params["parent_scope_type"] = parent_scope_type

    params["child_scope_type"] = child_scope_type

    params["parent_role_name"] = parent_role_name

    params["child_role_name"] = child_role_name

    params["is_active"] = is_active


    params = {k: v for k, v in params.items() if v is not UNSET and v is not None}


    _kwargs: dict[str, Any] = {
        "method": "delete",
        "url": "/scope_role_inheritance",
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
    parent_scope_type: Union[Unset, str] = UNSET,
    child_scope_type: Union[Unset, str] = UNSET,
    parent_role_name: Union[Unset, str] = UNSET,
    child_role_name: Union[Unset, str] = UNSET,
    is_active: Union[Unset, str] = UNSET,
    prefer: Union[Unset, DeleteScopeRoleInheritancePrefer] = UNSET,

) -> Response[Any]:
    """ 
    Args:
        parent_scope_type (Union[Unset, str]):
        child_scope_type (Union[Unset, str]):
        parent_role_name (Union[Unset, str]):
        child_role_name (Union[Unset, str]):
        is_active (Union[Unset, str]):
        prefer (Union[Unset, DeleteScopeRoleInheritancePrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        parent_scope_type=parent_scope_type,
child_scope_type=child_scope_type,
parent_role_name=parent_role_name,
child_role_name=child_role_name,
is_active=is_active,
prefer=prefer,

    )

    response = client.get_httpx_client().request(
        **kwargs,
    )

    return _build_response(client=client, response=response)


async def asyncio_detailed(
    *,
    client: Union[AuthenticatedClient, Client],
    parent_scope_type: Union[Unset, str] = UNSET,
    child_scope_type: Union[Unset, str] = UNSET,
    parent_role_name: Union[Unset, str] = UNSET,
    child_role_name: Union[Unset, str] = UNSET,
    is_active: Union[Unset, str] = UNSET,
    prefer: Union[Unset, DeleteScopeRoleInheritancePrefer] = UNSET,

) -> Response[Any]:
    """ 
    Args:
        parent_scope_type (Union[Unset, str]):
        child_scope_type (Union[Unset, str]):
        parent_role_name (Union[Unset, str]):
        child_role_name (Union[Unset, str]):
        is_active (Union[Unset, str]):
        prefer (Union[Unset, DeleteScopeRoleInheritancePrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        parent_scope_type=parent_scope_type,
child_scope_type=child_scope_type,
parent_role_name=parent_role_name,
child_role_name=child_role_name,
is_active=is_active,
prefer=prefer,

    )

    response = await client.get_async_httpx_client().request(
        **kwargs
    )

    return _build_response(client=client, response=response)

