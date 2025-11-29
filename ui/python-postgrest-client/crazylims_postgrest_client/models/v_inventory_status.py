from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from ..types import UNSET, Unset
from typing import Union
from uuid import UUID






T = TypeVar("T", bound="VInventoryStatus")



@_attrs_define
class VInventoryStatus:
    """ 
        Attributes:
            id (Union[Unset, UUID]): Note:
                This is a Primary Key.<pk/>
            name (Union[Unset, str]):
            barcode (Union[Unset, str]):
            quantity (Union[Unset, float]):
            unit (Union[Unset, str]):
            minimum_quantity (Union[Unset, float]):
            below_threshold (Union[Unset, bool]):
            expires_at (Union[Unset, str]):
            storage_sublocation_id (Union[Unset, UUID]): Note:
                This is a Foreign Key to `v_inventory_status.id`.<fk table='v_inventory_status' column='id'/>
            storage_path (Union[Unset, str]):
     """

    id: Union[Unset, UUID] = UNSET
    name: Union[Unset, str] = UNSET
    barcode: Union[Unset, str] = UNSET
    quantity: Union[Unset, float] = UNSET
    unit: Union[Unset, str] = UNSET
    minimum_quantity: Union[Unset, float] = UNSET
    below_threshold: Union[Unset, bool] = UNSET
    expires_at: Union[Unset, str] = UNSET
    storage_sublocation_id: Union[Unset, UUID] = UNSET
    storage_path: Union[Unset, str] = UNSET
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        id: Union[Unset, str] = UNSET
        if not isinstance(self.id, Unset):
            id = str(self.id)

        name = self.name

        barcode = self.barcode

        quantity = self.quantity

        unit = self.unit

        minimum_quantity = self.minimum_quantity

        below_threshold = self.below_threshold

        expires_at = self.expires_at

        storage_sublocation_id: Union[Unset, str] = UNSET
        if not isinstance(self.storage_sublocation_id, Unset):
            storage_sublocation_id = str(self.storage_sublocation_id)

        storage_path = self.storage_path


        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
        })
        if id is not UNSET:
            field_dict["id"] = id
        if name is not UNSET:
            field_dict["name"] = name
        if barcode is not UNSET:
            field_dict["barcode"] = barcode
        if quantity is not UNSET:
            field_dict["quantity"] = quantity
        if unit is not UNSET:
            field_dict["unit"] = unit
        if minimum_quantity is not UNSET:
            field_dict["minimum_quantity"] = minimum_quantity
        if below_threshold is not UNSET:
            field_dict["below_threshold"] = below_threshold
        if expires_at is not UNSET:
            field_dict["expires_at"] = expires_at
        if storage_sublocation_id is not UNSET:
            field_dict["storage_sublocation_id"] = storage_sublocation_id
        if storage_path is not UNSET:
            field_dict["storage_path"] = storage_path

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        _id = d.pop("id", UNSET)
        id: Union[Unset, UUID]
        if isinstance(_id,  Unset):
            id = UNSET
        else:
            id = UUID(_id)




        name = d.pop("name", UNSET)

        barcode = d.pop("barcode", UNSET)

        quantity = d.pop("quantity", UNSET)

        unit = d.pop("unit", UNSET)

        minimum_quantity = d.pop("minimum_quantity", UNSET)

        below_threshold = d.pop("below_threshold", UNSET)

        expires_at = d.pop("expires_at", UNSET)

        _storage_sublocation_id = d.pop("storage_sublocation_id", UNSET)
        storage_sublocation_id: Union[Unset, UUID]
        if isinstance(_storage_sublocation_id,  Unset):
            storage_sublocation_id = UNSET
        else:
            storage_sublocation_id = UUID(_storage_sublocation_id)




        storage_path = d.pop("storage_path", UNSET)

        v_inventory_status = cls(
            id=id,
            name=name,
            barcode=barcode,
            quantity=quantity,
            unit=unit,
            minimum_quantity=minimum_quantity,
            below_threshold=below_threshold,
            expires_at=expires_at,
            storage_sublocation_id=storage_sublocation_id,
            storage_path=storage_path,
        )


        v_inventory_status.additional_properties = d
        return v_inventory_status

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
