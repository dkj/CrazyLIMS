from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from ..types import UNSET, Unset
from typing import cast
from typing import Union
from uuid import UUID






T = TypeVar("T", bound="PostRpcActorHasScopeJsonBody")



@_attrs_define
class PostRpcActorHasScopeJsonBody:
    """ 
        Attributes:
            p_scope_id (UUID):
            p_actor_id (Union[Unset, UUID]):
            p_required_roles (Union[Unset, list[str]]):
     """

    p_scope_id: UUID
    p_actor_id: Union[Unset, UUID] = UNSET
    p_required_roles: Union[Unset, list[str]] = UNSET
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        p_scope_id = str(self.p_scope_id)

        p_actor_id: Union[Unset, str] = UNSET
        if not isinstance(self.p_actor_id, Unset):
            p_actor_id = str(self.p_actor_id)

        p_required_roles: Union[Unset, list[str]] = UNSET
        if not isinstance(self.p_required_roles, Unset):
            p_required_roles = self.p_required_roles




        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
            "p_scope_id": p_scope_id,
        })
        if p_actor_id is not UNSET:
            field_dict["p_actor_id"] = p_actor_id
        if p_required_roles is not UNSET:
            field_dict["p_required_roles"] = p_required_roles

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        p_scope_id = UUID(d.pop("p_scope_id"))




        _p_actor_id = d.pop("p_actor_id", UNSET)
        p_actor_id: Union[Unset, UUID]
        if isinstance(_p_actor_id,  Unset):
            p_actor_id = UNSET
        else:
            p_actor_id = UUID(_p_actor_id)




        p_required_roles = cast(list[str], d.pop("p_required_roles", UNSET))


        post_rpc_actor_has_scope_json_body = cls(
            p_scope_id=p_scope_id,
            p_actor_id=p_actor_id,
            p_required_roles=p_required_roles,
        )


        post_rpc_actor_has_scope_json_body.additional_properties = d
        return post_rpc_actor_has_scope_json_body

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
