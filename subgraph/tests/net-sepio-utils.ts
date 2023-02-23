import { newMockEvent } from "matchstick-as"
import { ethereum, Address, BigInt, Bytes } from "@graphprotocol/graph-ts"
import {
  Approval,
  ApprovalForAll,
  Paused,
  ReviewCreated,
  ReviewDeleted,
  ReviewUpdated,
  RoleAdminChanged,
  RoleGranted,
  RoleRevoked,
  Transfer,
  Unpaused
} from "../generated/NetSepio/NetSepio"

export function createApprovalEvent(
  owner: Address,
  approved: Address,
  tokenId: BigInt
): Approval {
  let approvalEvent = changetype<Approval>(newMockEvent())

  approvalEvent.parameters = new Array()

  approvalEvent.parameters.push(
    new ethereum.EventParam("owner", ethereum.Value.fromAddress(owner))
  )
  approvalEvent.parameters.push(
    new ethereum.EventParam("approved", ethereum.Value.fromAddress(approved))
  )
  approvalEvent.parameters.push(
    new ethereum.EventParam(
      "tokenId",
      ethereum.Value.fromUnsignedBigInt(tokenId)
    )
  )

  return approvalEvent
}

export function createApprovalForAllEvent(
  owner: Address,
  operator: Address,
  approved: boolean
): ApprovalForAll {
  let approvalForAllEvent = changetype<ApprovalForAll>(newMockEvent())

  approvalForAllEvent.parameters = new Array()

  approvalForAllEvent.parameters.push(
    new ethereum.EventParam("owner", ethereum.Value.fromAddress(owner))
  )
  approvalForAllEvent.parameters.push(
    new ethereum.EventParam("operator", ethereum.Value.fromAddress(operator))
  )
  approvalForAllEvent.parameters.push(
    new ethereum.EventParam("approved", ethereum.Value.fromBoolean(approved))
  )

  return approvalForAllEvent
}

export function createPausedEvent(account: Address): Paused {
  let pausedEvent = changetype<Paused>(newMockEvent())

  pausedEvent.parameters = new Array()

  pausedEvent.parameters.push(
    new ethereum.EventParam("account", ethereum.Value.fromAddress(account))
  )

  return pausedEvent
}

export function createReviewCreatedEvent(
  receiver: Address,
  tokenId: BigInt,
  category: string,
  domainAddress: string,
  siteURL: string,
  siteType: string,
  siteTag: string,
  siteSafety: string,
  metadataURI: string
): ReviewCreated {
  let reviewCreatedEvent = changetype<ReviewCreated>(newMockEvent())

  reviewCreatedEvent.parameters = new Array()

  reviewCreatedEvent.parameters.push(
    new ethereum.EventParam("receiver", ethereum.Value.fromAddress(receiver))
  )
  reviewCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "tokenId",
      ethereum.Value.fromUnsignedBigInt(tokenId)
    )
  )
  reviewCreatedEvent.parameters.push(
    new ethereum.EventParam("category", ethereum.Value.fromString(category))
  )
  reviewCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "domainAddress",
      ethereum.Value.fromString(domainAddress)
    )
  )
  reviewCreatedEvent.parameters.push(
    new ethereum.EventParam("siteURL", ethereum.Value.fromString(siteURL))
  )
  reviewCreatedEvent.parameters.push(
    new ethereum.EventParam("siteType", ethereum.Value.fromString(siteType))
  )
  reviewCreatedEvent.parameters.push(
    new ethereum.EventParam("siteTag", ethereum.Value.fromString(siteTag))
  )
  reviewCreatedEvent.parameters.push(
    new ethereum.EventParam("siteSafety", ethereum.Value.fromString(siteSafety))
  )
  reviewCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "metadataURI",
      ethereum.Value.fromString(metadataURI)
    )
  )

  return reviewCreatedEvent
}

export function createReviewDeletedEvent(
  ownerOrApproved: Address,
  tokenId: BigInt
): ReviewDeleted {
  let reviewDeletedEvent = changetype<ReviewDeleted>(newMockEvent())

  reviewDeletedEvent.parameters = new Array()

  reviewDeletedEvent.parameters.push(
    new ethereum.EventParam(
      "ownerOrApproved",
      ethereum.Value.fromAddress(ownerOrApproved)
    )
  )
  reviewDeletedEvent.parameters.push(
    new ethereum.EventParam(
      "tokenId",
      ethereum.Value.fromUnsignedBigInt(tokenId)
    )
  )

  return reviewDeletedEvent
}

