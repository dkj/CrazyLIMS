from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from typing import cast
from uuid import UUID






T = TypeVar("T", bound="PostRpcSpReturnFromOpsJsonBody")



@_attrs_define
class PostRpcSpReturnFromOpsJsonBody:
    """ 
        Attributes:
            p_ops_artefact_id (UUID):
            p_research_scope_ids (list[str]):
     """

    p_ops_artefact_id: UUID
    p_research_scope_ids: list[str]
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        p_ops_artefact_id = str(self.p_ops_artefact_id)

        p_research_scope_ids = self.p_research_scope_ids




        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
            "p_ops_artefact_id": p_ops_artefact_id,
            "p_research_scope_ids": p_research_scope_ids,
        })

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        p_ops_artefact_id = UUID(d.pop("p_ops_artefact_id"))




        p_research_scope_ids = cast(list[str], d.pop("p_research_scope_ids"))


        post_rpc_sp_return_from_ops_json_body = cls(
            p_ops_artefact_id=p_ops_artefact_id,
            p_research_scope_ids=p_research_scope_ids,
        )


        post_rpc_sp_return_from_ops_json_body.additional_properties = d
        return post_rpc_sp_return_from_ops_json_body

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
