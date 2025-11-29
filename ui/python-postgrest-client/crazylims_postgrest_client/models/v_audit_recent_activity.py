from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from ..types import UNSET, Unset
from typing import cast
from typing import Union
from uuid import UUID






T = TypeVar("T", bound="VAuditRecentActivity")



@_attrs_define
class VAuditRecentActivity:
    """ 
        Attributes:
            audit_id (Union[Unset, int]): Note:
                This is a Primary Key.<pk/>
            performed_at (Union[Unset, str]):
            schema_name (Union[Unset, str]):
            table_name (Union[Unset, str]):
            operation (Union[Unset, str]):
            txn_id (Union[Unset, UUID]): Note:
                This is a Foreign Key to `transaction_contexts.txn_id`.<fk table='transaction_contexts' column='txn_id'/>
            actor_id (Union[Unset, UUID]):
            actor_identity (Union[Unset, str]):
            actor_roles (Union[Unset, list[str]]):
     """

    audit_id: Union[Unset, int] = UNSET
    performed_at: Union[Unset, str] = UNSET
    schema_name: Union[Unset, str] = UNSET
    table_name: Union[Unset, str] = UNSET
    operation: Union[Unset, str] = UNSET
    txn_id: Union[Unset, UUID] = UNSET
    actor_id: Union[Unset, UUID] = UNSET
    actor_identity: Union[Unset, str] = UNSET
    actor_roles: Union[Unset, list[str]] = UNSET
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        audit_id = self.audit_id

        performed_at = self.performed_at

        schema_name = self.schema_name

        table_name = self.table_name

        operation = self.operation

        txn_id: Union[Unset, str] = UNSET
        if not isinstance(self.txn_id, Unset):
            txn_id = str(self.txn_id)

        actor_id: Union[Unset, str] = UNSET
        if not isinstance(self.actor_id, Unset):
            actor_id = str(self.actor_id)

        actor_identity = self.actor_identity

        actor_roles: Union[Unset, list[str]] = UNSET
        if not isinstance(self.actor_roles, Unset):
            actor_roles = self.actor_roles




        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
        })
        if audit_id is not UNSET:
            field_dict["audit_id"] = audit_id
        if performed_at is not UNSET:
            field_dict["performed_at"] = performed_at
        if schema_name is not UNSET:
            field_dict["schema_name"] = schema_name
        if table_name is not UNSET:
            field_dict["table_name"] = table_name
        if operation is not UNSET:
            field_dict["operation"] = operation
        if txn_id is not UNSET:
            field_dict["txn_id"] = txn_id
        if actor_id is not UNSET:
            field_dict["actor_id"] = actor_id
        if actor_identity is not UNSET:
            field_dict["actor_identity"] = actor_identity
        if actor_roles is not UNSET:
            field_dict["actor_roles"] = actor_roles

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        audit_id = d.pop("audit_id", UNSET)

        performed_at = d.pop("performed_at", UNSET)

        schema_name = d.pop("schema_name", UNSET)

        table_name = d.pop("table_name", UNSET)

        operation = d.pop("operation", UNSET)

        _txn_id = d.pop("txn_id", UNSET)
        txn_id: Union[Unset, UUID]
        if isinstance(_txn_id,  Unset):
            txn_id = UNSET
        else:
            txn_id = UUID(_txn_id)




        _actor_id = d.pop("actor_id", UNSET)
        actor_id: Union[Unset, UUID]
        if isinstance(_actor_id,  Unset):
            actor_id = UNSET
        else:
            actor_id = UUID(_actor_id)




        actor_identity = d.pop("actor_identity", UNSET)

        actor_roles = cast(list[str], d.pop("actor_roles", UNSET))


        v_audit_recent_activity = cls(
            audit_id=audit_id,
            performed_at=performed_at,
            schema_name=schema_name,
            table_name=table_name,
            operation=operation,
            txn_id=txn_id,
            actor_id=actor_id,
            actor_identity=actor_identity,
            actor_roles=actor_roles,
        )


        v_audit_recent_activity.additional_properties = d
        return v_audit_recent_activity

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
