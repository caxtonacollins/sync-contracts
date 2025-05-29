use account::{
    IAccountDispatcher, IAccountDispatcherTrait,
};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address, stop_cheat_caller_address};
use starknet::ContractAddress;

fn deploy_contract(name: ByteArray) -> ContractAddress {
    let contract = declare(name).unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    contract_address
}

#[test]
fn test_initialize() {
    let contract_address = deploy_contract("Account");

    let dispatcher = IAccountDispatcher { contract_address };

    dispatcher.initialize(1, 2.try_into().unwrap());

    let liquidity_bridge = dispatcher.get_liquidity_bridge();
    assert(liquidity_bridge == 2.try_into().unwrap(), 'Invalid liquidity bridge');

    let public_key = dispatcher.get_public_key();
    assert(public_key == 1, 'Invalid public key');
}

#[test]
fn test_approve_token() {
    let contract_address = deploy_contract("Account");

    let dispatcher = IAccountDispatcher { contract_address };

    let token_address: ContractAddress = 1.try_into().unwrap();
    let user_address: ContractAddress = 2.try_into().unwrap();

    start_cheat_caller_address(token_address, user_address);

    dispatcher.approve_token('STRK', token_address);

    stop_cheat_caller_address(token_address);

    let approved_token = dispatcher.get_approved_token('STRK');
    assert(approved_token == token_address, 'Invalid approved token');
}
