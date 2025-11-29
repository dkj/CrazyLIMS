from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from ..types import UNSET, Unset
from typing import Union
from uuid import UUID






T = TypeVar("T", bound="Roles")



@_attrs_define
class Roles:
    """ 
        Attributes:
            role_name (str): Note:
                This is a Primary Key.<pk/>
            display_name (str):
            is_system_role (bool):  Default: False.
            is_assignable (bool):  Default: True.
            created_at (str):  Default: 'clock_timestamp()'.
            description (Union[Unset, str]):
            created_by (Union[Unset, UUID]):
     """

    role_name: str
    display_name: str
    is_system_role: bool = False
    is_assignable: bool = True
    created_at: str = 'clock_timestamp()'
    description: Union[Unset, str] = UNSET
    created_by: Union[Unset, UUID] = UNSET
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        role_name = self.role_name

        display_name = self.display_name

        is_system_role = self.is_system_role

        is_assignable = self.is_assignable

        created_at = self.created_at

        description = self.description

        created_by: Union[Unset, str] = UNSET
        if not isinstance(self.created_by, Unset):
            created_by = str(self.created_by)


        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
            "role_name": role_name,
            "display_name": display_name,
            "is_system_role": is_system_role,
            "is_assignable": is_assignable,
            "created_at": created_at,
        })
        if description is not UNSET:
            field_dict["description"] = description
        if created_by is not UNSET:
            field_dict["created_by"] = created_by

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        role_name = d.pop("role_name")

        display_name = d.pop("display_name")

        is_system_role = d.pop("is_system_role")

        is_assignable = d.pop("is_assignable")

        created_at = d.pop("created_at")

        description = d.pop("description", UNSET)

        _created_by = d.pop("created_by", UNSET)
        created_by: Union[Unset, UUID]
        if isinstance(_created_by,  Unset):
            created_by = UNSET
        else:
            created_by = UUID(_created_by)




        roles = cls(
            role_name=role_name,
            display_name=display_name,
            is_system_role=is_system_role,
            is_assignable=is_assignable,
            created_at=created_at,
            description=description,
            created_by=created_by,
        )


        roles.additional_properties = d
        return roles

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
