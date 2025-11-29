from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from ..types import UNSET, Unset
from typing import cast
from typing import Union
from uuid import UUID






T = TypeVar("T", bound="PostRpcSpPoolFixedVolumeJsonBody")



@_attrs_define
class PostRpcSpPoolFixedVolumeJsonBody:
    """ 
        Attributes:
            p_destination_slot_id (UUID):
            p_input_slots (list[str]):
            p_volume_ul (float):
            p_metadata (Union[Unset, Any]):
     """

    p_destination_slot_id: UUID
    p_input_slots: list[str]
    p_volume_ul: float
    p_metadata: Union[Unset, Any] = UNSET
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        p_destination_slot_id = str(self.p_destination_slot_id)

        p_input_slots = self.p_input_slots



        p_volume_ul = self.p_volume_ul

        p_metadata = self.p_metadata


        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
            "p_destination_slot_id": p_destination_slot_id,
            "p_input_slots": p_input_slots,
            "p_volume_ul": p_volume_ul,
        })
        if p_metadata is not UNSET:
            field_dict["p_metadata"] = p_metadata

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        p_destination_slot_id = UUID(d.pop("p_destination_slot_id"))




        p_input_slots = cast(list[str], d.pop("p_input_slots"))


        p_volume_ul = d.pop("p_volume_ul")

        p_metadata = d.pop("p_metadata", UNSET)

        post_rpc_sp_pool_fixed_volume_json_body = cls(
            p_destination_slot_id=p_destination_slot_id,
            p_input_slots=p_input_slots,
            p_volume_ul=p_volume_ul,
            p_metadata=p_metadata,
        )


        post_rpc_sp_pool_fixed_volume_json_body.additional_properties = d
        return post_rpc_sp_pool_fixed_volume_json_body

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
