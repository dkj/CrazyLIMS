from collections.abc import Mapping
from typing import Any, TypeVar, Optional, BinaryIO, TextIO, TYPE_CHECKING, Generator

from attrs import define as _attrs_define
from attrs import field as _attrs_field

from ..types import UNSET, Unset

from ..types import UNSET, Unset
from typing import cast
from typing import Union
from uuid import UUID






T = TypeVar("T", bound="VScopeTransferOverview")



@_attrs_define
class VScopeTransferOverview:
    """ Generalised scope-to-scope transfer overview including scope metadata and allowed roles.

        Attributes:
            source_artefact_id (Union[Unset, UUID]): Note:
                This is a Foreign Key to `v_inventory_status.id`.<fk table='v_inventory_status' column='id'/>
            source_artefact_name (Union[Unset, str]):
            source_scopes (Union[Unset, Any]):
            target_artefact_id (Union[Unset, UUID]): Note:
                This is a Foreign Key to `v_inventory_status.id`.<fk table='v_inventory_status' column='id'/>
            target_artefact_name (Union[Unset, str]):
            target_scopes (Union[Unset, Any]):
            source_transfer_state (Union[Unset, str]):
            target_transfer_state (Union[Unset, str]):
            propagation_whitelist (Union[Unset, list[str]]):
            allowed_roles (Union[Unset, list[str]]):
            relationship_type (Union[Unset, str]):
            handover_at (Union[Unset, str]):
            returned_at (Union[Unset, str]):
            handover_by (Union[Unset, UUID]):
            returned_by (Union[Unset, UUID]):
            relationship_metadata (Union[Unset, Any]):
     """

    source_artefact_id: Union[Unset, UUID] = UNSET
    source_artefact_name: Union[Unset, str] = UNSET
    source_scopes: Union[Unset, Any] = UNSET
    target_artefact_id: Union[Unset, UUID] = UNSET
    target_artefact_name: Union[Unset, str] = UNSET
    target_scopes: Union[Unset, Any] = UNSET
    source_transfer_state: Union[Unset, str] = UNSET
    target_transfer_state: Union[Unset, str] = UNSET
    propagation_whitelist: Union[Unset, list[str]] = UNSET
    allowed_roles: Union[Unset, list[str]] = UNSET
    relationship_type: Union[Unset, str] = UNSET
    handover_at: Union[Unset, str] = UNSET
    returned_at: Union[Unset, str] = UNSET
    handover_by: Union[Unset, UUID] = UNSET
    returned_by: Union[Unset, UUID] = UNSET
    relationship_metadata: Union[Unset, Any] = UNSET
    additional_properties: dict[str, Any] = _attrs_field(init=False, factory=dict)





    def to_dict(self) -> dict[str, Any]:
        source_artefact_id: Union[Unset, str] = UNSET
        if not isinstance(self.source_artefact_id, Unset):
            source_artefact_id = str(self.source_artefact_id)

        source_artefact_name = self.source_artefact_name

        source_scopes = self.source_scopes

        target_artefact_id: Union[Unset, str] = UNSET
        if not isinstance(self.target_artefact_id, Unset):
            target_artefact_id = str(self.target_artefact_id)

        target_artefact_name = self.target_artefact_name

        target_scopes = self.target_scopes

        source_transfer_state = self.source_transfer_state

        target_transfer_state = self.target_transfer_state

        propagation_whitelist: Union[Unset, list[str]] = UNSET
        if not isinstance(self.propagation_whitelist, Unset):
            propagation_whitelist = self.propagation_whitelist



        allowed_roles: Union[Unset, list[str]] = UNSET
        if not isinstance(self.allowed_roles, Unset):
            allowed_roles = self.allowed_roles



        relationship_type = self.relationship_type

        handover_at = self.handover_at

        returned_at = self.returned_at

        handover_by: Union[Unset, str] = UNSET
        if not isinstance(self.handover_by, Unset):
            handover_by = str(self.handover_by)

        returned_by: Union[Unset, str] = UNSET
        if not isinstance(self.returned_by, Unset):
            returned_by = str(self.returned_by)

        relationship_metadata = self.relationship_metadata


        field_dict: dict[str, Any] = {}
        field_dict.update(self.additional_properties)
        field_dict.update({
        })
        if source_artefact_id is not UNSET:
            field_dict["source_artefact_id"] = source_artefact_id
        if source_artefact_name is not UNSET:
            field_dict["source_artefact_name"] = source_artefact_name
        if source_scopes is not UNSET:
            field_dict["source_scopes"] = source_scopes
        if target_artefact_id is not UNSET:
            field_dict["target_artefact_id"] = target_artefact_id
        if target_artefact_name is not UNSET:
            field_dict["target_artefact_name"] = target_artefact_name
        if target_scopes is not UNSET:
            field_dict["target_scopes"] = target_scopes
        if source_transfer_state is not UNSET:
            field_dict["source_transfer_state"] = source_transfer_state
        if target_transfer_state is not UNSET:
            field_dict["target_transfer_state"] = target_transfer_state
        if propagation_whitelist is not UNSET:
            field_dict["propagation_whitelist"] = propagation_whitelist
        if allowed_roles is not UNSET:
            field_dict["allowed_roles"] = allowed_roles
        if relationship_type is not UNSET:
            field_dict["relationship_type"] = relationship_type
        if handover_at is not UNSET:
            field_dict["handover_at"] = handover_at
        if returned_at is not UNSET:
            field_dict["returned_at"] = returned_at
        if handover_by is not UNSET:
            field_dict["handover_by"] = handover_by
        if returned_by is not UNSET:
            field_dict["returned_by"] = returned_by
        if relationship_metadata is not UNSET:
            field_dict["relationship_metadata"] = relationship_metadata

        return field_dict



    @classmethod
    def from_dict(cls: type[T], src_dict: Mapping[str, Any]) -> T:
        d = dict(src_dict)
        _source_artefact_id = d.pop("source_artefact_id", UNSET)
        source_artefact_id: Union[Unset, UUID]
        if isinstance(_source_artefact_id,  Unset):
            source_artefact_id = UNSET
        else:
            source_artefact_id = UUID(_source_artefact_id)




        source_artefact_name = d.pop("source_artefact_name", UNSET)

        source_scopes = d.pop("source_scopes", UNSET)

        _target_artefact_id = d.pop("target_artefact_id", UNSET)
        target_artefact_id: Union[Unset, UUID]
        if isinstance(_target_artefact_id,  Unset):
            target_artefact_id = UNSET
        else:
            target_artefact_id = UUID(_target_artefact_id)




        target_artefact_name = d.pop("target_artefact_name", UNSET)

        target_scopes = d.pop("target_scopes", UNSET)

        source_transfer_state = d.pop("source_transfer_state", UNSET)

        target_transfer_state = d.pop("target_transfer_state", UNSET)

        propagation_whitelist = cast(list[str], d.pop("propagation_whitelist", UNSET))


        allowed_roles = cast(list[str], d.pop("allowed_roles", UNSET))


        relationship_type = d.pop("relationship_type", UNSET)

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




        relationship_metadata = d.pop("relationship_metadata", UNSET)

        v_scope_transfer_overview = cls(
            source_artefact_id=source_artefact_id,
            source_artefact_name=source_artefact_name,
            source_scopes=source_scopes,
            target_artefact_id=target_artefact_id,
            target_artefact_name=target_artefact_name,
            target_scopes=target_scopes,
            source_transfer_state=source_transfer_state,
            target_transfer_state=target_transfer_state,
            propagation_whitelist=propagation_whitelist,
            allowed_roles=allowed_roles,
            relationship_type=relationship_type,
            handover_at=handover_at,
            returned_at=returned_at,
            handover_by=handover_by,
            returned_by=returned_by,
            relationship_metadata=relationship_metadata,
        )


        v_scope_transfer_overview.additional_properties = d
        return v_scope_transfer_overview

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
