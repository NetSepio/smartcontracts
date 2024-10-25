# EREBRUS
Smart Contract for the EREBRUS NFT with supply of 111.

Where decentralization meets VPN for ultimate internet security.
Anonymous Virtual Private Network for accessing internet in stealth mode bypassing filewalls and filters

To be deployed to testnet under contract address: 

Entry Functions:
- user_mint
- delegate_mint

View Functions:
- total_minted_NFTs: Total NFTs minted so far
- owner_of: Accepts tokenId to tell who is its owner

Events:
- NftMintedEvent


## Usage

To use this smart contract, follow these steps:

1. Compile the Move code:
   ```
   aptos init
   ```
3. Compile the Move code:
   ```
   aptos move compile
   ```

2. Publish the compiled package:
   ```
   aptos move publish
   ```

### Customizing the EREBRUS Token

To modify the EREBRUS token properties, you need to edit the `erebrus.move` file. Look for the following constants and update them as needed:

- `COLLECTION_NAME`
- `COLLECTION_DESCRIPTION`
- `COLLECTION_URI`
- `TOKEN_DESCRIPTION`
- `TOKEN_URI`

Make sure to recompile and republish the contract after making any changes.




## Revisions:
### 1.0.1:
### 1.0.2:
### 1.0.3:
- Deployed on mainnet under contract address: 