from http import HTTPStatus
from typing import Any, Optional, Union, cast

import httpx

from ...client import AuthenticatedClient, Client
from ...types import Response, UNSET
from ... import errors

from ...models.delete_container_slot_definitions_prefer import DeleteContainerSlotDefinitionsPrefer
from ...types import UNSET, Unset
from typing import Union



def _get_kwargs(
    *,
    slot_definition_id: Union[Unset, str] = UNSET,
    artefact_type_id: Union[Unset, str] = UNSET,
    slot_name: Union[Unset, str] = UNSET,
    display_name: Union[Unset, str] = UNSET,
    position: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    prefer: Union[Unset, DeleteContainerSlotDefinitionsPrefer] = UNSET,

) -> dict[str, Any]:
    headers: dict[str, Any] = {}
    if not isinstance(prefer, Unset):
        headers["Prefer"] = str(prefer)




    

    params: dict[str, Any] = {}

    params["slot_definition_id"] = slot_definition_id

    params["artefact_type_id"] = artefact_type_id

    params["slot_name"] = slot_name

    params["display_name"] = display_name

    params["position"] = position

    params["metadata"] = metadata


    params = {k: v for k, v in params.items() if v is not UNSET and v is not None}


    _kwargs: dict[str, Any] = {
        "method": "delete",
        "url": "/container_slot_definitions",
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
    slot_definition_id: Union[Unset, str] = UNSET,
    artefact_type_id: Union[Unset, str] = UNSET,
    slot_name: Union[Unset, str] = UNSET,
    display_name: Union[Unset, str] = UNSET,
    position: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    prefer: Union[Unset, DeleteContainerSlotDefinitionsPrefer] = UNSET,

) -> Response[Any]:
    """ 
    Args:
        slot_definition_id (Union[Unset, str]):
        artefact_type_id (Union[Unset, str]):
        slot_name (Union[Unset, str]):
        display_name (Union[Unset, str]):
        position (Union[Unset, str]):
        metadata (Union[Unset, str]):
        prefer (Union[Unset, DeleteContainerSlotDefinitionsPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        slot_definition_id=slot_definition_id,
artefact_type_id=artefact_type_id,
slot_name=slot_name,
display_name=display_name,
position=position,
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
    slot_definition_id: Union[Unset, str] = UNSET,
    artefact_type_id: Union[Unset, str] = UNSET,
    slot_name: Union[Unset, str] = UNSET,
    display_name: Union[Unset, str] = UNSET,
    position: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    prefer: Union[Unset, DeleteContainerSlotDefinitionsPrefer] = UNSET,

) -> Response[Any]:
    """ 
    Args:
        slot_definition_id (Union[Unset, str]):
        artefact_type_id (Union[Unset, str]):
        slot_name (Union[Unset, str]):
        display_name (Union[Unset, str]):
        position (Union[Unset, str]):
        metadata (Union[Unset, str]):
        prefer (Union[Unset, DeleteContainerSlotDefinitionsPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        slot_definition_id=slot_definition_id,
artefact_type_id=artefact_type_id,
slot_name=slot_name,
display_name=display_name,
position=position,
metadata=metadata,
prefer=prefer,

    )

    response = await client.get_async_httpx_client().request(
        **kwargs
    )

    return _build_response(client=client, response=response)

