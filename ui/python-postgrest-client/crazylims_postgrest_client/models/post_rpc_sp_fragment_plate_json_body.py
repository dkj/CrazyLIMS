from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from uuid import UUID






T = TypeVar("T", bound="PostRpcSpFragmentPlateJsonBody")



@_attrs_define
class PostRpcSpFragmentPlateJsonBody:
    """ 
        Attributes:
            p_destination_plate_id (UUID):
            p_mapping (Any):
            p_reagent_artefact_id (UUID):
            p_source_plate_id (UUID):
     """

    p_destination_plate_id: UUID
    p_mapping: Any
    p_reagent_artefact_id: UUID
    p_source_plate_id: UUID
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        p_destination_plate_id = str(self.p_destination_plate_id)

        p_mapping = self.p_mapping

        p_reagent_artefact_id = str(self.p_reagent_artefact_id)

        p_source_plate_id = str(self.p_source_plate_id)


        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
            "p_destination_plate_id": p_destination_plate_id,
            "p_mapping": p_mapping,
            "p_reagent_artefact_id": p_reagent_artefact_id,
            "p_source_plate_id": p_source_plate_id,
        })

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        p_destination_plate_id = UUID(d.pop("p_destination_plate_id"))




        p_mapping = d.pop("p_mapping")

        p_reagent_artefact_id = UUID(d.pop("p_reagent_artefact_id"))




        p_source_plate_id = UUID(d.pop("p_source_plate_id"))




        post_rpc_sp_fragment_plate_json_body = cls(
            p_destination_plate_id=p_destination_plate_id,
            p_mapping=p_mapping,
            p_reagent_artefact_id=p_reagent_artefact_id,
            p_source_plate_id=p_source_plate_id,
        )


        post_rpc_sp_fragment_plate_json_body.additional_properties = d
        return post_rpc_sp_fragment_plate_json_body

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
