from http import HTTPStatus
from typing import Any, Optional, Union, cast

import httpx

from ...client import AuthenticatedClient, Client
from ...types import Response, UNSET
from ... import errors

from ...models.delete_process_io_prefer import DeleteProcessIoPrefer
from ...types import UNSET, Unset
from typing import Union



def _get_kwargs(
    *,
    process_io_id: Union[Unset, str] = UNSET,
    process_instance_id: Union[Unset, str] = UNSET,
    artefact_id: Union[Unset, str] = UNSET,
    direction: Union[Unset, str] = UNSET,
    io_role: Union[Unset, str] = UNSET,
    quantity: Union[Unset, str] = UNSET,
    quantity_unit: Union[Unset, str] = UNSET,
    is_primary: Union[Unset, str] = UNSET,
    multiplex_group: Union[Unset, str] = UNSET,
    evidence: Union[Unset, str] = UNSET,
    confidence: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    prefer: Union[Unset, DeleteProcessIoPrefer] = UNSET,

) -> dict[str, Any]:
    headers: dict[str, Any] = {}
    if not isinstance(prefer, Unset):
        headers["Prefer"] = str(prefer)




    

    params: dict[str, Any] = {}

    params["process_io_id"] = process_io_id

    params["process_instance_id"] = process_instance_id

    params["artefact_id"] = artefact_id

    params["direction"] = direction

    params["io_role"] = io_role

    params["quantity"] = quantity

    params["quantity_unit"] = quantity_unit

    params["is_primary"] = is_primary

    params["multiplex_group"] = multiplex_group

    params["evidence"] = evidence

    params["confidence"] = confidence

    params["metadata"] = metadata


    params = {k: v for k, v in params.items() if v is not UNSET and v is not None}


    _kwargs: dict[str, Any] = {
        "method": "delete",
        "url": "/process_io",
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
    process_io_id: Union[Unset, str] = UNSET,
    process_instance_id: Union[Unset, str] = UNSET,
    artefact_id: Union[Unset, str] = UNSET,
    direction: Union[Unset, str] = UNSET,
    io_role: Union[Unset, str] = UNSET,
    quantity: Union[Unset, str] = UNSET,
    quantity_unit: Union[Unset, str] = UNSET,
    is_primary: Union[Unset, str] = UNSET,
    multiplex_group: Union[Unset, str] = UNSET,
    evidence: Union[Unset, str] = UNSET,
    confidence: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    prefer: Union[Unset, DeleteProcessIoPrefer] = UNSET,

) -> Response[Any]:
    """ 
    Args:
        process_io_id (Union[Unset, str]):
        process_instance_id (Union[Unset, str]):
        artefact_id (Union[Unset, str]):
        direction (Union[Unset, str]):
        io_role (Union[Unset, str]):
        quantity (Union[Unset, str]):
        quantity_unit (Union[Unset, str]):
        is_primary (Union[Unset, str]):
        multiplex_group (Union[Unset, str]):
        evidence (Union[Unset, str]):
        confidence (Union[Unset, str]):
        metadata (Union[Unset, str]):
        prefer (Union[Unset, DeleteProcessIoPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        process_io_id=process_io_id,
process_instance_id=process_instance_id,
artefact_id=artefact_id,
direction=direction,
io_role=io_role,
quantity=quantity,
quantity_unit=quantity_unit,
is_primary=is_primary,
multiplex_group=multiplex_group,
evidence=evidence,
confidence=confidence,
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
    process_io_id: Union[Unset, str] = UNSET,
    process_instance_id: Union[Unset, str] = UNSET,
    artefact_id: Union[Unset, str] = UNSET,
    direction: Union[Unset, str] = UNSET,
    io_role: Union[Unset, str] = UNSET,
    quantity: Union[Unset, str] = UNSET,
    quantity_unit: Union[Unset, str] = UNSET,
    is_primary: Union[Unset, str] = UNSET,
    multiplex_group: Union[Unset, str] = UNSET,
    evidence: Union[Unset, str] = UNSET,
    confidence: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    prefer: Union[Unset, DeleteProcessIoPrefer] = UNSET,

) -> Response[Any]:
    """ 
    Args:
        process_io_id (Union[Unset, str]):
        process_instance_id (Union[Unset, str]):
        artefact_id (Union[Unset, str]):
        direction (Union[Unset, str]):
        io_role (Union[Unset, str]):
        quantity (Union[Unset, str]):
        quantity_unit (Union[Unset, str]):
        is_primary (Union[Unset, str]):
        multiplex_group (Union[Unset, str]):
        evidence (Union[Unset, str]):
        confidence (Union[Unset, str]):
        metadata (Union[Unset, str]):
        prefer (Union[Unset, DeleteProcessIoPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        process_io_id=process_io_id,
process_instance_id=process_instance_id,
artefact_id=artefact_id,
direction=direction,
io_role=io_role,
quantity=quantity,
quantity_unit=quantity_unit,
is_primary=is_primary,
multiplex_group=multiplex_group,
evidence=evidence,
confidence=confidence,
metadata=metadata,
prefer=prefer,

    )

    response = await client.get_async_httpx_client().request(
        **kwargs
    )

    return _build_response(client=client, response=response)

