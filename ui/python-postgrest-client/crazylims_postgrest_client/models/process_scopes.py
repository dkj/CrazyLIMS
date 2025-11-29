from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from ..types import UNSET, Unset
from typing import Union
from uuid import UUID






T = TypeVar("T", bound="ProcessScopes")



@_attrs_define
class ProcessScopes:
    """ 
        Attributes:
            process_instance_id (UUID): Note:
                This is a Primary Key.<pk/>
                This is a Foreign Key to `process_instances.process_instance_id`.<fk table='process_instances'
                column='process_instance_id'/>
            scope_id (UUID): Note:
                This is a Primary Key.<pk/>
            relationship (str): Note:
                This is a Primary Key.<pk/> Default: 'primary'.
            assigned_at (str):  Default: 'clock_timestamp()'.
            metadata (Any):
            assigned_by (Union[Unset, UUID]):
     """

    process_instance_id: UUID
    scope_id: UUID
    metadata: Any
    relationship: str = 'primary'
    assigned_at: str = 'clock_timestamp()'
    assigned_by: Union[Unset, UUID] = UNSET
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        process_instance_id = str(self.process_instance_id)

        scope_id = str(self.scope_id)

        relationship = self.relationship

        assigned_at = self.assigned_at

        metadata = self.metadata

        assigned_by: Union[Unset, str] = UNSET
        if not isinstance(self.assigned_by, Unset):
            assigned_by = str(self.assigned_by)


        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
            "process_instance_id": process_instance_id,
            "scope_id": scope_id,
            "relationship": relationship,
            "assigned_at": assigned_at,
            "metadata": metadata,
        })
        if assigned_by is not UNSET:
            field_dict["assigned_by"] = assigned_by

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        process_instance_id = UUID(d.pop("process_instance_id"))




        scope_id = UUID(d.pop("scope_id"))




        relationship = d.pop("relationship")

        assigned_at = d.pop("assigned_at")

        metadata = d.pop("metadata")

        _assigned_by = d.pop("assigned_by", UNSET)
        assigned_by: Union[Unset, UUID]
        if isinstance(_assigned_by,  Unset):
            assigned_by = UNSET
        else:
            assigned_by = UUID(_assigned_by)




        process_scopes = cls(
            process_instance_id=process_instance_id,
            scope_id=scope_id,
            relationship=relationship,
            assigned_at=assigned_at,
            metadata=metadata,
            assigned_by=assigned_by,
        )


        process_scopes.additional_properties = d
        return process_scopes

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
