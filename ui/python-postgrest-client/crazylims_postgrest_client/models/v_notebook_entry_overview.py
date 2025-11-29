from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from ..types import UNSET, Unset
from typing import Union
from uuid import UUID






T = TypeVar("T", bound="VNotebookEntryOverview")



@_attrs_define
class VNotebookEntryOverview:
    """ @omit

        Attributes:
            entry_id (Union[Unset, UUID]):
            entry_key (Union[Unset, str]):
            title (Union[Unset, str]):
            description (Union[Unset, str]):
            status (Union[Unset, str]):
            primary_scope_id (Union[Unset, UUID]):
            primary_scope_key (Union[Unset, str]):
            primary_scope_name (Union[Unset, str]):
            metadata (Union[Unset, Any]):
            submitted_at (Union[Unset, str]):
            submitted_by (Union[Unset, UUID]):
            locked_at (Union[Unset, str]):
            locked_by (Union[Unset, UUID]):
            created_at (Union[Unset, str]):
            created_by (Union[Unset, UUID]):
            updated_at (Union[Unset, str]):
            updated_by (Union[Unset, UUID]):
            latest_version (Union[Unset, int]):
            latest_version_created_at (Union[Unset, str]):
            latest_version_created_by (Union[Unset, UUID]):
     """

    entry_id: Union[Unset, UUID] = UNSET
    entry_key: Union[Unset, str] = UNSET
    title: Union[Unset, str] = UNSET
    description: Union[Unset, str] = UNSET
    status: Union[Unset, str] = UNSET
    primary_scope_id: Union[Unset, UUID] = UNSET
    primary_scope_key: Union[Unset, str] = UNSET
    primary_scope_name: Union[Unset, str] = UNSET
    metadata: Union[Unset, Any] = UNSET
    submitted_at: Union[Unset, str] = UNSET
    submitted_by: Union[Unset, UUID] = UNSET
    locked_at: Union[Unset, str] = UNSET
    locked_by: Union[Unset, UUID] = UNSET
    created_at: Union[Unset, str] = UNSET
    created_by: Union[Unset, UUID] = UNSET
    updated_at: Union[Unset, str] = UNSET
    updated_by: Union[Unset, UUID] = UNSET
    latest_version: Union[Unset, int] = UNSET
    latest_version_created_at: Union[Unset, str] = UNSET
    latest_version_created_by: Union[Unset, UUID] = UNSET
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        entry_id: Union[Unset, str] = UNSET
        if not isinstance(self.entry_id, Unset):
            entry_id = str(self.entry_id)

        entry_key = self.entry_key

        title = self.title

        description = self.description

        status = self.status

        primary_scope_id: Union[Unset, str] = UNSET
        if not isinstance(self.primary_scope_id, Unset):
            primary_scope_id = str(self.primary_scope_id)

        primary_scope_key = self.primary_scope_key

        primary_scope_name = self.primary_scope_name

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

        latest_version = self.latest_version

        latest_version_created_at = self.latest_version_created_at

        latest_version_created_by: Union[Unset, str] = UNSET
        if not isinstance(self.latest_version_created_by, Unset):
            latest_version_created_by = str(self.latest_version_created_by)


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
        if status is not UNSET:
            field_dict["status"] = status
        if primary_scope_id is not UNSET:
            field_dict["primary_scope_id"] = primary_scope_id
        if primary_scope_key is not UNSET:
            field_dict["primary_scope_key"] = primary_scope_key
        if primary_scope_name is not UNSET:
            field_dict["primary_scope_name"] = primary_scope_name
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
        if latest_version is not UNSET:
            field_dict["latest_version"] = latest_version
        if latest_version_created_at is not UNSET:
            field_dict["latest_version_created_at"] = latest_version_created_at
        if latest_version_created_by is not UNSET:
            field_dict["latest_version_created_by"] = latest_version_created_by

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

        status = d.pop("status", UNSET)

        _primary_scope_id = d.pop("primary_scope_id", UNSET)
        primary_scope_id: Union[Unset, UUID]
        if isinstance(_primary_scope_id,  Unset):
            primary_scope_id = UNSET
        else:
            primary_scope_id = UUID(_primary_scope_id)




        primary_scope_key = d.pop("primary_scope_key", UNSET)

        primary_scope_name = d.pop("primary_scope_name", UNSET)

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




        latest_version = d.pop("latest_version", UNSET)

        latest_version_created_at = d.pop("latest_version_created_at", UNSET)

        _latest_version_created_by = d.pop("latest_version_created_by", UNSET)
        latest_version_created_by: Union[Unset, UUID]
        if isinstance(_latest_version_created_by,  Unset):
            latest_version_created_by = UNSET
        else:
            latest_version_created_by = UUID(_latest_version_created_by)




        v_notebook_entry_overview = cls(
            entry_id=entry_id,
            entry_key=entry_key,
            title=title,
            description=description,
            status=status,
            primary_scope_id=primary_scope_id,
            primary_scope_key=primary_scope_key,
            primary_scope_name=primary_scope_name,
            metadata=metadata,
            submitted_at=submitted_at,
            submitted_by=submitted_by,
            locked_at=locked_at,
            locked_by=locked_by,
            created_at=created_at,
            created_by=created_by,
            updated_at=updated_at,
            updated_by=updated_by,
            latest_version=latest_version,
            latest_version_created_at=latest_version_created_at,
            latest_version_created_by=latest_version_created_by,
        )


        v_notebook_entry_overview.additional_properties = d
        return v_notebook_entry_overview

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
