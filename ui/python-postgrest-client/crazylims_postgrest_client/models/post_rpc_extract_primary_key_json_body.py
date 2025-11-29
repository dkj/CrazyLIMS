from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset







T = TypeVar("T", bound="PostRpcExtractPrimaryKeyJsonBody")



@_attrs_define
class PostRpcExtractPrimaryKeyJsonBody:
    """ 
        Attributes:
            p_row (Any):
            p_schema (str):
            p_table (str):
     """

    p_row: Any
    p_schema: str
    p_table: str
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        p_row = self.p_row

        p_schema = self.p_schema

        p_table = self.p_table


        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
            "p_row": p_row,
            "p_schema": p_schema,
            "p_table": p_table,
        })

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        p_row = d.pop("p_row")

        p_schema = d.pop("p_schema")

        p_table = d.pop("p_table")

        post_rpc_extract_primary_key_json_body = cls(
            p_row=p_row,
            p_schema=p_schema,
            p_table=p_table,
        )


        post_rpc_extract_primary_key_json_body.additional_properties = d
        return post_rpc_extract_primary_key_json_body

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
