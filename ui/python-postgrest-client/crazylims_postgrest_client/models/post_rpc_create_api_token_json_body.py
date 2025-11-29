from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from ..types import UNSET, Unset
from typing import cast
from typing import Union
from uuid import UUID






T = TypeVar("T", bound="PostRpcCreateApiTokenJsonBody")



@_attrs_define
class PostRpcCreateApiTokenJsonBody:
    """ 
        Attributes:
            p_allowed_roles (list[str]):
            p_plaintext_token (str):
            p_user_id (UUID):
            p_client_identifier (Union[Unset, str]):
            p_expires_at (Union[Unset, str]):
            p_metadata (Union[Unset, Any]):
     """

    p_allowed_roles: list[str]
    p_plaintext_token: str
    p_user_id: UUID
    p_client_identifier: Union[Unset, str] = UNSET
    p_expires_at: Union[Unset, str] = UNSET
    p_metadata: Union[Unset, Any] = UNSET
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        p_allowed_roles = self.p_allowed_roles



        p_plaintext_token = self.p_plaintext_token

        p_user_id = str(self.p_user_id)

        p_client_identifier = self.p_client_identifier

        p_expires_at = self.p_expires_at

        p_metadata = self.p_metadata


        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
            "p_allowed_roles": p_allowed_roles,
            "p_plaintext_token": p_plaintext_token,
            "p_user_id": p_user_id,
        })
        if p_client_identifier is not UNSET:
            field_dict["p_client_identifier"] = p_client_identifier
        if p_expires_at is not UNSET:
            field_dict["p_expires_at"] = p_expires_at
        if p_metadata is not UNSET:
            field_dict["p_metadata"] = p_metadata

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        p_allowed_roles = cast(list[str], d.pop("p_allowed_roles"))


        p_plaintext_token = d.pop("p_plaintext_token")

        p_user_id = UUID(d.pop("p_user_id"))




        p_client_identifier = d.pop("p_client_identifier", UNSET)

        p_expires_at = d.pop("p_expires_at", UNSET)

        p_metadata = d.pop("p_metadata", UNSET)

        post_rpc_create_api_token_json_body = cls(
            p_allowed_roles=p_allowed_roles,
            p_plaintext_token=p_plaintext_token,
            p_user_id=p_user_id,
            p_client_identifier=p_client_identifier,
            p_expires_at=p_expires_at,
            p_metadata=p_metadata,
        )


        post_rpc_create_api_token_json_body.additional_properties = d
        return post_rpc_create_api_token_json_body

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
