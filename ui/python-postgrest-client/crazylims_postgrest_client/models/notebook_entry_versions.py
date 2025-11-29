from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from ..types import UNSET, Unset
from typing import Union
from uuid import UUID






T = TypeVar("T", bound="NotebookEntryVersions")



@_attrs_define
class NotebookEntryVersions:
    """ @omit

        Attributes:
            version_id (Union[Unset, UUID]): Note:
                This is a Primary Key.<pk/>
            entry_id (Union[Unset, UUID]): Note:
                This is a Foreign Key to `notebook_entries.entry_id`.<fk table='notebook_entries' column='entry_id'/>
            version_number (Union[Unset, int]):
            notebook_json (Union[Unset, Any]):
            checksum (Union[Unset, str]):
            note (Union[Unset, str]):
            metadata (Union[Unset, Any]):
            created_at (Union[Unset, str]):
            created_by (Union[Unset, UUID]): Note:
                This is a Foreign Key to `users.id`.<fk table='users' column='id'/>
     """

    version_id: Union[Unset, UUID] = UNSET
    entry_id: Union[Unset, UUID] = UNSET
    version_number: Union[Unset, int] = UNSET
    notebook_json: Union[Unset, Any] = UNSET
    checksum: Union[Unset, str] = UNSET
    note: Union[Unset, str] = UNSET
    metadata: Union[Unset, Any] = UNSET
    created_at: Union[Unset, str] = UNSET
    created_by: Union[Unset, UUID] = UNSET
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        version_id: Union[Unset, str] = UNSET
        if not isinstance(self.version_id, Unset):
            version_id = str(self.version_id)

        entry_id: Union[Unset, str] = UNSET
        if not isinstance(self.entry_id, Unset):
            entry_id = str(self.entry_id)

        version_number = self.version_number

        notebook_json = self.notebook_json

        checksum = self.checksum

        note = self.note

        metadata = self.metadata

        created_at = self.created_at

        created_by: Union[Unset, str] = UNSET
        if not isinstance(self.created_by, Unset):
            created_by = str(self.created_by)


        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
        })
        if version_id is not UNSET:
            field_dict["version_id"] = version_id
        if entry_id is not UNSET:
            field_dict["entry_id"] = entry_id
        if version_number is not UNSET:
            field_dict["version_number"] = version_number
        if notebook_json is not UNSET:
            field_dict["notebook_json"] = notebook_json
        if checksum is not UNSET:
            field_dict["checksum"] = checksum
        if note is not UNSET:
            field_dict["note"] = note
        if metadata is not UNSET:
            field_dict["metadata"] = metadata
        if created_at is not UNSET:
            field_dict["created_at"] = created_at
        if created_by is not UNSET:
            field_dict["created_by"] = created_by

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        _version_id = d.pop("version_id", UNSET)
        version_id: Union[Unset, UUID]
        if isinstance(_version_id,  Unset):
            version_id = UNSET
        else:
            version_id = UUID(_version_id)




        _entry_id = d.pop("entry_id", UNSET)
        entry_id: Union[Unset, UUID]
        if isinstance(_entry_id,  Unset):
            entry_id = UNSET
        else:
            entry_id = UUID(_entry_id)




        version_number = d.pop("version_number", UNSET)

        notebook_json = d.pop("notebook_json", UNSET)

        checksum = d.pop("checksum", UNSET)

        note = d.pop("note", UNSET)

        metadata = d.pop("metadata", UNSET)

        created_at = d.pop("created_at", UNSET)

        _created_by = d.pop("created_by", UNSET)
        created_by: Union[Unset, UUID]
        if isinstance(_created_by,  Unset):
            created_by = UNSET
        else:
            created_by = UUID(_created_by)




        notebook_entry_versions = cls(
            version_id=version_id,
            entry_id=entry_id,
            version_number=version_number,
            notebook_json=notebook_json,
            checksum=checksum,
            note=note,
            metadata=metadata,
            created_at=created_at,
            created_by=created_by,
        )


        notebook_entry_versions.additional_properties = d
        return notebook_entry_versions

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
