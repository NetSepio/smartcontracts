# Erebrus Registry - Solana Anchor Project

This project implements the Erebrus Registry, a decentralized system for managing WiFi and VPN nodes on the Solana blockchain.

_Devnet Deployment:_ [dyu7uefnn2Y2bKCDu6uTP4pVBPcBu4RPwsV522rjtbR6B2BJyA4vWC4eLGosDXqPzMpXsaBgzbE8VjqMkaYgf6g](https://explorer.solana.com/tx/dyu7uefnn2Y2bKCDu6uTP4pVBPcBu4RPwsV522rjtbR6B2BJyA4vWC4eLGosDXqPzMpXsaBgzbE8VjqMkaYgf6g?cluster=devnet)

## Features

1. **Registry Initialization**: Set up the main registry for managing nodes.
2. **WiFi Node Management**: Register, update, and deactivate WiFi nodes.
3. **VPN Node Management**: Register, update, and deactivate VPN nodes.
4. **Device Checkpoints**: Record checkpoints for registered devices.

## Smart Contract Structure

The main program module `erebrus_registry` contains the following key functions:

- `initialize`: Initialize the Erebrus Registry.
- `register_wifi_node`: Register a new WiFi node.
- `update_wifi_node`: Update an existing WiFi node's information.
- `register_vpn_node`: Register a new VPN node.
- `update_vpn_node`: Update an existing VPN node's information.
- `deactivate_node`: Deactivate a node (can be either WiFi or VPN).
- `device_checkpoint`: Record a checkpoint for a device.

## Account Structures

- `ErebrusRegistry`: Main registry account.
- `Node`: Represents a WiFi or VPN node.
- `Checkpoint`: Represents a device checkpoint.

## Development

This project uses Anchor, a framework for Solana's Sealevel runtime.

### Prerequisites

- Rust
- Solana CLI
- Anchor

### Setup

1. Clone the repository
2. Install dependencies:
   ```
   npm install
   ```

### Building

To build the project, run:

```
anchor build
```

### Testing

To run tests, use:

```
anchor test
```

### Deploying

To deploy the program to the Solana network, use:

```
anchor deploy
```