export function createReviewUpdatedEvent(
  ownerOrApproved: Address,
  tokenId: BigInt,
  oldInfoHash: string,
  newInfoHash: string
): ReviewUpdated {
  let reviewUpdatedEvent = changetype<ReviewUpdated>(newMockEvent())

  reviewUpdatedEvent.parameters = new Array()

  reviewUpdatedEvent.parameters.push(
    new ethereum.EventParam(
      "ownerOrApproved",
      ethereum.Value.fromAddress(ownerOrApproved)
    )
  )
  reviewUpdatedEvent.parameters.push(
    new ethereum.EventParam(
      "tokenId",
      ethereum.Value.fromUnsignedBigInt(tokenId)
    )
  )
  reviewUpdatedEvent.parameters.push(
    new ethereum.EventParam(
      "oldInfoHash",
      ethereum.Value.fromString(oldInfoHash)
    )
  )
  reviewUpdatedEvent.parameters.push(
    new ethereum.EventParam(
      "newInfoHash",
      ethereum.Value.fromString(newInfoHash)
    )
  )

  return reviewUpdatedEvent
}

export function createRoleAdminChangedEvent(
  role: Bytes,
  previousAdminRole: Bytes,
  newAdminRole: Bytes
): RoleAdminChanged {
  let roleAdminChangedEvent = changetype<RoleAdminChanged>(newMockEvent())

  roleAdminChangedEvent.parameters = new Array()

  roleAdminChangedEvent.parameters.push(
    new ethereum.EventParam("role", ethereum.Value.fromFixedBytes(role))
  )
  roleAdminChangedEvent.parameters.push(
    new ethereum.EventParam(
      "previousAdminRole",
      ethereum.Value.fromFixedBytes(previousAdminRole)
    )
  )
  roleAdminChangedEvent.parameters.push(
    new ethereum.EventParam(
      "newAdminRole",
      ethereum.Value.fromFixedBytes(newAdminRole)
    )
  )

  return roleAdminChangedEvent
}

export function createRoleGrantedEvent(
  role: Bytes,
  account: Address,
  sender: Address
): RoleGranted {
  let roleGrantedEvent = changetype<RoleGranted>(newMockEvent())

  roleGrantedEvent.parameters = new Array()

  roleGrantedEvent.parameters.push(
    new ethereum.EventParam("role", ethereum.Value.fromFixedBytes(role))
  )
  roleGrantedEvent.parameters.push(
    new ethereum.EventParam("account", ethereum.Value.fromAddress(account))
  )
  roleGrantedEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )

  return roleGrantedEvent
}

export function createRoleRevokedEvent(
  role: Bytes,
  account: Address,
  sender: Address
): RoleRevoked {
  let roleRevokedEvent = changetype<RoleRevoked>(newMockEvent())

  roleRevokedEvent.parameters = new Array()

  roleRevokedEvent.parameters.push(
    new ethereum.EventParam("role", ethereum.Value.fromFixedBytes(role))
  )
  roleRevokedEvent.parameters.push(
    new ethereum.EventParam("account", ethereum.Value.fromAddress(account))
  )
  roleRevokedEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )

  return roleRevokedEvent
}

export function createTransferEvent(
  from: Address,
  to: Address,
  tokenId: BigInt
): Transfer {
  let transferEvent = changetype<Transfer>(newMockEvent())

  transferEvent.parameters = new Array()

  transferEvent.parameters.push(
    new ethereum.EventParam("from", ethereum.Value.fromAddress(from))
  )
  transferEvent.parameters.push(
    new ethereum.EventParam("to", ethereum.Value.fromAddress(to))
  )
  transferEvent.parameters.push(
    new ethereum.EventParam(
      "tokenId",
      ethereum.Value.fromUnsignedBigInt(tokenId)
    )
  )

  return transferEvent
}

export function createUnpausedEvent(account: Address): Unpaused {
  let unpausedEvent = changetype<Unpaused>(newMockEvent())

  unpausedEvent.parameters = new Array()

  unpausedEvent.parameters.push(
    new ethereum.EventParam("account", ethereum.Value.fromAddress(account))
  )

  return unpausedEvent
}
