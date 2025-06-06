use account::interfaces::Iaccount::{IaccountDispatcher, IaccountDispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::{ContractAddress, contract_address_const};

fn setup() -> (ContractAddress, ContractAddress) {
    let admin_address: ContractAddress = contract_address_const::<'1'>();
    let public_key: felt252 = 'TEST_PUBLIC_KEY';

    let declare_result = declare("Account");
    assert(declare_result.is_ok(), "contract declaration failed");

    let contract_class = declare_result.unwrap().contract_class();
    let mut calldata = array![public_key];

    let deploy_result = contract_class.deploy(@calldata);
    assert(deploy_result.is_ok(), "contract deployment failed");

    let (contract_address, _) = deploy_result.unwrap();

    (contract_address, admin_address)
}

#[test]
fn test_initialize() {
    let (contract_address, _) = setup();

    let dispatcher = IaccountDispatcher { contract_address };

    dispatcher.initialize(1, 2.try_into().unwrap());

    let liquidity_bridge = dispatcher.get_liquidity_bridge();
    assert(liquidity_bridge == 2.try_into().unwrap(), "Invalid liquidity bridge");

    let public_key = dispatcher.get_key_public();
    assert(public_key == 1, "Invalid public key");

    let initialized = dispatcher.get_initialized_status();
    assert(initialized, "Invalid initialized");
}

#[test]
fn test_approve_token() {
    let (contract_address, _) = setup();

    let dispatcher = IaccountDispatcher { contract_address };

    let token_address: ContractAddress = contract_address_const::<
        0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d
    >();

    start_cheat_caller_address(contract_address, contract_address);

    dispatcher.initialize(1, 2.try_into().unwrap());

    dispatcher.approve_token('STRK', token_address);

    stop_cheat_caller_address(contract_address);

    let approved_token = dispatcher.get_approved_token('STRK');
    assert(approved_token == token_address, "Invalid approved token");
}

#[test]
fn test_deposit_fiat() {
    let (contract_address, _) = setup();
    let dispatcher = IaccountDispatcher { contract_address };

    dispatcher.initialize(1, 2.try_into().unwrap());

    // Deposit 1000 units of currency '1'
    dispatcher.deposit_fiat(1, 1000);

    let balance = dispatcher.get_balance();
    assert(balance == 1000.try_into().unwrap(), "Balance should be 1000 after deposit");

    // Deposit zero should fail
    let deposit_zero_result = std::panic::catch_unwind(|| {
        dispatcher.deposit_fiat(1, 0);
    });
    assert(deposit_zero_result.is_err(), "Deposit of 0 should fail");
}

#[test]
fn test_withdraw_fiat() {
    let (contract_address, _) = setup();
    let dispatcher = IaccountDispatcher { contract_address };

    dispatcher.initialize(1, 2.try_into().unwrap());

    // Deposit 1000 so withdrawal can succeed
    dispatcher.deposit_fiat(1, 1000);

    // Withdraw 500
    dispatcher.withdraw_fiat(1, 500, contract_address);

    let balance = dispatcher.get_balance();
    assert(balance == 500.try_into().unwrap(), "Balance should be 500 after withdrawal");

    // Withdraw zero should fail
    let withdraw_zero_result = std::panic::catch_unwind(|| {
        dispatcher.withdraw_fiat(1, 0, contract_address);
    });
    assert(withdraw_zero_result.is_err(), "Withdraw of 0 should fail");

    // Withdraw more than balance should fail
    let withdraw_too_much_result = std::panic::catch_unwind(|| {
        dispatcher.withdraw_fiat(1, 1000, contract_address);
    });
    assert(withdraw_too_much_result.is_err(), "Withdraw more than balance should fail");
}
