from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from ..types import UNSET, Unset
from typing import Union
from uuid import UUID






T = TypeVar("T", bound="VSampleOverview")



@_attrs_define
class VSampleOverview:
    """ 
        Attributes:
            id (Union[Unset, UUID]): Note:
                This is a Primary Key.<pk/>
            name (Union[Unset, str]):
            sample_type_code (Union[Unset, str]):
            sample_status (Union[Unset, str]):
            collected_at (Union[Unset, str]):
            project_id (Union[Unset, UUID]):
            project_code (Union[Unset, str]):
            project_name (Union[Unset, str]):
            current_labware_id (Union[Unset, UUID]):
            current_labware_barcode (Union[Unset, str]):
            current_labware_name (Union[Unset, str]):
            storage_path (Union[Unset, str]):
            derivatives (Union[Unset, Any]):
     """

    id: Union[Unset, UUID] = UNSET
    name: Union[Unset, str] = UNSET
    sample_type_code: Union[Unset, str] = UNSET
    sample_status: Union[Unset, str] = UNSET
    collected_at: Union[Unset, str] = UNSET
    project_id: Union[Unset, UUID] = UNSET
    project_code: Union[Unset, str] = UNSET
    project_name: Union[Unset, str] = UNSET
    current_labware_id: Union[Unset, UUID] = UNSET
    current_labware_barcode: Union[Unset, str] = UNSET
    current_labware_name: Union[Unset, str] = UNSET
    storage_path: Union[Unset, str] = UNSET
    derivatives: Union[Unset, Any] = UNSET
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        id: Union[Unset, str] = UNSET
        if not isinstance(self.id, Unset):
            id = str(self.id)

        name = self.name

        sample_type_code = self.sample_type_code

        sample_status = self.sample_status

        collected_at = self.collected_at

        project_id: Union[Unset, str] = UNSET
        if not isinstance(self.project_id, Unset):
            project_id = str(self.project_id)

        project_code = self.project_code

        project_name = self.project_name

        current_labware_id: Union[Unset, str] = UNSET
        if not isinstance(self.current_labware_id, Unset):
            current_labware_id = str(self.current_labware_id)

        current_labware_barcode = self.current_labware_barcode

        current_labware_name = self.current_labware_name

        storage_path = self.storage_path

        derivatives = self.derivatives


        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
        })
        if id is not UNSET:
            field_dict["id"] = id
        if name is not UNSET:
            field_dict["name"] = name
        if sample_type_code is not UNSET:
            field_dict["sample_type_code"] = sample_type_code
        if sample_status is not UNSET:
            field_dict["sample_status"] = sample_status
        if collected_at is not UNSET:
            field_dict["collected_at"] = collected_at
        if project_id is not UNSET:
            field_dict["project_id"] = project_id
        if project_code is not UNSET:
            field_dict["project_code"] = project_code
        if project_name is not UNSET:
            field_dict["project_name"] = project_name
        if current_labware_id is not UNSET:
            field_dict["current_labware_id"] = current_labware_id
        if current_labware_barcode is not UNSET:
            field_dict["current_labware_barcode"] = current_labware_barcode
        if current_labware_name is not UNSET:
            field_dict["current_labware_name"] = current_labware_name
        if storage_path is not UNSET:
            field_dict["storage_path"] = storage_path
        if derivatives is not UNSET:
            field_dict["derivatives"] = derivatives

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        _id = d.pop("id", UNSET)
        id: Union[Unset, UUID]
        if isinstance(_id,  Unset):
            id = UNSET
        else:
            id = UUID(_id)




        name = d.pop("name", UNSET)

        sample_type_code = d.pop("sample_type_code", UNSET)

        sample_status = d.pop("sample_status", UNSET)

        collected_at = d.pop("collected_at", UNSET)

        _project_id = d.pop("project_id", UNSET)
        project_id: Union[Unset, UUID]
        if isinstance(_project_id,  Unset):
            project_id = UNSET
        else:
            project_id = UUID(_project_id)




        project_code = d.pop("project_code", UNSET)

        project_name = d.pop("project_name", UNSET)

        _current_labware_id = d.pop("current_labware_id", UNSET)
        current_labware_id: Union[Unset, UUID]
        if isinstance(_current_labware_id,  Unset):
            current_labware_id = UNSET
        else:
            current_labware_id = UUID(_current_labware_id)




        current_labware_barcode = d.pop("current_labware_barcode", UNSET)

        current_labware_name = d.pop("current_labware_name", UNSET)

        storage_path = d.pop("storage_path", UNSET)

        derivatives = d.pop("derivatives", UNSET)

        v_sample_overview = cls(
            id=id,
            name=name,
            sample_type_code=sample_type_code,
            sample_status=sample_status,
            collected_at=collected_at,
            project_id=project_id,
            project_code=project_code,
            project_name=project_name,
            current_labware_id=current_labware_id,
            current_labware_barcode=current_labware_barcode,
            current_labware_name=current_labware_name,
            storage_path=storage_path,
            derivatives=derivatives,
        )


        v_sample_overview.additional_properties = d
        return v_sample_overview

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
