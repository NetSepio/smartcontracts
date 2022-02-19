import {

  ReviewCreated,
  ReviewDeleted,
  ReviewUpdated,
  RoleGranted,
  RoleRevoked,

} from "../generated/NetSepio/NetSepio"
import { Review, User } from "../generated/schema"

export function handleReviewCreated(event: ReviewCreated): void {
  let user = User.load(event.params.receiver.toHexString())
  if (!user) {
    user = new User(event.params.receiver.toHexString());
    user.save()
  }
  const review = new Review(event.params.tokenId.toString())
  review.category = event.params.category;
  review.domainAddress = event.params.domainAddress;
  review.siteURL = event.params.siteURL;
  review.siteType = event.params.siteType;
  review.siteTag = event.params.siteTag;
  review.siteSafety = event.params.category;
  review.metaDataUri = event.params.metadataURI;
  review.reviewBy = event.params.receiver.toHexString();
  review.deleted = false;
  review.infoHash = ""
  review.save()
}

export function handleReviewDeleted(event: ReviewDeleted): void {
  const review = Review.load(event.params.tokenId.toString())
  if (review) {
    review.deleted = true
    review.save()
  }
}

export function handleReviewUpdated(event: ReviewUpdated): void {
  const review = Review.load(event.params.tokenId.toString())
  if (review) {
    review.infoHash = event.params.newInfoHash
    review.save()
  }
}


export function handleRoleGranted(event: RoleGranted): void {
  let user = User.load(event.params.account.toHexString());
  if (!user) {
    user = new User(event.params.account.toHexString());
  }
  let userHasRole = user.roles.includes(event.params.role.toHexString())
  if (!userHasRole) {
    let updatedRoles = user.roles
    updatedRoles.push(event.params.role.toHexString())
    user.roles = updatedRoles
  }
  user.save();
}

export function handleRoleRevoked(event: RoleRevoked): void {
  let user = User.load(event.params.account.toHexString());
  if (!user) {
    user = new User(event.params.account.toHexString());
  }

  let idx = user.roles.indexOf(event.params.role.toHexString())
  if (idx >= 0) {
    let updatedRoles = user.roles;
    updatedRoles.splice(idx, 1)
    user.roles = updatedRoles
    user.save();
  }
}