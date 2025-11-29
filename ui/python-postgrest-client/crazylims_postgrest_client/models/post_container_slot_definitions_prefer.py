from enum import Enum

class PostContainerSlotDefinitionsPrefer(str, Enum):
    RESOLUTIONIGNORE_DUPLICATES = "resolution=ignore-duplicates"
    RESOLUTIONMERGE_DUPLICATES = "resolution=merge-duplicates"
    RETURNMINIMAL = "return=minimal"
    RETURNNONE = "return=none"
    RETURNREPRESENTATION = "return=representation"

    def __str__(self) -> str:
        return str(self.value)
