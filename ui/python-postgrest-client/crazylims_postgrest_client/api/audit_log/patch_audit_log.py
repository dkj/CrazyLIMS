from http import HTTPStatus
from typing import Any, Optional, Union, cast

import httpx

from ...client import AuthenticatedClient, Client
from ...types import Response, UNSET
from ... import errors

from ...models.audit_log import AuditLog
from ...models.patch_audit_log_prefer import PatchAuditLogPrefer
from ...types import UNSET, Unset
from typing import cast
from typing import Union



def _get_kwargs(
    *,
    body: Union[
        AuditLog,
        AuditLog,
        AuditLog,
    ],
    audit_id: Union[Unset, str] = UNSET,
    txn_id: Union[Unset, str] = UNSET,
    schema_name: Union[Unset, str] = UNSET,
    table_name: Union[Unset, str] = UNSET,
    operation: Union[Unset, str] = UNSET,
    primary_key_data: Union[Unset, str] = UNSET,
    row_before: Union[Unset, str] = UNSET,
    row_after: Union[Unset, str] = UNSET,
    actor_id: Union[Unset, str] = UNSET,
    actor_identity: Union[Unset, str] = UNSET,
    actor_roles: Union[Unset, str] = UNSET,
    performed_at: Union[Unset, str] = UNSET,
    prefer: Union[Unset, PatchAuditLogPrefer] = UNSET,

) -> dict[str, Any]:
    headers: dict[str, Any] = {}
    if not isinstance(prefer, Unset):
        headers["Prefer"] = str(prefer)




    

    params: dict[str, Any] = {}

    params["audit_id"] = audit_id

    params["txn_id"] = txn_id

    params["schema_name"] = schema_name

    params["table_name"] = table_name

    params["operation"] = operation

    params["primary_key_data"] = primary_key_data

    params["row_before"] = row_before

    params["row_after"] = row_after

    params["actor_id"] = actor_id

    params["actor_identity"] = actor_identity

    params["actor_roles"] = actor_roles

    params["performed_at"] = performed_at


    params = {k: v for k, v in params.items() if v is not UNSET and v is not None}


    _kwargs: dict[str, Any] = {
        "method": "patch",
        "url": "/audit_log",
        "params": params,
    }

    if isinstance(body, AuditLog):
        _kwargs["json"] = body.to_dict()


        headers["Content-Type"] = "application/json"
    if isinstance(body, AuditLog):
        _kwargs["json"] = body.to_dict()


        headers["Content-Type"] = "application/vnd.pgrst.object+json;nulls=stripped"
    if isinstance(body, AuditLog):
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
        AuditLog,
        AuditLog,
        AuditLog,
    ],
    audit_id: Union[Unset, str] = UNSET,
    txn_id: Union[Unset, str] = UNSET,
    schema_name: Union[Unset, str] = UNSET,
    table_name: Union[Unset, str] = UNSET,
    operation: Union[Unset, str] = UNSET,
    primary_key_data: Union[Unset, str] = UNSET,
    row_before: Union[Unset, str] = UNSET,
    row_after: Union[Unset, str] = UNSET,
    actor_id: Union[Unset, str] = UNSET,
    actor_identity: Union[Unset, str] = UNSET,
    actor_roles: Union[Unset, str] = UNSET,
    performed_at: Union[Unset, str] = UNSET,
    prefer: Union[Unset, PatchAuditLogPrefer] = UNSET,

) -> Response[Any]:
    """ 
    Args:
        audit_id (Union[Unset, str]):
        txn_id (Union[Unset, str]):
        schema_name (Union[Unset, str]):
        table_name (Union[Unset, str]):
        operation (Union[Unset, str]):
        primary_key_data (Union[Unset, str]):
        row_before (Union[Unset, str]):
        row_after (Union[Unset, str]):
        actor_id (Union[Unset, str]):
        actor_identity (Union[Unset, str]):
        actor_roles (Union[Unset, str]):
        performed_at (Union[Unset, str]):
        prefer (Union[Unset, PatchAuditLogPrefer]):
        body (AuditLog):
        body (AuditLog):
        body (AuditLog):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        body=body,
audit_id=audit_id,
txn_id=txn_id,
schema_name=schema_name,
table_name=table_name,
operation=operation,
primary_key_data=primary_key_data,
row_before=row_before,
row_after=row_after,
actor_id=actor_id,
actor_identity=actor_identity,
actor_roles=actor_roles,
performed_at=performed_at,
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
        AuditLog,
        AuditLog,
        AuditLog,
    ],
    audit_id: Union[Unset, str] = UNSET,
    txn_id: Union[Unset, str] = UNSET,
    schema_name: Union[Unset, str] = UNSET,
    table_name: Union[Unset, str] = UNSET,
    operation: Union[Unset, str] = UNSET,
    primary_key_data: Union[Unset, str] = UNSET,
    row_before: Union[Unset, str] = UNSET,
    row_after: Union[Unset, str] = UNSET,
    actor_id: Union[Unset, str] = UNSET,
    actor_identity: Union[Unset, str] = UNSET,
    actor_roles: Union[Unset, str] = UNSET,
    performed_at: Union[Unset, str] = UNSET,
    prefer: Union[Unset, PatchAuditLogPrefer] = UNSET,

) -> Response[Any]:
    """ 
    Args:
        audit_id (Union[Unset, str]):
        txn_id (Union[Unset, str]):
        schema_name (Union[Unset, str]):
        table_name (Union[Unset, str]):
        operation (Union[Unset, str]):
        primary_key_data (Union[Unset, str]):
        row_before (Union[Unset, str]):
        row_after (Union[Unset, str]):
        actor_id (Union[Unset, str]):
        actor_identity (Union[Unset, str]):
        actor_roles (Union[Unset, str]):
        performed_at (Union[Unset, str]):
        prefer (Union[Unset, PatchAuditLogPrefer]):
        body (AuditLog):
        body (AuditLog):
        body (AuditLog):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        body=body,
audit_id=audit_id,
txn_id=txn_id,
schema_name=schema_name,
table_name=table_name,
operation=operation,
primary_key_data=primary_key_data,
row_before=row_before,
row_after=row_after,
actor_id=actor_id,
actor_identity=actor_identity,
actor_roles=actor_roles,
performed_at=performed_at,
prefer=prefer,

    )

    response = await client.get_async_httpx_client().request(
        **kwargs
    )

    return _build_response(client=client, response=response)

