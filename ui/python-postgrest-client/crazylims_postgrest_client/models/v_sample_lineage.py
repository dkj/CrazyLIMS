from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from ..types import UNSET, Unset
from typing import Union
from uuid import UUID






T = TypeVar("T", bound="VSampleLineage")



@_attrs_define
class VSampleLineage:
    """ 
        Attributes:
            parent_sample_id (Union[Unset, UUID]):
            parent_sample_name (Union[Unset, str]):
            parent_sample_type_code (Union[Unset, str]):
            parent_project_id (Union[Unset, UUID]): Note:
                This is a Primary Key.<pk/>
            parent_labware_id (Union[Unset, UUID]):
            parent_labware_barcode (Union[Unset, str]):
            parent_labware_name (Union[Unset, str]):
            parent_storage_path (Union[Unset, str]):
            child_sample_id (Union[Unset, UUID]):
            child_sample_name (Union[Unset, str]):
            child_sample_type_code (Union[Unset, str]):
            child_project_id (Union[Unset, UUID]):
            child_labware_id (Union[Unset, UUID]): Note:
                This is a Primary Key.<pk/>
            child_labware_barcode (Union[Unset, str]):
            child_labware_name (Union[Unset, str]):
            child_storage_path (Union[Unset, str]):
            method (Union[Unset, str]):
            created_at (Union[Unset, str]):
            created_by (Union[Unset, str]):
     """

    parent_sample_id: Union[Unset, UUID] = UNSET
    parent_sample_name: Union[Unset, str] = UNSET
    parent_sample_type_code: Union[Unset, str] = UNSET
    parent_project_id: Union[Unset, UUID] = UNSET
    parent_labware_id: Union[Unset, UUID] = UNSET
    parent_labware_barcode: Union[Unset, str] = UNSET
    parent_labware_name: Union[Unset, str] = UNSET
    parent_storage_path: Union[Unset, str] = UNSET
    child_sample_id: Union[Unset, UUID] = UNSET
    child_sample_name: Union[Unset, str] = UNSET
    child_sample_type_code: Union[Unset, str] = UNSET
    child_project_id: Union[Unset, UUID] = UNSET
    child_labware_id: Union[Unset, UUID] = UNSET
    child_labware_barcode: Union[Unset, str] = UNSET
    child_labware_name: Union[Unset, str] = UNSET
    child_storage_path: Union[Unset, str] = UNSET
    method: Union[Unset, str] = UNSET
    created_at: Union[Unset, str] = UNSET
    created_by: Union[Unset, str] = UNSET
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        parent_sample_id: Union[Unset, str] = UNSET
        if not isinstance(self.parent_sample_id, Unset):
            parent_sample_id = str(self.parent_sample_id)

        parent_sample_name = self.parent_sample_name

        parent_sample_type_code = self.parent_sample_type_code

        parent_project_id: Union[Unset, str] = UNSET
        if not isinstance(self.parent_project_id, Unset):
            parent_project_id = str(self.parent_project_id)

        parent_labware_id: Union[Unset, str] = UNSET
        if not isinstance(self.parent_labware_id, Unset):
            parent_labware_id = str(self.parent_labware_id)

        parent_labware_barcode = self.parent_labware_barcode

        parent_labware_name = self.parent_labware_name

        parent_storage_path = self.parent_storage_path

        child_sample_id: Union[Unset, str] = UNSET
        if not isinstance(self.child_sample_id, Unset):
            child_sample_id = str(self.child_sample_id)

        child_sample_name = self.child_sample_name

        child_sample_type_code = self.child_sample_type_code

        child_project_id: Union[Unset, str] = UNSET
        if not isinstance(self.child_project_id, Unset):
            child_project_id = str(self.child_project_id)

        child_labware_id: Union[Unset, str] = UNSET
        if not isinstance(self.child_labware_id, Unset):
            child_labware_id = str(self.child_labware_id)

        child_labware_barcode = self.child_labware_barcode

        child_labware_name = self.child_labware_name

        child_storage_path = self.child_storage_path

        method = self.method

        created_at = self.created_at

        created_by = self.created_by


        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
        })
        if parent_sample_id is not UNSET:
            field_dict["parent_sample_id"] = parent_sample_id
        if parent_sample_name is not UNSET:
            field_dict["parent_sample_name"] = parent_sample_name
        if parent_sample_type_code is not UNSET:
            field_dict["parent_sample_type_code"] = parent_sample_type_code
        if parent_project_id is not UNSET:
            field_dict["parent_project_id"] = parent_project_id
        if parent_labware_id is not UNSET:
            field_dict["parent_labware_id"] = parent_labware_id
        if parent_labware_barcode is not UNSET:
            field_dict["parent_labware_barcode"] = parent_labware_barcode
        if parent_labware_name is not UNSET:
            field_dict["parent_labware_name"] = parent_labware_name
        if parent_storage_path is not UNSET:
            field_dict["parent_storage_path"] = parent_storage_path
        if child_sample_id is not UNSET:
            field_dict["child_sample_id"] = child_sample_id
        if child_sample_name is not UNSET:
            field_dict["child_sample_name"] = child_sample_name
        if child_sample_type_code is not UNSET:
            field_dict["child_sample_type_code"] = child_sample_type_code
        if child_project_id is not UNSET:
            field_dict["child_project_id"] = child_project_id
        if child_labware_id is not UNSET:
            field_dict["child_labware_id"] = child_labware_id
        if child_labware_barcode is not UNSET:
            field_dict["child_labware_barcode"] = child_labware_barcode
        if child_labware_name is not UNSET:
            field_dict["child_labware_name"] = child_labware_name
        if child_storage_path is not UNSET:
            field_dict["child_storage_path"] = child_storage_path
        if method is not UNSET:
            field_dict["method"] = method
        if created_at is not UNSET:
            field_dict["created_at"] = created_at
        if created_by is not UNSET:
            field_dict["created_by"] = created_by

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        _parent_sample_id = d.pop("parent_sample_id", UNSET)
        parent_sample_id: Union[Unset, UUID]
        if isinstance(_parent_sample_id,  Unset):
            parent_sample_id = UNSET
        else:
            parent_sample_id = UUID(_parent_sample_id)




        parent_sample_name = d.pop("parent_sample_name", UNSET)

        parent_sample_type_code = d.pop("parent_sample_type_code", UNSET)

        _parent_project_id = d.pop("parent_project_id", UNSET)
        parent_project_id: Union[Unset, UUID]
        if isinstance(_parent_project_id,  Unset):
            parent_project_id = UNSET
        else:
            parent_project_id = UUID(_parent_project_id)




        _parent_labware_id = d.pop("parent_labware_id", UNSET)
        parent_labware_id: Union[Unset, UUID]
        if isinstance(_parent_labware_id,  Unset):
            parent_labware_id = UNSET
        else:
            parent_labware_id = UUID(_parent_labware_id)




        parent_labware_barcode = d.pop("parent_labware_barcode", UNSET)

        parent_labware_name = d.pop("parent_labware_name", UNSET)

        parent_storage_path = d.pop("parent_storage_path", UNSET)

        _child_sample_id = d.pop("child_sample_id", UNSET)
        child_sample_id: Union[Unset, UUID]
        if isinstance(_child_sample_id,  Unset):
            child_sample_id = UNSET
        else:
            child_sample_id = UUID(_child_sample_id)




        child_sample_name = d.pop("child_sample_name", UNSET)

        child_sample_type_code = d.pop("child_sample_type_code", UNSET)

        _child_project_id = d.pop("child_project_id", UNSET)
        child_project_id: Union[Unset, UUID]
        if isinstance(_child_project_id,  Unset):
            child_project_id = UNSET
        else:
            child_project_id = UUID(_child_project_id)




        _child_labware_id = d.pop("child_labware_id", UNSET)
        child_labware_id: Union[Unset, UUID]
        if isinstance(_child_labware_id,  Unset):
            child_labware_id = UNSET
        else:
            child_labware_id = UUID(_child_labware_id)




        child_labware_barcode = d.pop("child_labware_barcode", UNSET)

        child_labware_name = d.pop("child_labware_name", UNSET)

        child_storage_path = d.pop("child_storage_path", UNSET)

        method = d.pop("method", UNSET)

        created_at = d.pop("created_at", UNSET)

        created_by = d.pop("created_by", UNSET)

        v_sample_lineage = cls(
            parent_sample_id=parent_sample_id,
            parent_sample_name=parent_sample_name,
            parent_sample_type_code=parent_sample_type_code,
            parent_project_id=parent_project_id,
            parent_labware_id=parent_labware_id,
            parent_labware_barcode=parent_labware_barcode,
            parent_labware_name=parent_labware_name,
            parent_storage_path=parent_storage_path,
            child_sample_id=child_sample_id,
            child_sample_name=child_sample_name,
            child_sample_type_code=child_sample_type_code,
            child_project_id=child_project_id,
            child_labware_id=child_labware_id,
            child_labware_barcode=child_labware_barcode,
            child_labware_name=child_labware_name,
            child_storage_path=child_storage_path,
            method=method,
            created_at=created_at,
            created_by=created_by,
        )


        v_sample_lineage.additional_properties = d
        return v_sample_lineage

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
