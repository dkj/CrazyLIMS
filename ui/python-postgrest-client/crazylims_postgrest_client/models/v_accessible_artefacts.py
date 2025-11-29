from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from ..types import UNSET, Unset
from typing import Union
from uuid import UUID






T = TypeVar("T", bound="VAccessibleArtefacts")



@_attrs_define
class VAccessibleArtefacts:
    """ 
        Attributes:
            artefact_id (Union[Unset, UUID]): Note:
                This is a Primary Key.<pk/>
            name (Union[Unset, str]):
            status (Union[Unset, str]):
            is_virtual (Union[Unset, bool]):
            quantity (Union[Unset, float]):
            quantity_unit (Union[Unset, str]):
            type_key (Union[Unset, str]):
            artefact_type (Union[Unset, str]):
            artefact_kind (Union[Unset, str]):
            primary_scope_id (Union[Unset, UUID]):
            primary_scope_name (Union[Unset, str]):
            primary_scope_type (Union[Unset, str]):
            storage_node_id (Union[Unset, UUID]): Note:
                This is a Foreign Key to `artefacts.artefact_id`.<fk table='artefacts' column='artefact_id'/>
            storage_display_name (Union[Unset, str]):
            storage_node_type (Union[Unset, str]):
            last_event_type (Union[Unset, str]):
            last_event_at (Union[Unset, str]):
     """

    artefact_id: Union[Unset, UUID] = UNSET
    name: Union[Unset, str] = UNSET
    status: Union[Unset, str] = UNSET
    is_virtual: Union[Unset, bool] = UNSET
    quantity: Union[Unset, float] = UNSET
    quantity_unit: Union[Unset, str] = UNSET
    type_key: Union[Unset, str] = UNSET
    artefact_type: Union[Unset, str] = UNSET
    artefact_kind: Union[Unset, str] = UNSET
    primary_scope_id: Union[Unset, UUID] = UNSET
    primary_scope_name: Union[Unset, str] = UNSET
    primary_scope_type: Union[Unset, str] = UNSET
    storage_node_id: Union[Unset, UUID] = UNSET
    storage_display_name: Union[Unset, str] = UNSET
    storage_node_type: Union[Unset, str] = UNSET
    last_event_type: Union[Unset, str] = UNSET
    last_event_at: Union[Unset, str] = UNSET
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        artefact_id: Union[Unset, str] = UNSET
        if not isinstance(self.artefact_id, Unset):
            artefact_id = str(self.artefact_id)

        name = self.name

        status = self.status

        is_virtual = self.is_virtual

        quantity = self.quantity

        quantity_unit = self.quantity_unit

        type_key = self.type_key

        artefact_type = self.artefact_type

        artefact_kind = self.artefact_kind

        primary_scope_id: Union[Unset, str] = UNSET
        if not isinstance(self.primary_scope_id, Unset):
            primary_scope_id = str(self.primary_scope_id)

        primary_scope_name = self.primary_scope_name

        primary_scope_type = self.primary_scope_type

        storage_node_id: Union[Unset, str] = UNSET
        if not isinstance(self.storage_node_id, Unset):
            storage_node_id = str(self.storage_node_id)

        storage_display_name = self.storage_display_name

        storage_node_type = self.storage_node_type

        last_event_type = self.last_event_type

        last_event_at = self.last_event_at


        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
        })
        if artefact_id is not UNSET:
            field_dict["artefact_id"] = artefact_id
        if name is not UNSET:
            field_dict["name"] = name
        if status is not UNSET:
            field_dict["status"] = status
        if is_virtual is not UNSET:
            field_dict["is_virtual"] = is_virtual
        if quantity is not UNSET:
            field_dict["quantity"] = quantity
        if quantity_unit is not UNSET:
            field_dict["quantity_unit"] = quantity_unit
        if type_key is not UNSET:
            field_dict["type_key"] = type_key
        if artefact_type is not UNSET:
            field_dict["artefact_type"] = artefact_type
        if artefact_kind is not UNSET:
            field_dict["artefact_kind"] = artefact_kind
        if primary_scope_id is not UNSET:
            field_dict["primary_scope_id"] = primary_scope_id
        if primary_scope_name is not UNSET:
            field_dict["primary_scope_name"] = primary_scope_name
        if primary_scope_type is not UNSET:
            field_dict["primary_scope_type"] = primary_scope_type
        if storage_node_id is not UNSET:
            field_dict["storage_node_id"] = storage_node_id
        if storage_display_name is not UNSET:
            field_dict["storage_display_name"] = storage_display_name
        if storage_node_type is not UNSET:
            field_dict["storage_node_type"] = storage_node_type
        if last_event_type is not UNSET:
            field_dict["last_event_type"] = last_event_type
        if last_event_at is not UNSET:
            field_dict["last_event_at"] = last_event_at

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        _artefact_id = d.pop("artefact_id", UNSET)
        artefact_id: Union[Unset, UUID]
        if isinstance(_artefact_id,  Unset):
            artefact_id = UNSET
        else:
            artefact_id = UUID(_artefact_id)




        name = d.pop("name", UNSET)

        status = d.pop("status", UNSET)

        is_virtual = d.pop("is_virtual", UNSET)

        quantity = d.pop("quantity", UNSET)

        quantity_unit = d.pop("quantity_unit", UNSET)

        type_key = d.pop("type_key", UNSET)

        artefact_type = d.pop("artefact_type", UNSET)

        artefact_kind = d.pop("artefact_kind", UNSET)

        _primary_scope_id = d.pop("primary_scope_id", UNSET)
        primary_scope_id: Union[Unset, UUID]
        if isinstance(_primary_scope_id,  Unset):
            primary_scope_id = UNSET
        else:
            primary_scope_id = UUID(_primary_scope_id)




        primary_scope_name = d.pop("primary_scope_name", UNSET)

        primary_scope_type = d.pop("primary_scope_type", UNSET)

        _storage_node_id = d.pop("storage_node_id", UNSET)
        storage_node_id: Union[Unset, UUID]
        if isinstance(_storage_node_id,  Unset):
            storage_node_id = UNSET
        else:
            storage_node_id = UUID(_storage_node_id)




        storage_display_name = d.pop("storage_display_name", UNSET)

        storage_node_type = d.pop("storage_node_type", UNSET)

        last_event_type = d.pop("last_event_type", UNSET)

        last_event_at = d.pop("last_event_at", UNSET)

        v_accessible_artefacts = cls(
            artefact_id=artefact_id,
            name=name,
            status=status,
            is_virtual=is_virtual,
            quantity=quantity,
            quantity_unit=quantity_unit,
            type_key=type_key,
            artefact_type=artefact_type,
            artefact_kind=artefact_kind,
            primary_scope_id=primary_scope_id,
            primary_scope_name=primary_scope_name,
            primary_scope_type=primary_scope_type,
            storage_node_id=storage_node_id,
            storage_display_name=storage_display_name,
            storage_node_type=storage_node_type,
            last_event_type=last_event_type,
            last_event_at=last_event_at,
        )


        v_accessible_artefacts.additional_properties = d
        return v_accessible_artefacts

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
