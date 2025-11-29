from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from typing import cast






T = TypeVar("T", bound="PostRpcProjectHandoverMetadataJsonBody")



@_attrs_define
class PostRpcProjectHandoverMetadataJsonBody:
    """ 
        Attributes:
            p_metadata (Any):
            p_whitelist (list[str]):
     """

    p_metadata: Any
    p_whitelist: list[str]
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        p_metadata = self.p_metadata

        p_whitelist = self.p_whitelist




        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
            "p_metadata": p_metadata,
            "p_whitelist": p_whitelist,
        })

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        p_metadata = d.pop("p_metadata")

        p_whitelist = cast(list[str], d.pop("p_whitelist"))


        post_rpc_project_handover_metadata_json_body = cls(
            p_metadata=p_metadata,
            p_whitelist=p_whitelist,
        )


        post_rpc_project_handover_metadata_json_body.additional_properties = d
        return post_rpc_project_handover_metadata_json_body

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
