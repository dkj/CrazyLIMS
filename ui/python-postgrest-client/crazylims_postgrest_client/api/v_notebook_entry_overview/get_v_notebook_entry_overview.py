from http import HTTPStatus
from typing import Any, Optional, Union, cast

import httpx

from ...client import AuthenticatedClient, Client
from ...types import Response, UNSET
from ... import errors

from ...models.get_v_notebook_entry_overview_prefer import GetVNotebookEntryOverviewPrefer
from ...models.v_notebook_entry_overview import VNotebookEntryOverview
from ...types import UNSET, Unset
from typing import cast
from typing import Union



def _get_kwargs(
    *,
    entry_id: Union[Unset, str] = UNSET,
    entry_key: Union[Unset, str] = UNSET,
    title: Union[Unset, str] = UNSET,
    description: Union[Unset, str] = UNSET,
    status: Union[Unset, str] = UNSET,
    primary_scope_id: Union[Unset, str] = UNSET,
    primary_scope_key: Union[Unset, str] = UNSET,
    primary_scope_name: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    submitted_at: Union[Unset, str] = UNSET,
    submitted_by: Union[Unset, str] = UNSET,
    locked_at: Union[Unset, str] = UNSET,
    locked_by: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    updated_at: Union[Unset, str] = UNSET,
    updated_by: Union[Unset, str] = UNSET,
    latest_version: Union[Unset, str] = UNSET,
    latest_version_created_at: Union[Unset, str] = UNSET,
    latest_version_created_by: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVNotebookEntryOverviewPrefer] = UNSET,

) -> dict[str, Any]:
    headers: dict[str, Any] = {}
    if not isinstance(range_, Unset):
        headers["Range"] = range_

    if not isinstance(range_unit, Unset):
        headers["Range-Unit"] = range_unit

    if not isinstance(prefer, Unset):
        headers["Prefer"] = str(prefer)




    

    params: dict[str, Any] = {}

    params["entry_id"] = entry_id

    params["entry_key"] = entry_key

    params["title"] = title

    params["description"] = description

    params["status"] = status

    params["primary_scope_id"] = primary_scope_id

    params["primary_scope_key"] = primary_scope_key

    params["primary_scope_name"] = primary_scope_name

    params["metadata"] = metadata

    params["submitted_at"] = submitted_at

    params["submitted_by"] = submitted_by

    params["locked_at"] = locked_at

    params["locked_by"] = locked_by

    params["created_at"] = created_at

    params["created_by"] = created_by

    params["updated_at"] = updated_at

    params["updated_by"] = updated_by

    params["latest_version"] = latest_version

    params["latest_version_created_at"] = latest_version_created_at

    params["latest_version_created_by"] = latest_version_created_by

    params["select"] = select

    params["order"] = order

    params["offset"] = offset

    params["limit"] = limit


    params = {k: v for k, v in params.items() if v is not UNSET and v is not None}


    _kwargs: dict[str, Any] = {
        "method": "get",
        "url": "/v_notebook_entry_overview",
        "params": params,
    }


    _kwargs["headers"] = headers
    return _kwargs



def _parse_response(*, client: Union[AuthenticatedClient, Client], response: httpx.Response) -> Optional[Union[Any, list['VNotebookEntryOverview']]]:
    if response.status_code == 200:
        response_200 = []
        _response_200 = response.json()
        for response_200_item_data in (_response_200):
            response_200_item = VNotebookEntryOverview.from_dict(response_200_item_data)



            response_200.append(response_200_item)

        return response_200

    if response.status_code == 206:
        response_206 = cast(Any, None)
        return response_206

    if client.raise_on_unexpected_status:
        raise errors.UnexpectedStatus(response.status_code, response.content)
    else:
        return None


def _build_response(*, client: Union[AuthenticatedClient, Client], response: httpx.Response) -> Response[Union[Any, list['VNotebookEntryOverview']]]:
    return Response(
        status_code=HTTPStatus(response.status_code),
        content=response.content,
        headers=response.headers,
        parsed=_parse_response(client=client, response=response),
    )


