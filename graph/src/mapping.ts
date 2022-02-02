import {

  ReviewCreated,
  ReviewDeleted,
  ReviewUpdated,

} from "../generated/NetSepio/NetSepio"
import { Review } from "../generated/schema"

export function handleReviewCreated(event: ReviewCreated): void {
  const review = new Review(event.params.tokenId.toString())
  review.category = event.params.category;
  review.domainAddress = event.params.domainAddress;
  review.siteURL = event.params.siteURL;
  review.siteType = event.params.siteType;
  review.siteTag = event.params.siteTag;
  review.siteSafety = event.params.category;
  review.metaDataUri = event.params.metadataURI;
  review.reviewBy = event.params.receiver;
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




