from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from uuid import UUID






T = TypeVar("T", bound="PostRpcSpDemultiplexOutputsJsonBody")



@_attrs_define
class PostRpcSpDemultiplexOutputsJsonBody:
    """ 
        Attributes:
            p_contributors (Any):
            p_pool_artefact_id (UUID):
            p_run_metadata (Any):
     """

    p_contributors: Any
    p_pool_artefact_id: UUID
    p_run_metadata: Any
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        p_contributors = self.p_contributors

        p_pool_artefact_id = str(self.p_pool_artefact_id)

        p_run_metadata = self.p_run_metadata


        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
            "p_contributors": p_contributors,
            "p_pool_artefact_id": p_pool_artefact_id,
            "p_run_metadata": p_run_metadata,
        })

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        p_contributors = d.pop("p_contributors")

        p_pool_artefact_id = UUID(d.pop("p_pool_artefact_id"))




        p_run_metadata = d.pop("p_run_metadata")

        post_rpc_sp_demultiplex_outputs_json_body = cls(
            p_contributors=p_contributors,
            p_pool_artefact_id=p_pool_artefact_id,
            p_run_metadata=p_run_metadata,
        )


        post_rpc_sp_demultiplex_outputs_json_body.additional_properties = d
        return post_rpc_sp_demultiplex_outputs_json_body

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
