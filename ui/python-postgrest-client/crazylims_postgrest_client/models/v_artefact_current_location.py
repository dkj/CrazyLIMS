from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from ..types import UNSET, Unset
from typing import Union
from uuid import UUID






T = TypeVar("T", bound="VArtefactCurrentLocation")



@_attrs_define
class VArtefactCurrentLocation:
    """ 
        Attributes:
            artefact_id (Union[Unset, UUID]): Note:
                This is a Foreign Key to `artefacts.artefact_id`.<fk table='artefacts' column='artefact_id'/>
            storage_node_id (Union[Unset, UUID]): Note:
                This is a Foreign Key to `artefacts.artefact_id`.<fk table='artefacts' column='artefact_id'/>
            storage_display_name (Union[Unset, str]):
            node_type (Union[Unset, str]):
            scope_id (Union[Unset, UUID]):
            environment (Union[Unset, Any]):
            last_event_type (Union[Unset, str]):
            last_event_at (Union[Unset, str]):
     """

    artefact_id: Union[Unset, UUID] = UNSET
    storage_node_id: Union[Unset, UUID] = UNSET
    storage_display_name: Union[Unset, str] = UNSET
    node_type: Union[Unset, str] = UNSET
    scope_id: Union[Unset, UUID] = UNSET
    environment: Union[Unset, Any] = UNSET
    last_event_type: Union[Unset, str] = UNSET
    last_event_at: Union[Unset, str] = UNSET
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        artefact_id: Union[Unset, str] = UNSET
        if not isinstance(self.artefact_id, Unset):
            artefact_id = str(self.artefact_id)

        storage_node_id: Union[Unset, str] = UNSET
        if not isinstance(self.storage_node_id, Unset):
            storage_node_id = str(self.storage_node_id)

        storage_display_name = self.storage_display_name

        node_type = self.node_type

        scope_id: Union[Unset, str] = UNSET
        if not isinstance(self.scope_id, Unset):
            scope_id = str(self.scope_id)

        environment = self.environment

        last_event_type = self.last_event_type

        last_event_at = self.last_event_at


        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
        })
        if artefact_id is not UNSET:
            field_dict["artefact_id"] = artefact_id
        if storage_node_id is not UNSET:
            field_dict["storage_node_id"] = storage_node_id
        if storage_display_name is not UNSET:
            field_dict["storage_display_name"] = storage_display_name
        if node_type is not UNSET:
            field_dict["node_type"] = node_type
        if scope_id is not UNSET:
            field_dict["scope_id"] = scope_id
        if environment is not UNSET:
            field_dict["environment"] = environment
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




        _storage_node_id = d.pop("storage_node_id", UNSET)
        storage_node_id: Union[Unset, UUID]
        if isinstance(_storage_node_id,  Unset):
            storage_node_id = UNSET
        else:
            storage_node_id = UUID(_storage_node_id)




        storage_display_name = d.pop("storage_display_name", UNSET)

        node_type = d.pop("node_type", UNSET)

        _scope_id = d.pop("scope_id", UNSET)
        scope_id: Union[Unset, UUID]
        if isinstance(_scope_id,  Unset):
            scope_id = UNSET
        else:
            scope_id = UUID(_scope_id)




        environment = d.pop("environment", UNSET)

        last_event_type = d.pop("last_event_type", UNSET)

        last_event_at = d.pop("last_event_at", UNSET)

        v_artefact_current_location = cls(
            artefact_id=artefact_id,
            storage_node_id=storage_node_id,
            storage_display_name=storage_display_name,
            node_type=node_type,
            scope_id=scope_id,
            environment=environment,
            last_event_type=last_event_type,
            last_event_at=last_event_at,
        )


        v_artefact_current_location.additional_properties = d
        return v_artefact_current_location

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
