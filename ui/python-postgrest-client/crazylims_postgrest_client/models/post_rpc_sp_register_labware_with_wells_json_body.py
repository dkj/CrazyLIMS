from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from ..types import UNSET, Unset
from typing import Union
from uuid import UUID






T = TypeVar("T", bound="PostRpcSpRegisterLabwareWithWellsJsonBody")



@_attrs_define
class PostRpcSpRegisterLabwareWithWellsJsonBody:
    """ 
        Attributes:
            p_container (Any):
            p_container_type_key (str):
            p_scope_id (Union[Unset, UUID]):
            p_wells (Union[Unset, Any]):
     """

    p_container: Any
    p_container_type_key: str
    p_scope_id: Union[Unset, UUID] = UNSET
    p_wells: Union[Unset, Any] = UNSET
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        p_container = self.p_container

        p_container_type_key = self.p_container_type_key

        p_scope_id: Union[Unset, str] = UNSET
        if not isinstance(self.p_scope_id, Unset):
            p_scope_id = str(self.p_scope_id)

        p_wells = self.p_wells


        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
            "p_container": p_container,
            "p_container_type_key": p_container_type_key,
        })
        if p_scope_id is not UNSET:
            field_dict["p_scope_id"] = p_scope_id
        if p_wells is not UNSET:
            field_dict["p_wells"] = p_wells

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        p_container = d.pop("p_container")

        p_container_type_key = d.pop("p_container_type_key")

        _p_scope_id = d.pop("p_scope_id", UNSET)
        p_scope_id: Union[Unset, UUID]
        if isinstance(_p_scope_id,  Unset):
            p_scope_id = UNSET
        else:
            p_scope_id = UUID(_p_scope_id)




        p_wells = d.pop("p_wells", UNSET)

        post_rpc_sp_register_labware_with_wells_json_body = cls(
            p_container=p_container,
            p_container_type_key=p_container_type_key,
            p_scope_id=p_scope_id,
            p_wells=p_wells,
        )


        post_rpc_sp_register_labware_with_wells_json_body.additional_properties = d
        return post_rpc_sp_register_labware_with_wells_json_body

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
