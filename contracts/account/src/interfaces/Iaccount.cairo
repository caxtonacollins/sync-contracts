use starknet::ContractAddress;
#[starknet::interface]
pub trait Iaccount<TContractState> {
    fn increase_balance(ref self: TContractState, amount: felt252);
    fn get_balance(self: @TContractState) -> felt252;
    fn initialize(ref self: TContractState, public_key: felt252, liquidity_bridge: ContractAddress);
    fn approve_token(ref self: TContractState, symbol: felt252, token_address: ContractAddress);
}
