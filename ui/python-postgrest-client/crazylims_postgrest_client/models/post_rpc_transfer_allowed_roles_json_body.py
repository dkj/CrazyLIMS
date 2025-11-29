from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from ..types import UNSET, Unset
from typing import Union
from uuid import UUID






T = TypeVar("T", bound="PostRpcTransferAllowedRolesJsonBody")



@_attrs_define
class PostRpcTransferAllowedRolesJsonBody:
    """ 
        Attributes:
            p_artefact_id (UUID):
            p_relationship_type (Union[Unset, str]):
     """

    p_artefact_id: UUID
    p_relationship_type: Union[Unset, str] = UNSET
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        p_artefact_id = str(self.p_artefact_id)

        p_relationship_type = self.p_relationship_type


        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
            "p_artefact_id": p_artefact_id,
        })
        if p_relationship_type is not UNSET:
            field_dict["p_relationship_type"] = p_relationship_type

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        p_artefact_id = UUID(d.pop("p_artefact_id"))




        p_relationship_type = d.pop("p_relationship_type", UNSET)

        post_rpc_transfer_allowed_roles_json_body = cls(
            p_artefact_id=p_artefact_id,
            p_relationship_type=p_relationship_type,
        )


        post_rpc_transfer_allowed_roles_json_body.additional_properties = d
        return post_rpc_transfer_allowed_roles_json_body

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
