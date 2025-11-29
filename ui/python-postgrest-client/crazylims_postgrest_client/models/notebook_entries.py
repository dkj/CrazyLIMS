from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from ..types import UNSET, Unset
from typing import Union
from uuid import UUID






T = TypeVar("T", bound="NotebookEntries")



@_attrs_define
class NotebookEntries:
    """ @omit

        Attributes:
            entry_id (Union[Unset, UUID]): Note:
                This is a Primary Key.<pk/>
            entry_key (Union[Unset, str]):
            title (Union[Unset, str]):
            description (Union[Unset, str]):
            primary_scope_id (Union[Unset, UUID]): Note:
                This is a Foreign Key to `v_sample_lineage.child_project_id`.<fk table='v_sample_lineage'
                column='child_project_id'/>
            status (Union[Unset, str]):
            metadata (Union[Unset, Any]):
            submitted_at (Union[Unset, str]):
            submitted_by (Union[Unset, UUID]): Note:
                This is a Foreign Key to `users.id`.<fk table='users' column='id'/>
            locked_at (Union[Unset, str]):
            locked_by (Union[Unset, UUID]): Note:
                This is a Foreign Key to `users.id`.<fk table='users' column='id'/>
            created_at (Union[Unset, str]):
            created_by (Union[Unset, UUID]): Note:
                This is a Foreign Key to `users.id`.<fk table='users' column='id'/>
            updated_at (Union[Unset, str]):
            updated_by (Union[Unset, UUID]): Note:
                This is a Foreign Key to `users.id`.<fk table='users' column='id'/>
     """

    entry_id: Union[Unset, UUID] = UNSET
    entry_key: Union[Unset, str] = UNSET
    title: Union[Unset, str] = UNSET
    description: Union[Unset, str] = UNSET
    primary_scope_id: Union[Unset, UUID] = UNSET
    status: Union[Unset, str] = UNSET
    metadata: Union[Unset, Any] = UNSET
    submitted_at: Union[Unset, str] = UNSET
    submitted_by: Union[Unset, UUID] = UNSET
    locked_at: Union[Unset, str] = UNSET
    locked_by: Union[Unset, UUID] = UNSET
    created_at: Union[Unset, str] = UNSET
    created_by: Union[Unset, UUID] = UNSET
    updated_at: Union[Unset, str] = UNSET
    updated_by: Union[Unset, UUID] = UNSET
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        entry_id: Union[Unset, str] = UNSET
        if not isinstance(self.entry_id, Unset):
            entry_id = str(self.entry_id)

        entry_key = self.entry_key

        title = self.title

        description = self.description

        primary_scope_id: Union[Unset, str] = UNSET
        if not isinstance(self.primary_scope_id, Unset):
            primary_scope_id = str(self.primary_scope_id)

        status = self.status

        metadata = self.metadata

        submitted_at = self.submitted_at

        submitted_by: Union[Unset, str] = UNSET
        if not isinstance(self.submitted_by, Unset):
            submitted_by = str(self.submitted_by)

        locked_at = self.locked_at

        locked_by: Union[Unset, str] = UNSET
        if not isinstance(self.locked_by, Unset):
            locked_by = str(self.locked_by)

        created_at = self.created_at

        created_by: Union[Unset, str] = UNSET
        if not isinstance(self.created_by, Unset):
            created_by = str(self.created_by)

        updated_at = self.updated_at

        updated_by: Union[Unset, str] = UNSET
        if not isinstance(self.updated_by, Unset):
            updated_by = str(self.updated_by)


        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
        })
        if entry_id is not UNSET:
            field_dict["entry_id"] = entry_id
        if entry_key is not UNSET:
            field_dict["entry_key"] = entry_key
        if title is not UNSET:
            field_dict["title"] = title
        if description is not UNSET:
            field_dict["description"] = description
        if primary_scope_id is not UNSET:
            field_dict["primary_scope_id"] = primary_scope_id
        if status is not UNSET:
            field_dict["status"] = status
        if metadata is not UNSET:
            field_dict["metadata"] = metadata
        if submitted_at is not UNSET:
            field_dict["submitted_at"] = submitted_at
        if submitted_by is not UNSET:
            field_dict["submitted_by"] = submitted_by
        if locked_at is not UNSET:
            field_dict["locked_at"] = locked_at
        if locked_by is not UNSET:
            field_dict["locked_by"] = locked_by
        if created_at is not UNSET:
            field_dict["created_at"] = created_at
        if created_by is not UNSET:
            field_dict["created_by"] = created_by
        if updated_at is not UNSET:
            field_dict["updated_at"] = updated_at
        if updated_by is not UNSET:
            field_dict["updated_by"] = updated_by

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        _entry_id = d.pop("entry_id", UNSET)
        entry_id: Union[Unset, UUID]
        if isinstance(_entry_id,  Unset):
            entry_id = UNSET
        else:
            entry_id = UUID(_entry_id)




        entry_key = d.pop("entry_key", UNSET)

        title = d.pop("title", UNSET)

        description = d.pop("description", UNSET)

        _primary_scope_id = d.pop("primary_scope_id", UNSET)
        primary_scope_id: Union[Unset, UUID]
        if isinstance(_primary_scope_id,  Unset):
            primary_scope_id = UNSET
        else:
            primary_scope_id = UUID(_primary_scope_id)




        status = d.pop("status", UNSET)

        metadata = d.pop("metadata", UNSET)

        submitted_at = d.pop("submitted_at", UNSET)

        _submitted_by = d.pop("submitted_by", UNSET)
        submitted_by: Union[Unset, UUID]
        if isinstance(_submitted_by,  Unset):
            submitted_by = UNSET
        else:
            submitted_by = UUID(_submitted_by)




        locked_at = d.pop("locked_at", UNSET)

        _locked_by = d.pop("locked_by", UNSET)
        locked_by: Union[Unset, UUID]
        if isinstance(_locked_by,  Unset):
            locked_by = UNSET
        else:
            locked_by = UUID(_locked_by)




        created_at = d.pop("created_at", UNSET)

        _created_by = d.pop("created_by", UNSET)
        created_by: Union[Unset, UUID]
        if isinstance(_created_by,  Unset):
            created_by = UNSET
        else:
            created_by = UUID(_created_by)




        updated_at = d.pop("updated_at", UNSET)

        _updated_by = d.pop("updated_by", UNSET)
        updated_by: Union[Unset, UUID]
        if isinstance(_updated_by,  Unset):
            updated_by = UNSET
        else:
            updated_by = UUID(_updated_by)




        notebook_entries = cls(
            entry_id=entry_id,
            entry_key=entry_key,
            title=title,
            description=description,
            primary_scope_id=primary_scope_id,
            status=status,
            metadata=metadata,
            submitted_at=submitted_at,
            submitted_by=submitted_by,
            locked_at=locked_at,
            locked_by=locked_by,
            created_at=created_at,
            created_by=created_by,
            updated_at=updated_at,
            updated_by=updated_by,
        )


        notebook_entries.additional_properties = d
        return notebook_entries

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
