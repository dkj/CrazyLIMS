from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from ..types import UNSET, Unset
from typing import cast
from typing import Union
from uuid import UUID






T = TypeVar("T", bound="PostRpcSpHandoverToOpsJsonBody")



@_attrs_define
class PostRpcSpHandoverToOpsJsonBody:
    """ 
        Attributes:
            p_artefact_ids (list[str]):
            p_ops_scope_key (str):
            p_research_scope_id (UUID):
            p_field_whitelist (Union[Unset, list[str]]):
     """

    p_artefact_ids: list[str]
    p_ops_scope_key: str
    p_research_scope_id: UUID
    p_field_whitelist: Union[Unset, list[str]] = UNSET
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        p_artefact_ids = self.p_artefact_ids



        p_ops_scope_key = self.p_ops_scope_key

        p_research_scope_id = str(self.p_research_scope_id)

        p_field_whitelist: Union[Unset, list[str]] = UNSET
        if not isinstance(self.p_field_whitelist, Unset):
            p_field_whitelist = self.p_field_whitelist




        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
            "p_artefact_ids": p_artefact_ids,
            "p_ops_scope_key": p_ops_scope_key,
            "p_research_scope_id": p_research_scope_id,
        })
        if p_field_whitelist is not UNSET:
            field_dict["p_field_whitelist"] = p_field_whitelist

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        p_artefact_ids = cast(list[str], d.pop("p_artefact_ids"))


        p_ops_scope_key = d.pop("p_ops_scope_key")

        p_research_scope_id = UUID(d.pop("p_research_scope_id"))




        p_field_whitelist = cast(list[str], d.pop("p_field_whitelist", UNSET))


        post_rpc_sp_handover_to_ops_json_body = cls(
            p_artefact_ids=p_artefact_ids,
            p_ops_scope_key=p_ops_scope_key,
            p_research_scope_id=p_research_scope_id,
            p_field_whitelist=p_field_whitelist,
        )


        post_rpc_sp_handover_to_ops_json_body.additional_properties = d
        return post_rpc_sp_handover_to_ops_json_body

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
