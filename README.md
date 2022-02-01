
# SmartContract
Smart Contract for the NetSepio Voting and NFT Minting Operations

Polygon testnet mumbai:
https://mumbai.polygonscan.com/address/0x8869088f4B2B415b8D0C5f3882BE03a214EFF4B0#code

updated contract address: 0x8869088f4B2B415b8D0C5f3882BE03a214EFF4B0

default moderator: 0x2dA0a615981C2c9c70E34b8f50Db5f5a905E7928 


---

You'll find here the NFT contracts, tests for that contract, a script that deploys those contracts. It also comes with a variety of other tools, preconfigured to work with the project code.

## Installation
1. Clone the repo by using 
```shell
git clone https://github.com/NetSepio/SmartContract.git
```
2. Install the dependencies by using the command `npm install`.
   This way your environment will be reproducible, and you will avoid future version conflicts.

## Configuration
1. Rename the file `.env.example` to `.env`
2. Update the values of the given parameters:
```shell
ETHERSCAN_API_KEY=
POLYGONSCAN_API_KEY=
ROPSTEN_URL=
RINKEBY_RPC_URL=
MATICMUM_RPC_URL=
MNEMONIC=
```
3. `ETHERSCAN_API_KEY` is required to verify the contract deployed on the blockchain network. Since we're using the Polygon Testnet, We need to get the API key from ```https://polygonscan.com```

4. Next we need to update the RPC URL based on the network of our choice. Since we have chosen the Polygon Testnet, we need to provide `MATICMUM_RPC_URL` from 
the `https://alchemy.com` or `https://infura.io`. In case if we choose, Rinkeby or Ropsten, we need to update their respective RPC URLs. 

5. Lastly we need to provide the wallet from which the gas will be deducted in order to deploy the smart contract. We provide the `MNEMONIC` i.e., The seed words from the ETH wallet/metamask to pay for the transaction. Ensure that there are enough funds in the wallet to pay for the transaction.

## Compiling the contract
Next, if you take a look at `contracts/`, you should be able to find `NetSepio.sol`.

Compile the smart contract by using 
```shell
npx hardhat compile
```

## Testing the contract
This project has tests that uses `@openzeppelin/test-helpers`. If we take a look at `test/`, you should be able to find various `test.js`.

To run the tests, we can use command:
```shell
npx hardhat test
```

## Deploying the contract
Next, to deploy the contract we will use a Hardhat script. Inside `scripts/` we use `deploy.js` and run it with 
```shell
npx hardhat run --network maticmum scripts/NetSepio-deploy.js
```
## Etherscan verification

To try out Etherscan verification, we need to deploy a contract to an Ethereum network that's supported by Etherscan, such as `Polygon Testnet - maticmum`.
Then, copy the deployment address and paste it in to replace `DEPLOYED_CONTRACT_ADDRESS` in this command:

```shell
npx hardhat verify --network maticmum --constructor-args NetSepioArguments.js DEPLOYED_CONTRACT_ADDRESS
```
where `NetSepioArguments.js` is a javascript module that exports the argument list.

Finally, visit the contract address on the Blockchain Explorer (PolygonScan) and interact with the smart contract at section `Read Contract` and `Write Contract`

# The graph setting(mumbai):

Build completed: QmZ5R3gSFC8MjkGZ2krBq8w3QZzzR76fbzLvbUwhN2wg3J

Deployed to https://thegraph.com/studio/subgraph/net

Subgraph endpoints:

Queries (HTTP):     https://api.studio.thegraph.com/query/5758/net/v0.0.1

Subscriptions (WS): https://api.studio.thegraph.com/query/5758/net/v0.0.1



# The graph setting(rinkeby):

Build completed: QmUaBWDjKafMzvHS7TkEFPQYkA22XBn5JWjj1cKJRjj87K

Deployed to https://thegraph.com/studio/subgraph/net1

Subgraph endpoints:

Queries (HTTP):     https://api.studio.thegraph.com/query/5758/net1/v0.0.1

Subscriptions (WS): https://api.studio.thegraph.com/query/5758/net1/v0.0.1

https://testnet.thegraph.com/subgraph?id=0x6a453a70f6fac3abef56e1cb6741b06a25b9e9fb-0&view=Overview
