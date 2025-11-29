from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset







T = TypeVar("T", bound="ScopeRoleInheritance")



@_attrs_define
class ScopeRoleInheritance:
    """ 
        Attributes:
            parent_scope_type (str): Note:
                This is a Primary Key.<pk/>
            child_scope_type (str): Note:
                This is a Primary Key.<pk/>
            parent_role_name (str): Note:
                This is a Primary Key.<pk/>
            child_role_name (str): Note:
                This is a Primary Key.<pk/>
            is_active (bool):  Default: True.
     """

    parent_scope_type: str
    child_scope_type: str
    parent_role_name: str
    child_role_name: str
    is_active: bool = True
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        parent_scope_type = self.parent_scope_type

        child_scope_type = self.child_scope_type

        parent_role_name = self.parent_role_name

        child_role_name = self.child_role_name

        is_active = self.is_active


        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
            "parent_scope_type": parent_scope_type,
            "child_scope_type": child_scope_type,
            "parent_role_name": parent_role_name,
            "child_role_name": child_role_name,
            "is_active": is_active,
        })

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        parent_scope_type = d.pop("parent_scope_type")

        child_scope_type = d.pop("child_scope_type")

        parent_role_name = d.pop("parent_role_name")

        child_role_name = d.pop("child_role_name")

        is_active = d.pop("is_active")

        scope_role_inheritance = cls(
            parent_scope_type=parent_scope_type,
            child_scope_type=child_scope_type,
            parent_role_name=parent_role_name,
            child_role_name=child_role_name,
            is_active=is_active,
        )


        scope_role_inheritance.additional_properties = d
        return scope_role_inheritance

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
