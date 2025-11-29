from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from ..types import UNSET, Unset
from typing import Union
from uuid import UUID






T = TypeVar("T", bound="PostRpcFinishTransactionContextJsonBody")



@_attrs_define
class PostRpcFinishTransactionContextJsonBody:
    """ 
        Attributes:
            p_reason (Union[Unset, str]):
            p_status (Union[Unset, str]):
            p_txn_id (Union[Unset, UUID]):
     """

    p_reason: Union[Unset, str] = UNSET
    p_status: Union[Unset, str] = UNSET
    p_txn_id: Union[Unset, UUID] = UNSET
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        p_reason = self.p_reason

        p_status = self.p_status

        p_txn_id: Union[Unset, str] = UNSET
        if not isinstance(self.p_txn_id, Unset):
            p_txn_id = str(self.p_txn_id)


        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
        })
        if p_reason is not UNSET:
            field_dict["p_reason"] = p_reason
        if p_status is not UNSET:
            field_dict["p_status"] = p_status
        if p_txn_id is not UNSET:
            field_dict["p_txn_id"] = p_txn_id

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        p_reason = d.pop("p_reason", UNSET)

        p_status = d.pop("p_status", UNSET)

        _p_txn_id = d.pop("p_txn_id", UNSET)
        p_txn_id: Union[Unset, UUID]
        if isinstance(_p_txn_id,  Unset):
            p_txn_id = UNSET
        else:
            p_txn_id = UUID(_p_txn_id)




        post_rpc_finish_transaction_context_json_body = cls(
            p_reason=p_reason,
            p_status=p_status,
            p_txn_id=p_txn_id,
        )


        post_rpc_finish_transaction_context_json_body.additional_properties = d
        return post_rpc_finish_transaction_context_json_body

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