def sync_detailed(
    *,
    client: Union[AuthenticatedClient, Client],
    entry_id: Union[Unset, str] = UNSET,
    entry_key: Union[Unset, str] = UNSET,
    title: Union[Unset, str] = UNSET,
    description: Union[Unset, str] = UNSET,
    status: Union[Unset, str] = UNSET,
    primary_scope_id: Union[Unset, str] = UNSET,
    primary_scope_key: Union[Unset, str] = UNSET,
    primary_scope_name: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    submitted_at: Union[Unset, str] = UNSET,
    submitted_by: Union[Unset, str] = UNSET,
    locked_at: Union[Unset, str] = UNSET,
    locked_by: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    updated_at: Union[Unset, str] = UNSET,
    updated_by: Union[Unset, str] = UNSET,
    latest_version: Union[Unset, str] = UNSET,
    latest_version_created_at: Union[Unset, str] = UNSET,
    latest_version_created_by: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVNotebookEntryOverviewPrefer] = UNSET,

) -> Response[Union[Any, list['VNotebookEntryOverview']]]:
    """ @omit

    Args:
        entry_id (Union[Unset, str]):
        entry_key (Union[Unset, str]):
        title (Union[Unset, str]):
        description (Union[Unset, str]):
        status (Union[Unset, str]):
        primary_scope_id (Union[Unset, str]):
        primary_scope_key (Union[Unset, str]):
        primary_scope_name (Union[Unset, str]):
        metadata (Union[Unset, str]):
        submitted_at (Union[Unset, str]):
        submitted_by (Union[Unset, str]):
        locked_at (Union[Unset, str]):
        locked_by (Union[Unset, str]):
        created_at (Union[Unset, str]):
        created_by (Union[Unset, str]):
        updated_at (Union[Unset, str]):
        updated_by (Union[Unset, str]):
        latest_version (Union[Unset, str]):
        latest_version_created_at (Union[Unset, str]):
        latest_version_created_by (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVNotebookEntryOverviewPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Union[Any, list['VNotebookEntryOverview']]]
     """


    kwargs = _get_kwargs(
        entry_id=entry_id,
entry_key=entry_key,
title=title,
description=description,
status=status,
primary_scope_id=primary_scope_id,
primary_scope_key=primary_scope_key,
primary_scope_name=primary_scope_name,
metadata=metadata,
submitted_at=submitted_at,
submitted_by=submitted_by,
locked_at=locked_at,
locked_by=locked_by,
created_at=created_at,
created_by=created_by,
updated_at=updated_at,
updated_by=updated_by,
latest_version=latest_version,
latest_version_created_at=latest_version_created_at,
latest_version_created_by=latest_version_created_by,
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
    entry_id: Union[Unset, str] = UNSET,
    entry_key: Union[Unset, str] = UNSET,
    title: Union[Unset, str] = UNSET,
    description: Union[Unset, str] = UNSET,
    status: Union[Unset, str] = UNSET,
    primary_scope_id: Union[Unset, str] = UNSET,
    primary_scope_key: Union[Unset, str] = UNSET,
    primary_scope_name: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    submitted_at: Union[Unset, str] = UNSET,
    submitted_by: Union[Unset, str] = UNSET,
    locked_at: Union[Unset, str] = UNSET,
    locked_by: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    updated_at: Union[Unset, str] = UNSET,
    updated_by: Union[Unset, str] = UNSET,
    latest_version: Union[Unset, str] = UNSET,
    latest_version_created_at: Union[Unset, str] = UNSET,
    latest_version_created_by: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVNotebookEntryOverviewPrefer] = UNSET,

) -> Optional[Union[Any, list['VNotebookEntryOverview']]]:
    """ @omit

    Args:
        entry_id (Union[Unset, str]):
        entry_key (Union[Unset, str]):
        title (Union[Unset, str]):
        description (Union[Unset, str]):
        status (Union[Unset, str]):
        primary_scope_id (Union[Unset, str]):
        primary_scope_key (Union[Unset, str]):
        primary_scope_name (Union[Unset, str]):
        metadata (Union[Unset, str]):
        submitted_at (Union[Unset, str]):
        submitted_by (Union[Unset, str]):
        locked_at (Union[Unset, str]):
        locked_by (Union[Unset, str]):
        created_at (Union[Unset, str]):
        created_by (Union[Unset, str]):
        updated_at (Union[Unset, str]):
        updated_by (Union[Unset, str]):
        latest_version (Union[Unset, str]):
        latest_version_created_at (Union[Unset, str]):
        latest_version_created_by (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVNotebookEntryOverviewPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Union[Any, list['VNotebookEntryOverview']]
     """


    return sync_detailed(
        client=client,
entry_id=entry_id,
entry_key=entry_key,
title=title,
description=description,
status=status,
primary_scope_id=primary_scope_id,
primary_scope_key=primary_scope_key,
primary_scope_name=primary_scope_name,
metadata=metadata,
submitted_at=submitted_at,
submitted_by=submitted_by,
locked_at=locked_at,
locked_by=locked_by,
created_at=created_at,
created_by=created_by,
updated_at=updated_at,
updated_by=updated_by,
latest_version=latest_version,
latest_version_created_at=latest_version_created_at,
latest_version_created_by=latest_version_created_by,
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
    entry_id: Union[Unset, str] = UNSET,
    entry_key: Union[Unset, str] = UNSET,
    title: Union[Unset, str] = UNSET,
    description: Union[Unset, str] = UNSET,
    status: Union[Unset, str] = UNSET,
    primary_scope_id: Union[Unset, str] = UNSET,
    primary_scope_key: Union[Unset, str] = UNSET,
    primary_scope_name: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    submitted_at: Union[Unset, str] = UNSET,
    submitted_by: Union[Unset, str] = UNSET,
    locked_at: Union[Unset, str] = UNSET,
    locked_by: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    updated_at: Union[Unset, str] = UNSET,
    updated_by: Union[Unset, str] = UNSET,
    latest_version: Union[Unset, str] = UNSET,
    latest_version_created_at: Union[Unset, str] = UNSET,
    latest_version_created_by: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVNotebookEntryOverviewPrefer] = UNSET,

) -> Response[Union[Any, list['VNotebookEntryOverview']]]:
    """ @omit

    Args:
        entry_id (Union[Unset, str]):
        entry_key (Union[Unset, str]):
        title (Union[Unset, str]):
        description (Union[Unset, str]):
        status (Union[Unset, str]):
        primary_scope_id (Union[Unset, str]):
        primary_scope_key (Union[Unset, str]):
        primary_scope_name (Union[Unset, str]):
        metadata (Union[Unset, str]):
        submitted_at (Union[Unset, str]):
        submitted_by (Union[Unset, str]):
        locked_at (Union[Unset, str]):
        locked_by (Union[Unset, str]):
        created_at (Union[Unset, str]):
        created_by (Union[Unset, str]):
        updated_at (Union[Unset, str]):
        updated_by (Union[Unset, str]):
        latest_version (Union[Unset, str]):
        latest_version_created_at (Union[Unset, str]):
        latest_version_created_by (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVNotebookEntryOverviewPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Response[Union[Any, list['VNotebookEntryOverview']]]
     """


    kwargs = _get_kwargs(
        entry_id=entry_id,
entry_key=entry_key,
title=title,
description=description,
status=status,
primary_scope_id=primary_scope_id,
primary_scope_key=primary_scope_key,
primary_scope_name=primary_scope_name,
metadata=metadata,
submitted_at=submitted_at,
submitted_by=submitted_by,
locked_at=locked_at,
locked_by=locked_by,
created_at=created_at,
created_by=created_by,
updated_at=updated_at,
updated_by=updated_by,
latest_version=latest_version,
latest_version_created_at=latest_version_created_at,
latest_version_created_by=latest_version_created_by,
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
    entry_id: Union[Unset, str] = UNSET,
    entry_key: Union[Unset, str] = UNSET,
    title: Union[Unset, str] = UNSET,
    description: Union[Unset, str] = UNSET,
    status: Union[Unset, str] = UNSET,
    primary_scope_id: Union[Unset, str] = UNSET,
    primary_scope_key: Union[Unset, str] = UNSET,
    primary_scope_name: Union[Unset, str] = UNSET,
    metadata: Union[Unset, str] = UNSET,
    submitted_at: Union[Unset, str] = UNSET,
    submitted_by: Union[Unset, str] = UNSET,
    locked_at: Union[Unset, str] = UNSET,
    locked_by: Union[Unset, str] = UNSET,
    created_at: Union[Unset, str] = UNSET,
    created_by: Union[Unset, str] = UNSET,
    updated_at: Union[Unset, str] = UNSET,
    updated_by: Union[Unset, str] = UNSET,
    latest_version: Union[Unset, str] = UNSET,
    latest_version_created_at: Union[Unset, str] = UNSET,
    latest_version_created_by: Union[Unset, str] = UNSET,
    select: Union[Unset, str] = UNSET,
    order: Union[Unset, str] = UNSET,
    offset: Union[Unset, str] = UNSET,
    limit: Union[Unset, str] = UNSET,
    range_: Union[Unset, str] = UNSET,
    range_unit: Union[Unset, str] = 'items',
    prefer: Union[Unset, GetVNotebookEntryOverviewPrefer] = UNSET,

) -> Optional[Union[Any, list['VNotebookEntryOverview']]]:
    """ @omit

    Args:
        entry_id (Union[Unset, str]):
        entry_key (Union[Unset, str]):
        title (Union[Unset, str]):
        description (Union[Unset, str]):
        status (Union[Unset, str]):
        primary_scope_id (Union[Unset, str]):
        primary_scope_key (Union[Unset, str]):
        primary_scope_name (Union[Unset, str]):
        metadata (Union[Unset, str]):
        submitted_at (Union[Unset, str]):
        submitted_by (Union[Unset, str]):
        locked_at (Union[Unset, str]):
        locked_by (Union[Unset, str]):
        created_at (Union[Unset, str]):
        created_by (Union[Unset, str]):
        updated_at (Union[Unset, str]):
        updated_by (Union[Unset, str]):
        latest_version (Union[Unset, str]):
        latest_version_created_at (Union[Unset, str]):
        latest_version_created_by (Union[Unset, str]):
        select (Union[Unset, str]):
        order (Union[Unset, str]):
        offset (Union[Unset, str]):
        limit (Union[Unset, str]):
        range_ (Union[Unset, str]):
        range_unit (Union[Unset, str]):  Default: 'items'.
        prefer (Union[Unset, GetVNotebookEntryOverviewPrefer]):

    Raises:
        errors.UnexpectedStatus: If the server returns an undocumented status code and Client.raise_on_unexpected_status is True.
        httpx.TimeoutException: If the request takes longer than Client.timeout.

    Returns:
        Union[Any, list['VNotebookEntryOverview']]
     """


    return (await asyncio_detailed(
        client=client,
entry_id=entry_id,
entry_key=entry_key,
title=title,
description=description,
status=status,
primary_scope_id=primary_scope_id,
primary_scope_key=primary_scope_key,
primary_scope_name=primary_scope_name,
metadata=metadata,
submitted_at=submitted_at,
submitted_by=submitted_by,
locked_at=locked_at,
locked_by=locked_by,
created_at=created_at,
created_by=created_by,
updated_at=updated_at,
updated_by=updated_by,
latest_version=latest_version,
latest_version_created_at=latest_version_created_at,
latest_version_created_by=latest_version_created_by,
select=select,
order=order,
offset=offset,
limit=limit,
range_=range_,
range_unit=range_unit,
prefer=prefer,

    )).parsed
