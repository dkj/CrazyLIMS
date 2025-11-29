from http import HTTPStatus
from typing import Any, Optional, Union, cast

import httpx

from ...client import AuthenticatedClient, Client
from ...types import Response, UNSET
from ... import errors

from ...models.delete_process_instances_prefer import DeleteProcessInstancesPrefer
from ...types import UNSET, Unset
from typing import Union



def _get_kwargs(
    *,
    process_instance_id: Union[Unset, str] = UNSET,
    process_type_id: Union[Unset, str] = UNSET,
    process_identifier: Union[Unset, str] = UNSET,
    name: Union[Unset, str] = UNSET,
    description: Union[Unset, str] = UNSET,
    status: Union[Unset, str] = UNSET,
    started_at: Union[Unset, str] = UNSET,
    completed_at: Union[Unset, str] = UNSET,
    executed_by: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    updated_at: Union[Unset, str] = UNSET,
    updated_by: Union[Unset, str] = UNSET,
    prefer: Union[Unset, DeleteProcessInstancesPrefer] = UNSET,

) -> dict[str, Any]:
    headers: dict[str, Any] = {}
    if not isinstance(prefer, Unset):
        headers["Prefer"] = str(prefer)




    

    params: dict[str, Any] = {}

    params["process_instance_id"] = process_instance_id

    params["process_type_id"] = process_type_id

    params["process_identifier"] = process_identifier

    params["name"] = name

    params["description"] = description

    params["status"] = status

    params["started_at"] = started_at

    params["completed_at"] = completed_at

    params["executed_by"] = executed_by

    params["metadata"] = metadata

    params["created_at"] = created_at

    params["created_by"] = created_by

    params["updated_at"] = updated_at

    params["updated_by"] = updated_by


    params = {k: v for k, v in params.items() if v is not UNSET and v is not None}


    _kwargs: dict[str, Any] = {
        "method": "delete",
        "url": "/process_instances",
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
    process_instance_id: Union[Unset, str] = UNSET,
    process_type_id: Union[Unset, str] = UNSET,
    process_identifier: Union[Unset, str] = UNSET,
    name: Union[Unset, str] = UNSET,
    description: Union[Unset, str] = UNSET,
    status: Union[Unset, str] = UNSET,
    started_at: Union[Unset, str] = UNSET,
    completed_at: Union[Unset, str] = UNSET,
    executed_by: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    updated_at: Union[Unset, str] = UNSET,
    updated_by: Union[Unset, str] = UNSET,
    prefer: Union[Unset, DeleteProcessInstancesPrefer] = UNSET,

) -> Response[Any]:
    """ 
    Args:
        process_instance_id (Union[Unset, str]):
        process_type_id (Union[Unset, str]):
        process_identifier (Union[Unset, str]):
        name (Union[Unset, str]):
        description (Union[Unset, str]):
        status (Union[Unset, str]):
        started_at (Union[Unset, str]):
        completed_at (Union[Unset, str]):
        executed_by (Union[Unset, str]):
        metadata (Union[Unset, str]):
        created_at (Union[Unset, str]):
        created_by (Union[Unset, str]):
        updated_at (Union[Unset, str]):
        updated_by (Union[Unset, str]):
        prefer (Union[Unset, DeleteProcessInstancesPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        process_instance_id=process_instance_id,
process_type_id=process_type_id,
process_identifier=process_identifier,
name=name,
description=description,
status=status,
started_at=started_at,
completed_at=completed_at,
executed_by=executed_by,
metadata=metadata,
created_at=created_at,
created_by=created_by,
updated_at=updated_at,
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
    process_instance_id: Union[Unset, str] = UNSET,
    process_type_id: Union[Unset, str] = UNSET,
    process_identifier: Union[Unset, str] = UNSET,
    name: Union[Unset, str] = UNSET,
    description: Union[Unset, str] = UNSET,
    status: Union[Unset, str] = UNSET,
    started_at: Union[Unset, str] = UNSET,
    completed_at: Union[Unset, str] = UNSET,
    executed_by: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    updated_at: Union[Unset, str] = UNSET,
    updated_by: Union[Unset, str] = UNSET,
    prefer: Union[Unset, DeleteProcessInstancesPrefer] = UNSET,

) -> Response[Any]:
    """ 
    Args:
        process_instance_id (Union[Unset, str]):
        process_type_id (Union[Unset, str]):
        process_identifier (Union[Unset, str]):
        name (Union[Unset, str]):
        description (Union[Unset, str]):
        status (Union[Unset, str]):
        started_at (Union[Unset, str]):
        completed_at (Union[Unset, str]):
        executed_by (Union[Unset, str]):
        metadata (Union[Unset, str]):
        created_at (Union[Unset, str]):
        created_by (Union[Unset, str]):
        updated_at (Union[Unset, str]):
        updated_by (Union[Unset, str]):
        prefer (Union[Unset, DeleteProcessInstancesPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        process_instance_id=process_instance_id,
process_type_id=process_type_id,
process_identifier=process_identifier,
name=name,
description=description,
status=status,
started_at=started_at,
completed_at=completed_at,
executed_by=executed_by,
metadata=metadata,
created_at=created_at,
created_by=created_by,
updated_at=updated_at,
updated_by=updated_by,
prefer=prefer,

    )

    response = await client.get_async_httpx_client().request(
        **kwargs
    )

    return _build_response(client=client, response=response)

