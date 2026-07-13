from enum import Enum

from zero_lab.models import ActionProposal, Actor, PermissionLevel


class PolicyDecision(str, Enum):
    ALLOW = "ALLOW"
    SHADOW = "SHADOW"
    BLOCK = "BLOCK"


ACTION_MINIMUM_PERMISSION = {
    "public_read": PermissionLevel.L0,
    "repository_write": PermissionLevel.L1,
    "code_change": PermissionLevel.L1,
    "public_post": PermissionLevel.L2,
    "deployment": PermissionLevel.L2,
    "create_account": PermissionLevel.L3,
}


def decide(proposal: ActionProposal, capability_stage: int) -> PolicyDecision:
    minimum = ACTION_MINIMUM_PERMISSION.get(proposal.action_type)
    if minimum is None or proposal.permission < minimum:
        return PolicyDecision.BLOCK
    if proposal.permission == PermissionLevel.L3:
        return PolicyDecision.BLOCK
    if proposal.actor == Actor.ZERO and proposal.payload.get("identity") == "499244188":
        return PolicyDecision.BLOCK
    if proposal.permission == PermissionLevel.L2:
        return (
            PolicyDecision.ALLOW
            if capability_stage >= 3
            else PolicyDecision.SHADOW
        )
    if proposal.permission == PermissionLevel.L1:
        return (
            PolicyDecision.ALLOW
            if capability_stage >= 2
            else PolicyDecision.SHADOW
        )
    return PolicyDecision.ALLOW
