from http import HTTPStatus
from typing import Any, Optional, Union, cast

import httpx

from ...client import AuthenticatedClient, Client
from ...types import Response, UNSET
from ... import errors

from ...models.get_v_transaction_context_activity_prefer import GetVTransactionContextActivityPrefer
from ...models.v_transaction_context_activity import VTransactionContextActivity
from ...types import UNSET, Unset
from typing import cast
from typing import Union



def _get_kwargs(
    *,
    started_hour: Union[Unset, str] = UNSET,
    client_app: Union[Unset, str] = UNSET,
    finished_status: Union[Unset, str] = UNSET,
    context_count: Union[Unset, str] = UNSET,
    open_contexts: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVTransactionContextActivityPrefer] = UNSET,

) -> dict[str, Any]:
    headers: dict[str, Any] = {}
    if not isinstance(range_, Unset):
        headers["Range"] = range_

    if not isinstance(range_unit, Unset):
        headers["Range-Unit"] = range_unit

    if not isinstance(prefer, Unset):
        headers["Prefer"] = str(prefer)




    

    params: dict[str, Any] = {}

    params["started_hour"] = started_hour

    params["client_app"] = client_app

    params["finished_status"] = finished_status

    params["context_count"] = context_count

    params["open_contexts"] = open_contexts

    params["select"] = select

    params["order"] = order

    params["offset"] = offset

    params["limit"] = limit


    params = {k: v for k, v in params.items() if v is not UNSET and v is not None}


    _kwargs: dict[str, Any] = {
        "method": "get",
        "url": "/v_transaction_context_activity",
        "params": params,
    }


    _kwargs["headers"] = headers
    return _kwargs



def _parse_response(*, client: Union[AuthenticatedClient, Client], response: httpx.Response) -> Optional[Union[Any, list['VTransactionContextActivity']]]:
    if response.status_code == 200:
        response_200 = []
        _response_200 = response.json()
        for response_200_item_data in (_response_200):
            response_200_item = VTransactionContextActivity.from_dict(response_200_item_data)



            response_200.append(response_200_item)

        return response_200

    if response.status_code == 206:
        response_206 = cast(Any, None)
        return response_206

    if client.raise_on_unexpected_status:
        raise errors.UnexpectedStatus(response.status_code, response.content)
    else:
        return None


def _build_response(*, client: Union[AuthenticatedClient, Client], response: httpx.Response) -> Response[Union[Any, list['VTransactionContextActivity']]]:
    return Response(
        status_code=HTTPStatus(response.status_code),
        content=response.content,
        headers=response.headers,
        parsed=_parse_response(client=client, response=response),
    )


def sync_detailed(
    *,
    client: Union[AuthenticatedClient, Client],
    started_hour: Union[Unset, str] = UNSET,
    client_app: Union[Unset, str] = UNSET,
    finished_status: Union[Unset, str] = UNSET,
    context_count: Union[Unset, str] = UNSET,
    open_contexts: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVTransactionContextActivityPrefer] = UNSET,

) -> Response[Union[Any, list['VTransactionContextActivity']]]:
    """ 
    Args:
        started_hour (Union[Unset, str]):
        client_app (Union[Unset, str]):
        finished_status (Union[Unset, str]):
        context_count (Union[Unset, str]):
        open_contexts (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVTransactionContextActivityPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Union[Any, list['VTransactionContextActivity']]]
     """


    kwargs = _get_kwargs(
        started_hour=started_hour,
client_app=client_app,
finished_status=finished_status,
context_count=context_count,
open_contexts=open_contexts,
select=select,
order=order,
offset=offset,
limit=limit,
range_=range_,
range_unit=range_unit,
prefer=prefer,

    )

    response = client.get_httpx_client().request(
        **kwargs,
    )

    return _build_response(client=client, response=response)

def sync(
    *,
    client: Union[AuthenticatedClient, Client],
    started_hour: Union[Unset, str] = UNSET,
    client_app: Union[Unset, str] = UNSET,
    finished_status: Union[Unset, str] = UNSET,
    context_count: Union[Unset, str] = UNSET,
    open_contexts: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVTransactionContextActivityPrefer] = UNSET,

) -> Optional[Union[Any, list['VTransactionContextActivity']]]:
    """ 
    Args:
        started_hour (Union[Unset, str]):
        client_app (Union[Unset, str]):
        finished_status (Union[Unset, str]):
        context_count (Union[Unset, str]):
        open_contexts (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVTransactionContextActivityPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Union[Any, list['VTransactionContextActivity']]
     """


    return sync_detailed(
        client=client,
started_hour=started_hour,
client_app=client_app,
finished_status=finished_status,
context_count=context_count,
open_contexts=open_contexts,
select=select,
order=order,
offset=offset,
limit=limit,
range_=range_,
range_unit=range_unit,
prefer=prefer,

    ).parsed

async def asyncio_detailed(
    *,
    client: Union[AuthenticatedClient, Client],
    started_hour: Union[Unset, str] = UNSET,
    client_app: Union[Unset, str] = UNSET,
    finished_status: Union[Unset, str] = UNSET,
    context_count: Union[Unset, str] = UNSET,
    open_contexts: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVTransactionContextActivityPrefer] = UNSET,

) -> Response[Union[Any, list['VTransactionContextActivity']]]:
    """ 
    Args:
        started_hour (Union[Unset, str]):
        client_app (Union[Unset, str]):
        finished_status (Union[Unset, str]):
        context_count (Union[Unset, str]):
        open_contexts (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVTransactionContextActivityPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Union[Any, list['VTransactionContextActivity']]]
     """


    kwargs = _get_kwargs(
        started_hour=started_hour,
client_app=client_app,
finished_status=finished_status,
context_count=context_count,
open_contexts=open_contexts,
select=select,
order=order,
offset=offset,
limit=limit,
range_=range_,
range_unit=range_unit,
prefer=prefer,

    )

    response = await client.get_async_httpx_client().request(
        **kwargs
    )

    return _build_response(client=client, response=response)

async def asyncio(
    *,
    client: Union[AuthenticatedClient, Client],
    started_hour: Union[Unset, str] = UNSET,
    client_app: Union[Unset, str] = UNSET,
    finished_status: Union[Unset, str] = UNSET,
    context_count: Union[Unset, str] = UNSET,
    open_contexts: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVTransactionContextActivityPrefer] = UNSET,

) -> Optional[Union[Any, list['VTransactionContextActivity']]]:
    """ 
    Args:
        started_hour (Union[Unset, str]):
        client_app (Union[Unset, str]):
        finished_status (Union[Unset, str]):
        context_count (Union[Unset, str]):
        open_contexts (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVTransactionContextActivityPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Union[Any, list['VTransactionContextActivity']]
     """


    return (await asyncio_detailed(
        client=client,
started_hour=started_hour,
client_app=client_app,
finished_status=finished_status,
context_count=context_count,
open_contexts=open_contexts,
select=select,
order=order,
offset=offset,
limit=limit,
range_=range_,
range_unit=range_unit,
prefer=prefer,

    )).parsed
