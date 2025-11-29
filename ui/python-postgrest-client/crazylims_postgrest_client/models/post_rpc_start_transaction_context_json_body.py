from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from ..types import UNSET, Unset
from typing import cast
from typing import Union
from uuid import UUID






T = TypeVar("T", bound="PostRpcStartTransactionContextJsonBody")



@_attrs_define
class PostRpcStartTransactionContextJsonBody:
    """ 
        Attributes:
            p_actor_id (Union[Unset, UUID]):
            p_actor_identity (Union[Unset, str]):
            p_client_app (Union[Unset, str]):
            p_client_ip (Union[Unset, str]):
            p_effective_roles (Union[Unset, list[str]]):
            p_impersonated_roles (Union[Unset, list[str]]):
            p_jwt_claims (Union[Unset, Any]):
            p_metadata (Union[Unset, Any]):
     """

    p_actor_id: Union[Unset, UUID] = UNSET
    p_actor_identity: Union[Unset, str] = UNSET
    p_client_app: Union[Unset, str] = UNSET
    p_client_ip: Union[Unset, str] = UNSET
    p_effective_roles: Union[Unset, list[str]] = UNSET
    p_impersonated_roles: Union[Unset, list[str]] = UNSET
    p_jwt_claims: Union[Unset, Any] = UNSET
    p_metadata: Union[Unset, Any] = UNSET
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        p_actor_id: Union[Unset, str] = UNSET
        if not isinstance(self.p_actor_id, Unset):
            p_actor_id = str(self.p_actor_id)

        p_actor_identity = self.p_actor_identity

        p_client_app = self.p_client_app

        p_client_ip = self.p_client_ip

        p_effective_roles: Union[Unset, list[str]] = UNSET
        if not isinstance(self.p_effective_roles, Unset):
            p_effective_roles = self.p_effective_roles



        p_impersonated_roles: Union[Unset, list[str]] = UNSET
        if not isinstance(self.p_impersonated_roles, Unset):
            p_impersonated_roles = self.p_impersonated_roles



        p_jwt_claims = self.p_jwt_claims

        p_metadata = self.p_metadata


        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
        })
        if p_actor_id is not UNSET:
            field_dict["p_actor_id"] = p_actor_id
        if p_actor_identity is not UNSET:
            field_dict["p_actor_identity"] = p_actor_identity
        if p_client_app is not UNSET:
            field_dict["p_client_app"] = p_client_app
        if p_client_ip is not UNSET:
            field_dict["p_client_ip"] = p_client_ip
        if p_effective_roles is not UNSET:
            field_dict["p_effective_roles"] = p_effective_roles
        if p_impersonated_roles is not UNSET:
            field_dict["p_impersonated_roles"] = p_impersonated_roles
        if p_jwt_claims is not UNSET:
            field_dict["p_jwt_claims"] = p_jwt_claims
        if p_metadata is not UNSET:
            field_dict["p_metadata"] = p_metadata

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        _p_actor_id = d.pop("p_actor_id", UNSET)
        p_actor_id: Union[Unset, UUID]
        if isinstance(_p_actor_id,  Unset):
            p_actor_id = UNSET
        else:
            p_actor_id = UUID(_p_actor_id)




        p_actor_identity = d.pop("p_actor_identity", UNSET)

        p_client_app = d.pop("p_client_app", UNSET)

        p_client_ip = d.pop("p_client_ip", UNSET)

        p_effective_roles = cast(list[str], d.pop("p_effective_roles", UNSET))


        p_impersonated_roles = cast(list[str], d.pop("p_impersonated_roles", UNSET))


        p_jwt_claims = d.pop("p_jwt_claims", UNSET)

        p_metadata = d.pop("p_metadata", UNSET)

        post_rpc_start_transaction_context_json_body = cls(
            p_actor_id=p_actor_id,
            p_actor_identity=p_actor_identity,
            p_client_app=p_client_app,
            p_client_ip=p_client_ip,
            p_effective_roles=p_effective_roles,
            p_impersonated_roles=p_impersonated_roles,
            p_jwt_claims=p_jwt_claims,
            p_metadata=p_metadata,
        )


        post_rpc_start_transaction_context_json_body.additional_properties = d
        return post_rpc_start_transaction_context_json_body

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
