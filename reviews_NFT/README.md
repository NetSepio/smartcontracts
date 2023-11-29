# Reviews_NFT
Smart Contract for the NetSepio Reviews for Aptos Blockchain

_Currently deployed on:_ 

Entry Functions:
- grant_role
- remove_role
- submit_review
- delegate_submit_review
- delete_review
- archive_link

View Functions:
- check_if_metadata_exists
- check_role
- total_dapps_reviewed
- total_reviews

Events:
- RoleGrantedEvent
- RoleRemovedEvent
- ArchiveLinkEvent
- ReviewSubmittedEvent
- ReviewDeletedEvent

## Revisions:
### 1.0.2:
- Deployed to testnet under contract address: 08256c1924e4234c5e5391149a1691bc03eaefeaf059e26a51f8679d4bc109cb
- renamed "total_dapps_reviewed" -> "total_sites_reviewed"
- added "init_module_for_test" for test interaction with other contracts

### 1.0.3:
- Deployed to testnet under contract address: 
- delete_review -> access changed to user and operator instead of operator only
- revised error codes