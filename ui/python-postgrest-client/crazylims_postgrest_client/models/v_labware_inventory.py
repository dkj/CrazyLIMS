from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from ..types import UNSET, Unset
from typing import Union
from uuid import UUID






T = TypeVar("T", bound="VLabwareInventory")



@_attrs_define
class VLabwareInventory:
    """ 
        Attributes:
            labware_id (Union[Unset, UUID]): Note:
                This is a Primary Key.<pk/>
            barcode (Union[Unset, str]):
            display_name (Union[Unset, str]):
            status (Union[Unset, str]):
            labware_type (Union[Unset, str]):
            current_storage_sublocation_id (Union[Unset, UUID]): Note:
                This is a Foreign Key to `v_inventory_status.id`.<fk table='v_inventory_status' column='id'/>
            storage_path (Union[Unset, str]):
            active_sample_count (Union[Unset, int]):
            active_samples (Union[Unset, Any]):
     """

    labware_id: Union[Unset, UUID] = UNSET
    barcode: Union[Unset, str] = UNSET
    display_name: Union[Unset, str] = UNSET
    status: Union[Unset, str] = UNSET
    labware_type: Union[Unset, str] = UNSET
    current_storage_sublocation_id: Union[Unset, UUID] = UNSET
    storage_path: Union[Unset, str] = UNSET
    active_sample_count: Union[Unset, int] = UNSET
    active_samples: Union[Unset, Any] = UNSET
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        labware_id: Union[Unset, str] = UNSET
        if not isinstance(self.labware_id, Unset):
            labware_id = str(self.labware_id)

        barcode = self.barcode

        display_name = self.display_name

        status = self.status

        labware_type = self.labware_type

        current_storage_sublocation_id: Union[Unset, str] = UNSET
        if not isinstance(self.current_storage_sublocation_id, Unset):
            current_storage_sublocation_id = str(self.current_storage_sublocation_id)

        storage_path = self.storage_path

        active_sample_count = self.active_sample_count

        active_samples = self.active_samples


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
        if labware_type is not UNSET:
            field_dict["labware_type"] = labware_type
        if current_storage_sublocation_id is not UNSET:
            field_dict["current_storage_sublocation_id"] = current_storage_sublocation_id
        if storage_path is not UNSET:
            field_dict["storage_path"] = storage_path
        if active_sample_count is not UNSET:
            field_dict["active_sample_count"] = active_sample_count
        if active_samples is not UNSET:
            field_dict["active_samples"] = active_samples

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

        labware_type = d.pop("labware_type", UNSET)

        _current_storage_sublocation_id = d.pop("current_storage_sublocation_id", UNSET)
        current_storage_sublocation_id: Union[Unset, UUID]
        if isinstance(_current_storage_sublocation_id,  Unset):
            current_storage_sublocation_id = UNSET
        else:
            current_storage_sublocation_id = UUID(_current_storage_sublocation_id)




        storage_path = d.pop("storage_path", UNSET)

        active_sample_count = d.pop("active_sample_count", UNSET)

        active_samples = d.pop("active_samples", UNSET)

        v_labware_inventory = cls(
            labware_id=labware_id,
            barcode=barcode,
            display_name=display_name,
            status=status,
            labware_type=labware_type,
            current_storage_sublocation_id=current_storage_sublocation_id,
            storage_path=storage_path,
            active_sample_count=active_sample_count,
            active_samples=active_samples,
        )


        v_labware_inventory.additional_properties = d
        return v_labware_inventory

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
