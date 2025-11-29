from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from ..types import UNSET, Unset
from typing import cast
from typing import Union
from uuid import UUID






T = TypeVar("T", bound="PostRpcSpTransferBetweenScopesJsonBody")



@_attrs_define
class PostRpcSpTransferBetweenScopesJsonBody:
    """ 
        Attributes:
            p_artefact_ids (list[str]):
            p_source_scope_id (UUID):
            p_target_scope_key (str):
            p_target_scope_type (str):
            p_allowed_roles (Union[Unset, list[str]]):
            p_field_whitelist (Union[Unset, list[str]]):
            p_relationship_metadata (Union[Unset, Any]):
            p_relationship_type (Union[Unset, str]):
            p_scope_metadata (Union[Unset, Any]):
            p_target_parent_scope_id (Union[Unset, UUID]):
     """

    p_artefact_ids: list[str]
    p_source_scope_id: UUID
    p_target_scope_key: str
    p_target_scope_type: str
    p_allowed_roles: Union[Unset, list[str]] = UNSET
    p_field_whitelist: Union[Unset, list[str]] = UNSET
    p_relationship_metadata: Union[Unset, Any] = UNSET
    p_relationship_type: Union[Unset, str] = UNSET
    p_scope_metadata: Union[Unset, Any] = UNSET
    p_target_parent_scope_id: Union[Unset, UUID] = UNSET
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        p_artefact_ids = self.p_artefact_ids



        p_source_scope_id = str(self.p_source_scope_id)

        p_target_scope_key = self.p_target_scope_key

        p_target_scope_type = self.p_target_scope_type

        p_allowed_roles: Union[Unset, list[str]] = UNSET
        if not isinstance(self.p_allowed_roles, Unset):
            p_allowed_roles = self.p_allowed_roles



        p_field_whitelist: Union[Unset, list[str]] = UNSET
        if not isinstance(self.p_field_whitelist, Unset):
            p_field_whitelist = self.p_field_whitelist



        p_relationship_metadata = self.p_relationship_metadata

        p_relationship_type = self.p_relationship_type

        p_scope_metadata = self.p_scope_metadata

        p_target_parent_scope_id: Union[Unset, str] = UNSET
        if not isinstance(self.p_target_parent_scope_id, Unset):
            p_target_parent_scope_id = str(self.p_target_parent_scope_id)


        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
            "p_artefact_ids": p_artefact_ids,
            "p_source_scope_id": p_source_scope_id,
            "p_target_scope_key": p_target_scope_key,
            "p_target_scope_type": p_target_scope_type,
        })
        if p_allowed_roles is not UNSET:
            field_dict["p_allowed_roles"] = p_allowed_roles
        if p_field_whitelist is not UNSET:
            field_dict["p_field_whitelist"] = p_field_whitelist
        if p_relationship_metadata is not UNSET:
            field_dict["p_relationship_metadata"] = p_relationship_metadata
        if p_relationship_type is not UNSET:
            field_dict["p_relationship_type"] = p_relationship_type
        if p_scope_metadata is not UNSET:
            field_dict["p_scope_metadata"] = p_scope_metadata
        if p_target_parent_scope_id is not UNSET:
            field_dict["p_target_parent_scope_id"] = p_target_parent_scope_id

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        p_artefact_ids = cast(list[str], d.pop("p_artefact_ids"))


        p_source_scope_id = UUID(d.pop("p_source_scope_id"))




        p_target_scope_key = d.pop("p_target_scope_key")

        p_target_scope_type = d.pop("p_target_scope_type")

        p_allowed_roles = cast(list[str], d.pop("p_allowed_roles", UNSET))


        p_field_whitelist = cast(list[str], d.pop("p_field_whitelist", UNSET))


        p_relationship_metadata = d.pop("p_relationship_metadata", UNSET)

        p_relationship_type = d.pop("p_relationship_type", UNSET)

        p_scope_metadata = d.pop("p_scope_metadata", UNSET)

        _p_target_parent_scope_id = d.pop("p_target_parent_scope_id", UNSET)
        p_target_parent_scope_id: Union[Unset, UUID]
        if isinstance(_p_target_parent_scope_id,  Unset):
            p_target_parent_scope_id = UNSET
        else:
            p_target_parent_scope_id = UUID(_p_target_parent_scope_id)




        post_rpc_sp_transfer_between_scopes_json_body = cls(
            p_artefact_ids=p_artefact_ids,
            p_source_scope_id=p_source_scope_id,
            p_target_scope_key=p_target_scope_key,
            p_target_scope_type=p_target_scope_type,
            p_allowed_roles=p_allowed_roles,
            p_field_whitelist=p_field_whitelist,
            p_relationship_metadata=p_relationship_metadata,
            p_relationship_type=p_relationship_type,
            p_scope_metadata=p_scope_metadata,
            p_target_parent_scope_id=p_target_parent_scope_id,
        )


        post_rpc_sp_transfer_between_scopes_json_body.additional_properties = d
        return post_rpc_sp_transfer_between_scopes_json_body

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
