from http import HTTPStatus
from typing import Any, Optional, Union, cast

import httpx

from ...client import AuthenticatedClient, Client
from ...types import Response, UNSET
from ... import errors

from ...models.delete_artefacts_prefer import DeleteArtefactsPrefer
from ...types import UNSET, Unset
from typing import Union



def _get_kwargs(
    *,
    artefact_id: Union[Unset, str] = UNSET,
    artefact_type_id: Union[Unset, str] = UNSET,
    name: Union[Unset, str] = UNSET,
    external_identifier: Union[Unset, str] = UNSET,
    description: Union[Unset, str] = UNSET,
    status: Union[Unset, str] = UNSET,
    is_virtual: Union[Unset, str] = UNSET,
    quantity: Union[Unset, str] = UNSET,
    quantity_unit: Union[Unset, str] = UNSET,
    quantity_estimated: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    origin_process_instance_id: Union[Unset, str] = UNSET,
    container_artefact_id: Union[Unset, str] = UNSET,
    container_slot_id: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    updated_at: Union[Unset, str] = UNSET,
    updated_by: Union[Unset, str] = UNSET,
    prefer: Union[Unset, DeleteArtefactsPrefer] = UNSET,

) -> dict[str, Any]:
    headers: dict[str, Any] = {}
    if not isinstance(prefer, Unset):
        headers["Prefer"] = str(prefer)




    

    params: dict[str, Any] = {}

    params["artefact_id"] = artefact_id

    params["artefact_type_id"] = artefact_type_id

    params["name"] = name

    params["external_identifier"] = external_identifier

    params["description"] = description

    params["status"] = status

    params["is_virtual"] = is_virtual

    params["quantity"] = quantity

    params["quantity_unit"] = quantity_unit

    params["quantity_estimated"] = quantity_estimated

    params["metadata"] = metadata

    params["origin_process_instance_id"] = origin_process_instance_id

    params["container_artefact_id"] = container_artefact_id

    params["container_slot_id"] = container_slot_id

    params["created_at"] = created_at

    params["created_by"] = created_by

    params["updated_at"] = updated_at

    params["updated_by"] = updated_by


    params = {k: v for k, v in params.items() if v is not UNSET and v is not None}


    _kwargs: dict[str, Any] = {
        "method": "delete",
        "url": "/artefacts",
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
    artefact_id: Union[Unset, str] = UNSET,
    artefact_type_id: Union[Unset, str] = UNSET,
    name: Union[Unset, str] = UNSET,
    external_identifier: Union[Unset, str] = UNSET,
    description: Union[Unset, str] = UNSET,
    status: Union[Unset, str] = UNSET,
    is_virtual: Union[Unset, str] = UNSET,
    quantity: Union[Unset, str] = UNSET,
    quantity_unit: Union[Unset, str] = UNSET,
    quantity_estimated: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    origin_process_instance_id: Union[Unset, str] = UNSET,
    container_artefact_id: Union[Unset, str] = UNSET,
    container_slot_id: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    updated_at: Union[Unset, str] = UNSET,
    updated_by: Union[Unset, str] = UNSET,
    prefer: Union[Unset, DeleteArtefactsPrefer] = UNSET,

) -> Response[Any]:
    """ 
    Args:
        artefact_id (Union[Unset, str]):
        artefact_type_id (Union[Unset, str]):
        name (Union[Unset, str]):
        external_identifier (Union[Unset, str]):
        description (Union[Unset, str]):
        status (Union[Unset, str]):
        is_virtual (Union[Unset, str]):
        quantity (Union[Unset, str]):
        quantity_unit (Union[Unset, str]):
        quantity_estimated (Union[Unset, str]):
        metadata (Union[Unset, str]):
        origin_process_instance_id (Union[Unset, str]):
        container_artefact_id (Union[Unset, str]):
        container_slot_id (Union[Unset, str]):
        created_at (Union[Unset, str]):
        created_by (Union[Unset, str]):
        updated_at (Union[Unset, str]):
        updated_by (Union[Unset, str]):
        prefer (Union[Unset, DeleteArtefactsPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        artefact_id=artefact_id,
artefact_type_id=artefact_type_id,
name=name,
external_identifier=external_identifier,
description=description,
status=status,
is_virtual=is_virtual,
quantity=quantity,
quantity_unit=quantity_unit,
quantity_estimated=quantity_estimated,
metadata=metadata,
origin_process_instance_id=origin_process_instance_id,
container_artefact_id=container_artefact_id,
container_slot_id=container_slot_id,
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
    artefact_id: Union[Unset, str] = UNSET,
    artefact_type_id: Union[Unset, str] = UNSET,
    name: Union[Unset, str] = UNSET,
    external_identifier: Union[Unset, str] = UNSET,
    description: Union[Unset, str] = UNSET,
    status: Union[Unset, str] = UNSET,
    is_virtual: Union[Unset, str] = UNSET,
    quantity: Union[Unset, str] = UNSET,
    quantity_unit: Union[Unset, str] = UNSET,
    quantity_estimated: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    origin_process_instance_id: Union[Unset, str] = UNSET,
    container_artefact_id: Union[Unset, str] = UNSET,
    container_slot_id: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    updated_at: Union[Unset, str] = UNSET,
    updated_by: Union[Unset, str] = UNSET,
    prefer: Union[Unset, DeleteArtefactsPrefer] = UNSET,

) -> Response[Any]:
    """ 
    Args:
        artefact_id (Union[Unset, str]):
        artefact_type_id (Union[Unset, str]):
        name (Union[Unset, str]):
        external_identifier (Union[Unset, str]):
        description (Union[Unset, str]):
        status (Union[Unset, str]):
        is_virtual (Union[Unset, str]):
        quantity (Union[Unset, str]):
        quantity_unit (Union[Unset, str]):
        quantity_estimated (Union[Unset, str]):
        metadata (Union[Unset, str]):
        origin_process_instance_id (Union[Unset, str]):
        container_artefact_id (Union[Unset, str]):
        container_slot_id (Union[Unset, str]):
        created_at (Union[Unset, str]):
        created_by (Union[Unset, str]):
        updated_at (Union[Unset, str]):
        updated_by (Union[Unset, str]):
        prefer (Union[Unset, DeleteArtefactsPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        artefact_id=artefact_id,
artefact_type_id=artefact_type_id,
name=name,
external_identifier=external_identifier,
description=description,
status=status,
is_virtual=is_virtual,
quantity=quantity,
quantity_unit=quantity_unit,
quantity_estimated=quantity_estimated,
metadata=metadata,
origin_process_instance_id=origin_process_instance_id,
container_artefact_id=container_artefact_id,
container_slot_id=container_slot_id,
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

