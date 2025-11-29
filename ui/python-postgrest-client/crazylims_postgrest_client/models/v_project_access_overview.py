from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from ..types import UNSET, Unset
from typing import Union
from uuid import UUID






T = TypeVar("T", bound="VProjectAccessOverview")



@_attrs_define
class VProjectAccessOverview:
    """ 
        Attributes:
            id (Union[Unset, UUID]):
            project_code (Union[Unset, str]):
            name (Union[Unset, str]):
            description (Union[Unset, str]):
            is_member (Union[Unset, bool]):
            access_via (Union[Unset, str]):
            sample_count (Union[Unset, int]):
            active_labware_count (Union[Unset, int]):
     """

    id: Union[Unset, UUID] = UNSET
    project_code: Union[Unset, str] = UNSET
    name: Union[Unset, str] = UNSET
    description: Union[Unset, str] = UNSET
    is_member: Union[Unset, bool] = UNSET
    access_via: Union[Unset, str] = UNSET
    sample_count: Union[Unset, int] = UNSET
    active_labware_count: Union[Unset, int] = UNSET
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        id: Union[Unset, str] = UNSET
        if not isinstance(self.id, Unset):
            id = str(self.id)

        project_code = self.project_code

        name = self.name

        description = self.description

        is_member = self.is_member

        access_via = self.access_via

        sample_count = self.sample_count

        active_labware_count = self.active_labware_count


        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
        })
        if id is not UNSET:
            field_dict["id"] = id
        if project_code is not UNSET:
            field_dict["project_code"] = project_code
        if name is not UNSET:
            field_dict["name"] = name
        if description is not UNSET:
            field_dict["description"] = description
        if is_member is not UNSET:
            field_dict["is_member"] = is_member
        if access_via is not UNSET:
            field_dict["access_via"] = access_via
        if sample_count is not UNSET:
            field_dict["sample_count"] = sample_count
        if active_labware_count is not UNSET:
            field_dict["active_labware_count"] = active_labware_count

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




        project_code = d.pop("project_code", UNSET)

        name = d.pop("name", UNSET)

        description = d.pop("description", UNSET)

        is_member = d.pop("is_member", UNSET)

        access_via = d.pop("access_via", UNSET)

        sample_count = d.pop("sample_count", UNSET)

        active_labware_count = d.pop("active_labware_count", UNSET)

        v_project_access_overview = cls(
            id=id,
            project_code=project_code,
            name=name,
            description=description,
            is_member=is_member,
            access_via=access_via,
            sample_count=sample_count,
            active_labware_count=active_labware_count,
        )


        v_project_access_overview.additional_properties = d
        return v_project_access_overview

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
