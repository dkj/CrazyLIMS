from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from ..types import UNSET, Unset
from typing import cast
from typing import Union
from uuid import UUID






T = TypeVar("T", bound="VHandoverOverview")



@_attrs_define
class VHandoverOverview:
    """ Summarises handover duplicates, scope memberships, transfer state, and propagation metadata for UI consumption.

        Attributes:
            research_artefact_id (Union[Unset, UUID]): Note:
                This is a Foreign Key to `v_inventory_status.id`.<fk table='v_inventory_status' column='id'/>
            research_artefact_name (Union[Unset, str]):
            research_scope_keys (Union[Unset, list[str]]):
            ops_artefact_id (Union[Unset, UUID]): Note:
                This is a Foreign Key to `v_inventory_status.id`.<fk table='v_inventory_status' column='id'/>
            ops_artefact_name (Union[Unset, str]):
            ops_scope_keys (Union[Unset, list[str]]):
            research_transfer_state (Union[Unset, str]):
            ops_transfer_state (Union[Unset, str]):
            propagation_whitelist (Union[Unset, list[str]]):
            handover_at (Union[Unset, str]):
            returned_at (Union[Unset, str]):
            handover_by (Union[Unset, UUID]):
            returned_by (Union[Unset, UUID]):
     """

    research_artefact_id: Union[Unset, UUID] = UNSET
    research_artefact_name: Union[Unset, str] = UNSET
    research_scope_keys: Union[Unset, list[str]] = UNSET
    ops_artefact_id: Union[Unset, UUID] = UNSET
    ops_artefact_name: Union[Unset, str] = UNSET
    ops_scope_keys: Union[Unset, list[str]] = UNSET
    research_transfer_state: Union[Unset, str] = UNSET
    ops_transfer_state: Union[Unset, str] = UNSET
    propagation_whitelist: Union[Unset, list[str]] = UNSET
    handover_at: Union[Unset, str] = UNSET
    returned_at: Union[Unset, str] = UNSET
    handover_by: Union[Unset, UUID] = UNSET
    returned_by: Union[Unset, UUID] = UNSET
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        research_artefact_id: Union[Unset, str] = UNSET
        if not isinstance(self.research_artefact_id, Unset):
            research_artefact_id = str(self.research_artefact_id)

        research_artefact_name = self.research_artefact_name

        research_scope_keys: Union[Unset, list[str]] = UNSET
        if not isinstance(self.research_scope_keys, Unset):
            research_scope_keys = self.research_scope_keys



        ops_artefact_id: Union[Unset, str] = UNSET
        if not isinstance(self.ops_artefact_id, Unset):
            ops_artefact_id = str(self.ops_artefact_id)

        ops_artefact_name = self.ops_artefact_name

        ops_scope_keys: Union[Unset, list[str]] = UNSET
        if not isinstance(self.ops_scope_keys, Unset):
            ops_scope_keys = self.ops_scope_keys



        research_transfer_state = self.research_transfer_state

        ops_transfer_state = self.ops_transfer_state

        propagation_whitelist: Union[Unset, list[str]] = UNSET
        if not isinstance(self.propagation_whitelist, Unset):
            propagation_whitelist = self.propagation_whitelist



        handover_at = self.handover_at

        returned_at = self.returned_at

        handover_by: Union[Unset, str] = UNSET
        if not isinstance(self.handover_by, Unset):
            handover_by = str(self.handover_by)

        returned_by: Union[Unset, str] = UNSET
        if not isinstance(self.returned_by, Unset):
            returned_by = str(self.returned_by)


        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
        })
        if research_artefact_id is not UNSET:
            field_dict["research_artefact_id"] = research_artefact_id
        if research_artefact_name is not UNSET:
            field_dict["research_artefact_name"] = research_artefact_name
        if research_scope_keys is not UNSET:
            field_dict["research_scope_keys"] = research_scope_keys
        if ops_artefact_id is not UNSET:
            field_dict["ops_artefact_id"] = ops_artefact_id
        if ops_artefact_name is not UNSET:
            field_dict["ops_artefact_name"] = ops_artefact_name
        if ops_scope_keys is not UNSET:
            field_dict["ops_scope_keys"] = ops_scope_keys
        if research_transfer_state is not UNSET:
            field_dict["research_transfer_state"] = research_transfer_state
        if ops_transfer_state is not UNSET:
            field_dict["ops_transfer_state"] = ops_transfer_state
        if propagation_whitelist is not UNSET:
            field_dict["propagation_whitelist"] = propagation_whitelist
        if handover_at is not UNSET:
            field_dict["handover_at"] = handover_at
        if returned_at is not UNSET:
            field_dict["returned_at"] = returned_at
        if handover_by is not UNSET:
            field_dict["handover_by"] = handover_by
        if returned_by is not UNSET:
            field_dict["returned_by"] = returned_by

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        _research_artefact_id = d.pop("research_artefact_id", UNSET)
        research_artefact_id: Union[Unset, UUID]
        if isinstance(_research_artefact_id,  Unset):
            research_artefact_id = UNSET
        else:
            research_artefact_id = UUID(_research_artefact_id)




        research_artefact_name = d.pop("research_artefact_name", UNSET)

        research_scope_keys = cast(list[str], d.pop("research_scope_keys", UNSET))


        _ops_artefact_id = d.pop("ops_artefact_id", UNSET)
        ops_artefact_id: Union[Unset, UUID]
        if isinstance(_ops_artefact_id,  Unset):
            ops_artefact_id = UNSET
        else:
            ops_artefact_id = UUID(_ops_artefact_id)




        ops_artefact_name = d.pop("ops_artefact_name", UNSET)

        ops_scope_keys = cast(list[str], d.pop("ops_scope_keys", UNSET))


        research_transfer_state = d.pop("research_transfer_state", UNSET)

        ops_transfer_state = d.pop("ops_transfer_state", UNSET)

        propagation_whitelist = cast(list[str], d.pop("propagation_whitelist", UNSET))


        handover_at = d.pop("handover_at", UNSET)

        returned_at = d.pop("returned_at", UNSET)

        _handover_by = d.pop("handover_by", UNSET)
        handover_by: Union[Unset, UUID]
        if isinstance(_handover_by,  Unset):
            handover_by = UNSET
        else:
            handover_by = UUID(_handover_by)




        _returned_by = d.pop("returned_by", UNSET)
        returned_by: Union[Unset, UUID]
        if isinstance(_returned_by,  Unset):
            returned_by = UNSET
        else:
            returned_by = UUID(_returned_by)




        v_handover_overview = cls(
            research_artefact_id=research_artefact_id,
            research_artefact_name=research_artefact_name,
            research_scope_keys=research_scope_keys,
            ops_artefact_id=ops_artefact_id,
            ops_artefact_name=ops_artefact_name,
            ops_scope_keys=ops_scope_keys,
            research_transfer_state=research_transfer_state,
            ops_transfer_state=ops_transfer_state,
            propagation_whitelist=propagation_whitelist,
            handover_at=handover_at,
            returned_at=returned_at,
            handover_by=handover_by,
            returned_by=returned_by,
        )


        v_handover_overview.additional_properties = d
        return v_handover_overview

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
