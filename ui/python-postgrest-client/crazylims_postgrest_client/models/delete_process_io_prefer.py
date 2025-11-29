from enum import Enum

class DeleteProcessIoPrefer(str, Enum):
    RETURNMINIMAL = "return=minimal"
    RETURNNONE = "return=none"
    RETURNREPRESENTATION = "return=representation"

    def __str__(self) -> str:
        return str(self.value)
