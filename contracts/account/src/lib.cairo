<<<<<<< HEAD
pub mod contract {
    pub mod account;
}

pub mod interfaces {
    pub mod Iaccount;
=======
use starknet::ContractAddress;

#[starknet::interface]
pub trait IAccount<TContractState> {
    fn initialize(ref self: TContractState, public_key: felt252, liquidity_bridge: ContractAddress);
    fn approve_token(ref self: TContractState, symbol: felt252, token_address: ContractAddress);
}

#[starknet::contract]
mod Account {
    

>>>>>>> 35cecce (feat: Account implementation functions initialize and approve_token)
}
