from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from ..types import UNSET, Unset
from typing import Union
from uuid import UUID






T = TypeVar("T", bound="VContainerContents")



@_attrs_define
class VContainerContents:
    """ 
        Attributes:
            container_artefact_id (Union[Unset, UUID]): Note:
                This is a Foreign Key to `artefacts.artefact_id`.<fk table='artefacts' column='artefact_id'/>
            container_name (Union[Unset, str]):
            container_status (Union[Unset, str]):
            container_slot_id (Union[Unset, UUID]): Note:
                This is a Primary Key.<pk/>
            slot_name (Union[Unset, str]):
            slot_display_name (Union[Unset, str]):
            position (Union[Unset, Any]):
            artefact_id (Union[Unset, UUID]): Note:
                This is a Primary Key.<pk/>
            artefact_name (Union[Unset, str]):
            artefact_status (Union[Unset, str]):
            quantity (Union[Unset, float]):
            quantity_unit (Union[Unset, str]):
            occupied_at (Union[Unset, str]):
            last_updated_at (Union[Unset, str]):
     """

    container_artefact_id: Union[Unset, UUID] = UNSET
    container_name: Union[Unset, str] = UNSET
    container_status: Union[Unset, str] = UNSET
    container_slot_id: Union[Unset, UUID] = UNSET
    slot_name: Union[Unset, str] = UNSET
    slot_display_name: Union[Unset, str] = UNSET
    position: Union[Unset, Any] = UNSET
    artefact_id: Union[Unset, UUID] = UNSET
    artefact_name: Union[Unset, str] = UNSET
    artefact_status: Union[Unset, str] = UNSET
    quantity: Union[Unset, float] = UNSET
    quantity_unit: Union[Unset, str] = UNSET
    occupied_at: Union[Unset, str] = UNSET
    last_updated_at: Union[Unset, str] = UNSET
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        container_artefact_id: Union[Unset, str] = UNSET
        if not isinstance(self.container_artefact_id, Unset):
            container_artefact_id = str(self.container_artefact_id)

        container_name = self.container_name

        container_status = self.container_status

        container_slot_id: Union[Unset, str] = UNSET
        if not isinstance(self.container_slot_id, Unset):
            container_slot_id = str(self.container_slot_id)

        slot_name = self.slot_name

        slot_display_name = self.slot_display_name

        position = self.position

        artefact_id: Union[Unset, str] = UNSET
        if not isinstance(self.artefact_id, Unset):
            artefact_id = str(self.artefact_id)

        artefact_name = self.artefact_name

        artefact_status = self.artefact_status

        quantity = self.quantity

        quantity_unit = self.quantity_unit

        occupied_at = self.occupied_at

        last_updated_at = self.last_updated_at


        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
        })
        if container_artefact_id is not UNSET:
            field_dict["container_artefact_id"] = container_artefact_id
        if container_name is not UNSET:
            field_dict["container_name"] = container_name
        if container_status is not UNSET:
            field_dict["container_status"] = container_status
        if container_slot_id is not UNSET:
            field_dict["container_slot_id"] = container_slot_id
        if slot_name is not UNSET:
            field_dict["slot_name"] = slot_name
        if slot_display_name is not UNSET:
            field_dict["slot_display_name"] = slot_display_name
        if position is not UNSET:
            field_dict["position"] = position
        if artefact_id is not UNSET:
            field_dict["artefact_id"] = artefact_id
        if artefact_name is not UNSET:
            field_dict["artefact_name"] = artefact_name
        if artefact_status is not UNSET:
            field_dict["artefact_status"] = artefact_status
        if quantity is not UNSET:
            field_dict["quantity"] = quantity
        if quantity_unit is not UNSET:
            field_dict["quantity_unit"] = quantity_unit
        if occupied_at is not UNSET:
            field_dict["occupied_at"] = occupied_at
        if last_updated_at is not UNSET:
            field_dict["last_updated_at"] = last_updated_at

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        _container_artefact_id = d.pop("container_artefact_id", UNSET)
        container_artefact_id: Union[Unset, UUID]
        if isinstance(_container_artefact_id,  Unset):
            container_artefact_id = UNSET
        else:
            container_artefact_id = UUID(_container_artefact_id)




        container_name = d.pop("container_name", UNSET)

        container_status = d.pop("container_status", UNSET)

        _container_slot_id = d.pop("container_slot_id", UNSET)
        container_slot_id: Union[Unset, UUID]
        if isinstance(_container_slot_id,  Unset):
            container_slot_id = UNSET
        else:
            container_slot_id = UUID(_container_slot_id)




        slot_name = d.pop("slot_name", UNSET)

        slot_display_name = d.pop("slot_display_name", UNSET)

        position = d.pop("position", UNSET)

        _artefact_id = d.pop("artefact_id", UNSET)
        artefact_id: Union[Unset, UUID]
        if isinstance(_artefact_id,  Unset):
            artefact_id = UNSET
        else:
            artefact_id = UUID(_artefact_id)




        artefact_name = d.pop("artefact_name", UNSET)

        artefact_status = d.pop("artefact_status", UNSET)

        quantity = d.pop("quantity", UNSET)

        quantity_unit = d.pop("quantity_unit", UNSET)

        occupied_at = d.pop("occupied_at", UNSET)

        last_updated_at = d.pop("last_updated_at", UNSET)

        v_container_contents = cls(
            container_artefact_id=container_artefact_id,
            container_name=container_name,
            container_status=container_status,
            container_slot_id=container_slot_id,
            slot_name=slot_name,
            slot_display_name=slot_display_name,
            position=position,
            artefact_id=artefact_id,
            artefact_name=artefact_name,
            artefact_status=artefact_status,
            quantity=quantity,
            quantity_unit=quantity_unit,
            occupied_at=occupied_at,
            last_updated_at=last_updated_at,
        )


        v_container_contents.additional_properties = d
        return v_container_contents

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
