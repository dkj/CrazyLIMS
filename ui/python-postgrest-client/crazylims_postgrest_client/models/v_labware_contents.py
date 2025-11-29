from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from ..types import UNSET, Unset
from typing import Union
from uuid import UUID






T = TypeVar("T", bound="VLabwareContents")



@_attrs_define
class VLabwareContents:
    """ 
        Attributes:
            labware_id (Union[Unset, UUID]): Note:
                This is a Primary Key.<pk/>
            barcode (Union[Unset, str]):
            display_name (Union[Unset, str]):
            status (Union[Unset, str]):
            position_label (Union[Unset, str]):
            sample_id (Union[Unset, UUID]):
            sample_name (Union[Unset, str]):
            sample_status (Union[Unset, str]):
            volume (Union[Unset, float]):
            volume_unit (Union[Unset, str]):
            current_storage_sublocation_id (Union[Unset, UUID]): Note:
                This is a Foreign Key to `v_inventory_status.id`.<fk table='v_inventory_status' column='id'/>
            storage_path (Union[Unset, str]):
     """

    labware_id: Union[Unset, UUID] = UNSET
    barcode: Union[Unset, str] = UNSET
    display_name: Union[Unset, str] = UNSET
    status: Union[Unset, str] = UNSET
    position_label: Union[Unset, str] = UNSET
    sample_id: Union[Unset, UUID] = UNSET
    sample_name: Union[Unset, str] = UNSET
    sample_status: Union[Unset, str] = UNSET
    volume: Union[Unset, float] = UNSET
    volume_unit: Union[Unset, str] = UNSET
    current_storage_sublocation_id: Union[Unset, UUID] = UNSET
    storage_path: Union[Unset, str] = UNSET
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        labware_id: Union[Unset, str] = UNSET
        if not isinstance(self.labware_id, Unset):
            labware_id = str(self.labware_id)

        barcode = self.barcode

        display_name = self.display_name

        status = self.status

        position_label = self.position_label

        sample_id: Union[Unset, str] = UNSET
        if not isinstance(self.sample_id, Unset):
            sample_id = str(self.sample_id)

        sample_name = self.sample_name

        sample_status = self.sample_status

        volume = self.volume

        volume_unit = self.volume_unit

        current_storage_sublocation_id: Union[Unset, str] = UNSET
        if not isinstance(self.current_storage_sublocation_id, Unset):
            current_storage_sublocation_id = str(self.current_storage_sublocation_id)

        storage_path = self.storage_path


        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
        })
        if labware_id is not UNSET:
            field_dict["labware_id"] = labware_id
        if barcode is not UNSET:
            field_dict["barcode"] = barcode
        if display_name is not UNSET:
            field_dict["display_name"] = display_name
        if status is not UNSET:
            field_dict["status"] = status
        if position_label is not UNSET:
            field_dict["position_label"] = position_label
        if sample_id is not UNSET:
            field_dict["sample_id"] = sample_id
        if sample_name is not UNSET:
            field_dict["sample_name"] = sample_name
        if sample_status is not UNSET:
            field_dict["sample_status"] = sample_status
        if volume is not UNSET:
            field_dict["volume"] = volume
        if volume_unit is not UNSET:
            field_dict["volume_unit"] = volume_unit
        if current_storage_sublocation_id is not UNSET:
            field_dict["current_storage_sublocation_id"] = current_storage_sublocation_id
        if storage_path is not UNSET:
            field_dict["storage_path"] = storage_path

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        _labware_id = d.pop("labware_id", UNSET)
        labware_id: Union[Unset, UUID]
        if isinstance(_labware_id,  Unset):
            labware_id = UNSET
        else:
            labware_id = UUID(_labware_id)




        barcode = d.pop("barcode", UNSET)

        display_name = d.pop("display_name", UNSET)

        status = d.pop("status", UNSET)

        position_label = d.pop("position_label", UNSET)

        _sample_id = d.pop("sample_id", UNSET)
        sample_id: Union[Unset, UUID]
        if isinstance(_sample_id,  Unset):
            sample_id = UNSET
        else:
            sample_id = UUID(_sample_id)




        sample_name = d.pop("sample_name", UNSET)

        sample_status = d.pop("sample_status", UNSET)

        volume = d.pop("volume", UNSET)

        volume_unit = d.pop("volume_unit", UNSET)

        _current_storage_sublocation_id = d.pop("current_storage_sublocation_id", UNSET)
        current_storage_sublocation_id: Union[Unset, UUID]
        if isinstance(_current_storage_sublocation_id,  Unset):
            current_storage_sublocation_id = UNSET
        else:
            current_storage_sublocation_id = UUID(_current_storage_sublocation_id)




        storage_path = d.pop("storage_path", UNSET)

        v_labware_contents = cls(
            labware_id=labware_id,
            barcode=barcode,
            display_name=display_name,
            status=status,
            position_label=position_label,
            sample_id=sample_id,
            sample_name=sample_name,
            sample_status=sample_status,
            volume=volume,
            volume_unit=volume_unit,
            current_storage_sublocation_id=current_storage_sublocation_id,
            storage_path=storage_path,
        )


        v_labware_contents.additional_properties = d
        return v_labware_contents

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
