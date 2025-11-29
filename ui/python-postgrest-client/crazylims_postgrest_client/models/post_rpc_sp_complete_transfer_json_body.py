from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from ..types import UNSET, Unset
from typing import cast
from typing import Union
from uuid import UUID






T = TypeVar("T", bound="PostRpcSpCompleteTransferJsonBody")



@_attrs_define
class PostRpcSpCompleteTransferJsonBody:
    """ 
        Attributes:
            p_target_artefact_id (UUID):
            p_completion_state (Union[Unset, str]):
            p_relationship_type (Union[Unset, str]):
            p_return_scope_ids (Union[Unset, list[str]]):
            p_state_metadata (Union[Unset, Any]):
     """

    p_target_artefact_id: UUID
    p_completion_state: Union[Unset, str] = UNSET
    p_relationship_type: Union[Unset, str] = UNSET
    p_return_scope_ids: Union[Unset, list[str]] = UNSET
    p_state_metadata: Union[Unset, Any] = UNSET
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        p_target_artefact_id = str(self.p_target_artefact_id)

        p_completion_state = self.p_completion_state

        p_relationship_type = self.p_relationship_type

        p_return_scope_ids: Union[Unset, list[str]] = UNSET
        if not isinstance(self.p_return_scope_ids, Unset):
            p_return_scope_ids = self.p_return_scope_ids



        p_state_metadata = self.p_state_metadata


        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
            "p_target_artefact_id": p_target_artefact_id,
        })
        if p_completion_state is not UNSET:
            field_dict["p_completion_state"] = p_completion_state
        if p_relationship_type is not UNSET:
            field_dict["p_relationship_type"] = p_relationship_type
        if p_return_scope_ids is not UNSET:
            field_dict["p_return_scope_ids"] = p_return_scope_ids
        if p_state_metadata is not UNSET:
            field_dict["p_state_metadata"] = p_state_metadata

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        p_target_artefact_id = UUID(d.pop("p_target_artefact_id"))




        p_completion_state = d.pop("p_completion_state", UNSET)

        p_relationship_type = d.pop("p_relationship_type", UNSET)

        p_return_scope_ids = cast(list[str], d.pop("p_return_scope_ids", UNSET))


        p_state_metadata = d.pop("p_state_metadata", UNSET)

        post_rpc_sp_complete_transfer_json_body = cls(
            p_target_artefact_id=p_target_artefact_id,
            p_completion_state=p_completion_state,
            p_relationship_type=p_relationship_type,
            p_return_scope_ids=p_return_scope_ids,
            p_state_metadata=p_state_metadata,
        )


        post_rpc_sp_complete_transfer_json_body.additional_properties = d
        return post_rpc_sp_complete_transfer_json_body

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
