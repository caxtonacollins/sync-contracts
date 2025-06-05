use starknet::ContractAddress;
#[starknet::interface]
pub trait ILiquidityBridge<TContractState> {
    fn swap_crypto_to_fiat(
        ref self: TContractState,
        user: ContractAddress,
        crypto_symbol: felt252,
        fiat_currency: felt252,
        fiat_amount: u256,
    ) -> bool;
}
