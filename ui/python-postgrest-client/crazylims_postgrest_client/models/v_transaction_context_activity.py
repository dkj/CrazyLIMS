from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from ..types import UNSET, Unset
from typing import Union






T = TypeVar("T", bound="VTransactionContextActivity")



@_attrs_define
class VTransactionContextActivity:
    """ 
        Attributes:
            started_hour (Union[Unset, str]):
            client_app (Union[Unset, str]):
            finished_status (Union[Unset, str]):
            context_count (Union[Unset, int]):
            open_contexts (Union[Unset, int]):
     """

    started_hour: Union[Unset, str] = UNSET
    client_app: Union[Unset, str] = UNSET
    finished_status: Union[Unset, str] = UNSET
    context_count: Union[Unset, int] = UNSET
    open_contexts: Union[Unset, int] = UNSET
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        started_hour = self.started_hour

        client_app = self.client_app

        finished_status = self.finished_status

        context_count = self.context_count

        open_contexts = self.open_contexts


        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
        })
        if started_hour is not UNSET:
            field_dict["started_hour"] = started_hour
        if client_app is not UNSET:
            field_dict["client_app"] = client_app
        if finished_status is not UNSET:
            field_dict["finished_status"] = finished_status
        if context_count is not UNSET:
            field_dict["context_count"] = context_count
        if open_contexts is not UNSET:
            field_dict["open_contexts"] = open_contexts

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        started_hour = d.pop("started_hour", UNSET)

        client_app = d.pop("client_app", UNSET)

        finished_status = d.pop("finished_status", UNSET)

        context_count = d.pop("context_count", UNSET)

        open_contexts = d.pop("open_contexts", UNSET)

        v_transaction_context_activity = cls(
            started_hour=started_hour,
            client_app=client_app,
            finished_status=finished_status,
            context_count=context_count,
            open_contexts=open_contexts,
        )


        v_transaction_context_activity.additional_properties = d
        return v_transaction_context_activity

    @property
    def additional_keys(self) -> list[str]:
        return list(self.additional_properties.keys())

    def __getitem__(self, key: str) -> Any:
        return self.additional_properties[key]

    def __setitem__(self, key: str, value: Any) -> None:
        self.additional_properties[key] = value

    def __delitem__(self, key: str) -> None:
        del self.additional_properties[key]

    def __contains__(self, key: str) -> bool:
        return key in self.additional_properties
