from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from ..types import UNSET, Unset
from typing import Union
from uuid import UUID






T = TypeVar("T", bound="PostRpcSpRegisterVirtualManifestJsonBody")



@_attrs_define
class PostRpcSpRegisterVirtualManifestJsonBody:
    """ 
        Attributes:
            p_manifest (Any):
            p_scope_id (UUID):
            p_default_type_key (Union[Unset, str]):
     """

    p_manifest: Any
    p_scope_id: UUID
    p_default_type_key: Union[Unset, str] = UNSET
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        p_manifest = self.p_manifest

        p_scope_id = str(self.p_scope_id)

        p_default_type_key = self.p_default_type_key


        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
            "p_manifest": p_manifest,
            "p_scope_id": p_scope_id,
        })
        if p_default_type_key is not UNSET:
            field_dict["p_default_type_key"] = p_default_type_key

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        p_manifest = d.pop("p_manifest")

        p_scope_id = UUID(d.pop("p_scope_id"))




        p_default_type_key = d.pop("p_default_type_key", UNSET)

        post_rpc_sp_register_virtual_manifest_json_body = cls(
            p_manifest=p_manifest,
            p_scope_id=p_scope_id,
            p_default_type_key=p_default_type_key,
        )


        post_rpc_sp_register_virtual_manifest_json_body.additional_properties = d
        return post_rpc_sp_register_virtual_manifest_json_body

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
