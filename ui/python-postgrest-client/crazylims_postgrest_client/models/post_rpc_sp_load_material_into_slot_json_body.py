from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from ..types import UNSET, Unset
from typing import Union
from uuid import UUID






T = TypeVar("T", bound="PostRpcSpLoadMaterialIntoSlotJsonBody")



@_attrs_define
class PostRpcSpLoadMaterialIntoSlotJsonBody:
    """ 
        Attributes:
            p_material (Any):
            p_slot_id (UUID):
            p_parent_artefact_id (Union[Unset, UUID]):
            p_relationship_type (Union[Unset, str]):
     """

    p_material: Any
    p_slot_id: UUID
    p_parent_artefact_id: Union[Unset, UUID] = UNSET
    p_relationship_type: Union[Unset, str] = UNSET
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        p_material = self.p_material

        p_slot_id = str(self.p_slot_id)

        p_parent_artefact_id: Union[Unset, str] = UNSET
        if not isinstance(self.p_parent_artefact_id, Unset):
            p_parent_artefact_id = str(self.p_parent_artefact_id)

        p_relationship_type = self.p_relationship_type


        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
            "p_material": p_material,
            "p_slot_id": p_slot_id,
        })
        if p_parent_artefact_id is not UNSET:
            field_dict["p_parent_artefact_id"] = p_parent_artefact_id
        if p_relationship_type is not UNSET:
            field_dict["p_relationship_type"] = p_relationship_type

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        p_material = d.pop("p_material")

        p_slot_id = UUID(d.pop("p_slot_id"))




        _p_parent_artefact_id = d.pop("p_parent_artefact_id", UNSET)
        p_parent_artefact_id: Union[Unset, UUID]
        if isinstance(_p_parent_artefact_id,  Unset):
            p_parent_artefact_id = UNSET
        else:
            p_parent_artefact_id = UUID(_p_parent_artefact_id)




        p_relationship_type = d.pop("p_relationship_type", UNSET)

        post_rpc_sp_load_material_into_slot_json_body = cls(
            p_material=p_material,
            p_slot_id=p_slot_id,
            p_parent_artefact_id=p_parent_artefact_id,
            p_relationship_type=p_relationship_type,
        )


        post_rpc_sp_load_material_into_slot_json_body.additional_properties = d
        return post_rpc_sp_load_material_into_slot_json_body

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
