from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from ..types import UNSET, Unset
from typing import Union
from uuid import UUID






T = TypeVar("T", bound="UserRoles")



@_attrs_define
class UserRoles:
    """ 
        Attributes:
            user_id (UUID): Note:
                This is a Primary Key.<pk/>
                This is a Foreign Key to `users.id`.<fk table='users' column='id'/>
            role_name (str): Note:
                This is a Primary Key.<pk/>
                This is a Foreign Key to `roles.role_name`.<fk table='roles' column='role_name'/>
            granted_at (str):  Default: 'clock_timestamp()'.
            granted_by (Union[Unset, UUID]): Note:
                This is a Foreign Key to `users.id`.<fk table='users' column='id'/>
     """

    user_id: UUID
    role_name: str
    granted_at: str = 'clock_timestamp()'
    granted_by: Union[Unset, UUID] = UNSET
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        user_id = str(self.user_id)

        role_name = self.role_name

        granted_at = self.granted_at

        granted_by: Union[Unset, str] = UNSET
        if not isinstance(self.granted_by, Unset):
            granted_by = str(self.granted_by)


        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
            "user_id": user_id,
            "role_name": role_name,
            "granted_at": granted_at,
        })
        if granted_by is not UNSET:
            field_dict["granted_by"] = granted_by

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        user_id = UUID(d.pop("user_id"))




        role_name = d.pop("role_name")

        granted_at = d.pop("granted_at")

        _granted_by = d.pop("granted_by", UNSET)
        granted_by: Union[Unset, UUID]
        if isinstance(_granted_by,  Unset):
            granted_by = UNSET
        else:
            granted_by = UUID(_granted_by)




        user_roles = cls(
            user_id=user_id,
            role_name=role_name,
            granted_at=granted_at,
            granted_by=granted_by,
        )


        user_roles.additional_properties = d
        return user_roles

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
