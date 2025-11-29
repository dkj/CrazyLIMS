from http import HTTPStatus
from typing import Any, Optional, Union, cast

import httpx

from ...client import AuthenticatedClient, Client
from ...types import Response, UNSET
from ... import errors

from ...models.delete_artefact_trait_values_prefer import DeleteArtefactTraitValuesPrefer
from ...types import UNSET, Unset
from typing import Union



def _get_kwargs(
    *,
    artefact_trait_value_id: Union[Unset, str] = UNSET,
    artefact_id: Union[Unset, str] = UNSET,
    trait_id: Union[Unset, str] = UNSET,
    value: Union[Unset, str] = UNSET,
    effective_at: Union[Unset, str] = UNSET,
    recorded_by: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    prefer: Union[Unset, DeleteArtefactTraitValuesPrefer] = UNSET,

) -> dict[str, Any]:
    headers: dict[str, Any] = {}
    if not isinstance(prefer, Unset):
        headers["Prefer"] = str(prefer)




    

    params: dict[str, Any] = {}

    params["artefact_trait_value_id"] = artefact_trait_value_id

    params["artefact_id"] = artefact_id

    params["trait_id"] = trait_id

    params["value"] = value

    params["effective_at"] = effective_at

    params["recorded_by"] = recorded_by

    params["metadata"] = metadata


    params = {k: v for k, v in params.items() if v is not UNSET and v is not None}


    _kwargs: dict[str, Any] = {
        "method": "delete",
        "url": "/artefact_trait_values",
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
    artefact_trait_value_id: Union[Unset, str] = UNSET,
    artefact_id: Union[Unset, str] = UNSET,
    trait_id: Union[Unset, str] = UNSET,
    value: Union[Unset, str] = UNSET,
    effective_at: Union[Unset, str] = UNSET,
    recorded_by: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    prefer: Union[Unset, DeleteArtefactTraitValuesPrefer] = UNSET,

) -> Response[Any]:
    """ 
    Args:
        artefact_trait_value_id (Union[Unset, str]):
        artefact_id (Union[Unset, str]):
        trait_id (Union[Unset, str]):
        value (Union[Unset, str]):
        effective_at (Union[Unset, str]):
        recorded_by (Union[Unset, str]):
        metadata (Union[Unset, str]):
        prefer (Union[Unset, DeleteArtefactTraitValuesPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        artefact_trait_value_id=artefact_trait_value_id,
artefact_id=artefact_id,
trait_id=trait_id,
value=value,
effective_at=effective_at,
recorded_by=recorded_by,
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
    artefact_trait_value_id: Union[Unset, str] = UNSET,
    artefact_id: Union[Unset, str] = UNSET,
    trait_id: Union[Unset, str] = UNSET,
    value: Union[Unset, str] = UNSET,
    effective_at: Union[Unset, str] = UNSET,
    recorded_by: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    prefer: Union[Unset, DeleteArtefactTraitValuesPrefer] = UNSET,

) -> Response[Any]:
    """ 
    Args:
        artefact_trait_value_id (Union[Unset, str]):
        artefact_id (Union[Unset, str]):
        trait_id (Union[Unset, str]):
        value (Union[Unset, str]):
        effective_at (Union[Unset, str]):
        recorded_by (Union[Unset, str]):
        metadata (Union[Unset, str]):
        prefer (Union[Unset, DeleteArtefactTraitValuesPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Any]
     """


    kwargs = _get_kwargs(
        artefact_trait_value_id=artefact_trait_value_id,
artefact_id=artefact_id,
trait_id=trait_id,
value=value,
effective_at=effective_at,
recorded_by=recorded_by,
metadata=metadata,
prefer=prefer,

    )

    response = await client.get_async_httpx_client().request(
        **kwargs
    )

    return _build_response(client=client, response=response)

