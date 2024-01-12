# Reviews_NFT
Smart Contract for the NetSepio Reviews for Aptos Blockchain

_Currently deployed on testnet:_ 75bcfe882d1a4d032ead2b47f377e4c95221594d66ab2bd09a61aded4c9d64f9

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
- Deployed to testnet under contract address: 0x5fdf39c03b36e9c59387628ca9066c62b2ec41019355c249177a7886e663f4a1
- delete_review -> access changed to user and operator instead of operator only
- revised error codes

### 1.0.4:
- Deployed to testnet under contract address: f315eefb17f4ec43cc9fab9123bf96883162984bfb9f716b81491e789199549e
- Changed NFT name system
- Changed Collection and NFT image_uri

### 1.0.5:
- Deployed to testnet under contract address: 75bcfe882d1a4d032ead2b47f377e4c95221594d66ab2bd09a61aded4c9d64f9
- Debugged NFT generation issue

### 1.0.6:
- Deployed to mainnet under contract address: 