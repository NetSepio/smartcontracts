use anchor_lang::prelude::*;
use std::mem::size_of;

declare_id!("6adzicpnDv2JmoJxbafKL4GXGMUbsfLUbdz31iwpRotC");

#[program]
pub mod erebrus_registry {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        let registry = &mut ctx.accounts.registry;
        registry.owner = *ctx.accounts.owner.key;
        registry.current_wifi_node = 0;
        registry.current_vpn_node = 0;
        Ok(())
    }

    pub fn register_wifi_node(
        ctx: Context<RegisterNode>,
        device_id: String,
        did: String,
        ssid: String,
        location: String,
        price_per_minute: u64,
    ) -> Result<()> {
        let registry = &mut ctx.accounts.registry;
        let node_id = registry.current_wifi_node;
        require!(node_id < MAX_NODES as u64, ErrorCode::MaxNodesReached);
        
        registry.current_wifi_node += 1;

        let wifi_node = &mut ctx.accounts.node;
        wifi_node.node_type = NodeType::WiFi;
        wifi_node.user = *ctx.accounts.user.key;
        wifi_node.device_id = device_id;
        wifi_node.did = did;
        wifi_node.ssid = Some(ssid);
        wifi_node.location = location;
        wifi_node.price_per_minute = Some(price_per_minute);
        wifi_node.is_active = true;
        wifi_node.total_checkpoints = 0;

        Ok(())
    }

    pub fn update_wifi_node(
        ctx: Context<UpdateNode>,
        ssid: Option<String>,
        location: Option<String>,
        price_per_minute: Option<u64>,
    ) -> Result<()> {
        let node = &mut ctx.accounts.node;
        require!(node.is_active, ErrorCode::NodeNotActive);
        require!(node.user == ctx.accounts.user.key(), ErrorCode::Unauthorized);
        require!(node.node_type == NodeType::WiFi, ErrorCode::InvalidNodeType);

        if let Some(new_ssid) = ssid {
            node.ssid = Some(new_ssid);
        }
        if let Some(new_location) = location {
            node.location = new_location;
        }
        if let Some(new_price) = price_per_minute {
            node.price_per_minute = Some(new_price);
        }
        Ok(())
    }

    pub fn deactivate_node(ctx: Context<DeactivateNode>) -> Result<()> {
        let node = &mut ctx.accounts.node;
        require!(ctx.accounts.registry.owner == ctx.accounts.owner.key(), ErrorCode::Unauthorized);
        node.is_active = false;
        Ok(())
    }

    pub fn device_checkpoint(
        ctx: Context<DeviceCheckpoint>,
        data_hash: String,
    ) -> Result<()> {
        let node = &mut ctx.accounts.node;
        let checkpoint = &mut ctx.accounts.checkpoint;
        
        checkpoint.node = node.key();
        checkpoint.user = *ctx.accounts.user.key;
        checkpoint.data_hash = data_hash;
        
        node.total_checkpoints += 1;
        
        Ok(())
    }

    pub fn register_vpn_node(
        ctx: Context<RegisterNode>,
        device_id: String,
        did: String,
        node_name: String,
        ip_address: String,
        isp_info: String,
        region: String,
        location: String,
    ) -> Result<()> {
        let registry = &mut ctx.accounts.registry;
        let node_id = registry.current_vpn_node;
        require!(node_id < MAX_NODES as u64, ErrorCode::MaxNodesReached);
        
        registry.current_vpn_node += 1;

        let vpn_node = &mut ctx.accounts.node;
        vpn_node.node_type = NodeType::VPN;
        vpn_node.user = *ctx.accounts.user.key;
        vpn_node.device_id = device_id;
        vpn_node.did = did;
        vpn_node.node_name = Some(node_name);
        vpn_node.ip_address = Some(ip_address);
        vpn_node.isp_info = Some(isp_info);
        vpn_node.region = Some(region);
        vpn_node.location = location;
        vpn_node.is_active = true;
        vpn_node.total_checkpoints = 0;

        Ok(())
    }

    pub fn update_vpn_node(
        ctx: Context<UpdateNode>,
        node_name: Option<String>,
        ip_address: Option<String>,
        isp_info: Option<String>,
        region: Option<String>,
        location: Option<String>,
    ) -> Result<()> {
        let node = &mut ctx.accounts.node;
        require!(node.is_active, ErrorCode::NodeNotActive);
        require!(node.user == ctx.accounts.user.key(), ErrorCode::Unauthorized);
        require!(node.node_type == NodeType::VPN, ErrorCode::InvalidNodeType);

        if let Some(new_node_name) = node_name {
            node.node_name = Some(new_node_name);
        }
        if let Some(new_ip_address) = ip_address {
            node.ip_address = Some(new_ip_address);
        }
        if let Some(new_isp_info) = isp_info {
            node.isp_info = Some(new_isp_info);
        }
        if let Some(new_region) = region {
            node.region = Some(new_region);
        }
        if let Some(new_location) = location {
            node.location = new_location;
        }
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(init, payer = owner, space = 8 + size_of::<ErebrusRegistry>())]
    pub registry: Account<'info, ErebrusRegistry>,
    #[account(mut)]
    pub owner: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct RegisterNode<'info> {
    #[account(mut)]
    pub registry: Account<'info, ErebrusRegistry>,
    #[account(init, payer = user, space = 8 + size_of::<Node>())]
    pub node: Account<'info, Node>,
    #[account(mut)]
    pub user: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct UpdateNode<'info> {
    #[account(mut)]
    pub node: Account<'info, Node>,
    pub user: Signer<'info>,
}

#[derive(Accounts)]
pub struct DeactivateNode<'info> {
    pub registry: Account<'info, ErebrusRegistry>,
    #[account(mut)]
    pub node: Account<'info, Node>,
    pub owner: Signer<'info>,
}

#[derive(Accounts)]
pub struct DeviceCheckpoint<'info> {
    #[account(
        init,
        payer = user,
        space = 8 + size_of::<Checkpoint>(),
        seeds = [b"checkpoint", node.key().as_ref(), &node.total_checkpoints.to_le_bytes()],
        bump
    )]
    pub checkpoint: Account<'info, Checkpoint>,
    #[account(mut)]
    pub node: Account<'info, Node>,
    #[account(mut)]
    pub user: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[account]
#[derive(Default)]
pub struct ErebrusRegistry {
    pub owner: Pubkey,
    pub current_wifi_node: u64,
    pub current_vpn_node: u64,
}

#[account]
#[derive(Default)]
pub struct Node {
    pub node_type: NodeType,
    pub user: Pubkey,
    pub device_id: String,
    pub did: String,
    pub ssid: Option<String>,
    pub node_name: Option<String>,
    pub ip_address: Option<String>,
    pub isp_info: Option<String>,
    pub region: Option<String>,
    pub location: String,
    pub price_per_minute: Option<u64>,
    pub is_active: bool,
    pub total_checkpoints: u64,
}

#[account]
#[derive(Default)]
pub struct Checkpoint {
    pub node: Pubkey,
    pub user: Pubkey,
    pub data_hash: String,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, PartialEq, Default)]
pub enum NodeType {
    #[default]
    WiFi,
    VPN,
}

#[error_code]
pub enum ErrorCode {
    InvalidNodeId,
    NodeNotActive,
    Unauthorized,
    MaxNodesReached,
    InvalidNodeType,
}

const MAX_NODES: usize = 1000;