from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from ..types import UNSET, Unset
from typing import cast
from typing import Union
from uuid import UUID






T = TypeVar("T", bound="AuditLog")



@_attrs_define
class AuditLog:
    """ 
        Attributes:
            audit_id (int): Note:
                This is a Primary Key.<pk/>
            txn_id (UUID): Note:
                This is a Foreign Key to `transaction_contexts.txn_id`.<fk table='transaction_contexts' column='txn_id'/>
            schema_name (str):
            table_name (str):
            operation (str):
            actor_roles (list[str]):
            performed_at (str):  Default: 'clock_timestamp()'.
            primary_key_data (Union[Unset, Any]):
            row_before (Union[Unset, Any]):
            row_after (Union[Unset, Any]):
            actor_id (Union[Unset, UUID]):
            actor_identity (Union[Unset, str]):
     """

    audit_id: int
    txn_id: UUID
    schema_name: str
    table_name: str
    operation: str
    actor_roles: list[str]
    performed_at: str = 'clock_timestamp()'
    primary_key_data: Union[Unset, Any] = UNSET
    row_before: Union[Unset, Any] = UNSET
    row_after: Union[Unset, Any] = UNSET
    actor_id: Union[Unset, UUID] = UNSET
    actor_identity: Union[Unset, str] = UNSET
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        audit_id = self.audit_id

        txn_id = str(self.txn_id)

        schema_name = self.schema_name

        table_name = self.table_name

        operation = self.operation

        actor_roles = self.actor_roles



        performed_at = self.performed_at

        primary_key_data = self.primary_key_data

        row_before = self.row_before

        row_after = self.row_after

        actor_id: Union[Unset, str] = UNSET
        if not isinstance(self.actor_id, Unset):
            actor_id = str(self.actor_id)

        actor_identity = self.actor_identity


        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
            "audit_id": audit_id,
            "txn_id": txn_id,
            "schema_name": schema_name,
            "table_name": table_name,
            "operation": operation,
            "actor_roles": actor_roles,
            "performed_at": performed_at,
        })
        if primary_key_data is not UNSET:
            field_dict["primary_key_data"] = primary_key_data
        if row_before is not UNSET:
            field_dict["row_before"] = row_before
        if row_after is not UNSET:
            field_dict["row_after"] = row_after
        if actor_id is not UNSET:
            field_dict["actor_id"] = actor_id
        if actor_identity is not UNSET:
            field_dict["actor_identity"] = actor_identity

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        audit_id = d.pop("audit_id")

        txn_id = UUID(d.pop("txn_id"))




        schema_name = d.pop("schema_name")

        table_name = d.pop("table_name")

        operation = d.pop("operation")

        actor_roles = cast(list[str], d.pop("actor_roles"))


        performed_at = d.pop("performed_at")

        primary_key_data = d.pop("primary_key_data", UNSET)

        row_before = d.pop("row_before", UNSET)

        row_after = d.pop("row_after", UNSET)

        _actor_id = d.pop("actor_id", UNSET)
        actor_id: Union[Unset, UUID]
        if isinstance(_actor_id,  Unset):
            actor_id = UNSET
        else:
            actor_id = UUID(_actor_id)




        actor_identity = d.pop("actor_identity", UNSET)

        audit_log = cls(
            audit_id=audit_id,
            txn_id=txn_id,
            schema_name=schema_name,
            table_name=table_name,
            operation=operation,
            actor_roles=actor_roles,
            performed_at=performed_at,
            primary_key_data=primary_key_data,
            row_before=row_before,
            row_after=row_after,
            actor_id=actor_id,
            actor_identity=actor_identity,
        )


        audit_log.additional_properties = d
        return audit_log

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
