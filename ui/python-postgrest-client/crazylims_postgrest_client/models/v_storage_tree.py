from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from ..types import UNSET, Unset
from typing import Union
from uuid import UUID






T = TypeVar("T", bound="VStorageTree")



@_attrs_define
class VStorageTree:
    """ 
        Attributes:
            facility_id (Union[Unset, UUID]):
            facility_name (Union[Unset, str]):
            unit_id (Union[Unset, UUID]):
            unit_name (Union[Unset, str]):
            storage_type (Union[Unset, str]):
            sublocation_id (Union[Unset, UUID]):
            sublocation_name (Union[Unset, str]):
            parent_sublocation_id (Union[Unset, UUID]):
            capacity (Union[Unset, int]):
            storage_path (Union[Unset, str]):
            labware_count (Union[Unset, int]):
            sample_count (Union[Unset, int]):
     """

    facility_id: Union[Unset, UUID] = UNSET
    facility_name: Union[Unset, str] = UNSET
    unit_id: Union[Unset, UUID] = UNSET
    unit_name: Union[Unset, str] = UNSET
    storage_type: Union[Unset, str] = UNSET
    sublocation_id: Union[Unset, UUID] = UNSET
    sublocation_name: Union[Unset, str] = UNSET
    parent_sublocation_id: Union[Unset, UUID] = UNSET
    capacity: Union[Unset, int] = UNSET
    storage_path: Union[Unset, str] = UNSET
    labware_count: Union[Unset, int] = UNSET
    sample_count: Union[Unset, int] = UNSET
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        facility_id: Union[Unset, str] = UNSET
        if not isinstance(self.facility_id, Unset):
            facility_id = str(self.facility_id)

        facility_name = self.facility_name

        unit_id: Union[Unset, str] = UNSET
        if not isinstance(self.unit_id, Unset):
            unit_id = str(self.unit_id)

        unit_name = self.unit_name

        storage_type = self.storage_type

        sublocation_id: Union[Unset, str] = UNSET
        if not isinstance(self.sublocation_id, Unset):
            sublocation_id = str(self.sublocation_id)

        sublocation_name = self.sublocation_name

        parent_sublocation_id: Union[Unset, str] = UNSET
        if not isinstance(self.parent_sublocation_id, Unset):
            parent_sublocation_id = str(self.parent_sublocation_id)

        capacity = self.capacity

        storage_path = self.storage_path

        labware_count = self.labware_count

        sample_count = self.sample_count


        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
        })
        if facility_id is not UNSET:
            field_dict["facility_id"] = facility_id
        if facility_name is not UNSET:
            field_dict["facility_name"] = facility_name
        if unit_id is not UNSET:
            field_dict["unit_id"] = unit_id
        if unit_name is not UNSET:
            field_dict["unit_name"] = unit_name
        if storage_type is not UNSET:
            field_dict["storage_type"] = storage_type
        if sublocation_id is not UNSET:
            field_dict["sublocation_id"] = sublocation_id
        if sublocation_name is not UNSET:
            field_dict["sublocation_name"] = sublocation_name
        if parent_sublocation_id is not UNSET:
            field_dict["parent_sublocation_id"] = parent_sublocation_id
        if capacity is not UNSET:
            field_dict["capacity"] = capacity
        if storage_path is not UNSET:
            field_dict["storage_path"] = storage_path
        if labware_count is not UNSET:
            field_dict["labware_count"] = labware_count
        if sample_count is not UNSET:
            field_dict["sample_count"] = sample_count

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        _facility_id = d.pop("facility_id", UNSET)
        facility_id: Union[Unset, UUID]
        if isinstance(_facility_id,  Unset):
            facility_id = UNSET
        else:
            facility_id = UUID(_facility_id)




        facility_name = d.pop("facility_name", UNSET)

        _unit_id = d.pop("unit_id", UNSET)
        unit_id: Union[Unset, UUID]
        if isinstance(_unit_id,  Unset):
            unit_id = UNSET
        else:
            unit_id = UUID(_unit_id)




        unit_name = d.pop("unit_name", UNSET)

        storage_type = d.pop("storage_type", UNSET)

        _sublocation_id = d.pop("sublocation_id", UNSET)
        sublocation_id: Union[Unset, UUID]
        if isinstance(_sublocation_id,  Unset):
            sublocation_id = UNSET
        else:
            sublocation_id = UUID(_sublocation_id)




        sublocation_name = d.pop("sublocation_name", UNSET)

        _parent_sublocation_id = d.pop("parent_sublocation_id", UNSET)
        parent_sublocation_id: Union[Unset, UUID]
        if isinstance(_parent_sublocation_id,  Unset):
            parent_sublocation_id = UNSET
        else:
            parent_sublocation_id = UUID(_parent_sublocation_id)




        capacity = d.pop("capacity", UNSET)

        storage_path = d.pop("storage_path", UNSET)

        labware_count = d.pop("labware_count", UNSET)

        sample_count = d.pop("sample_count", UNSET)

        v_storage_tree = cls(
            facility_id=facility_id,
            facility_name=facility_name,
            unit_id=unit_id,
            unit_name=unit_name,
            storage_type=storage_type,
            sublocation_id=sublocation_id,
            sublocation_name=sublocation_name,
            parent_sublocation_id=parent_sublocation_id,
            capacity=capacity,
            storage_path=storage_path,
            labware_count=labware_count,
            sample_count=sample_count,
        )


        v_storage_tree.additional_properties = d
        return v_storage_tree

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
