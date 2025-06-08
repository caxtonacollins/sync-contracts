use starknet::ContractAddress;
#[starknet::interface]
pub trait Iaccount<TContractState> {
    fn increase_balance(ref self: TContractState, amount: felt252);
    fn get_balance(self: @TContractState) -> felt252;
    fn initialize(ref self: TContractState, public_key: felt252, liquidity_bridge: ContractAddress);
    fn approve_token(ref self: TContractState, symbol: felt252, token_address: ContractAddress);
    fn get_liquidity_bridge(self: @TContractState) -> ContractAddress;
    fn get_key_public(self: @TContractState) -> felt252;
    fn get_approved_token(self: @TContractState, symbol: felt252) -> ContractAddress;
    fn get_initialized_status(self: @TContractState) -> bool;
    fn make_payment(
        ref self: TContractState,
        recipient: ContractAddress,
        currency: felt252,
        amount: u128,
        use_liquidity_bridge: bool,
    ) -> bool;
    fn get_fiat_balance(self: @TContractState, user: ContractAddress, currency: felt252) -> u128;
}
