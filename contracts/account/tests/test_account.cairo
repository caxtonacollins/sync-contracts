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
    assert(declare_result.is_ok(), 'contract decleration failed');

    let contract_class = declare_result.unwrap().contract_class();
    let mut calldata = array![public_key];

    let deploy_result = contract_class.deploy(@calldata);
    assert(deploy_result.is_ok(), 'contract deployment failed');

    let (contract_address, _) = deploy_result.unwrap();

    (contract_address, admin_address)
}

#[test]
fn test_initialize() {
    let (contract_address, _) = setup();

    let dispatcher = IaccountDispatcher { contract_address };

    dispatcher.initialize(1, 2.try_into().unwrap());

    let liquidity_bridge = dispatcher.get_liquidity_bridge();
    assert(liquidity_bridge == 2.try_into().unwrap(), 'Invalid liquidity bridge');

    let public_key = dispatcher.get_key_public();
    assert(public_key == 1, 'Invalid public key');

    let initialized = dispatcher.get_initialized_status();
    assert(initialized, 'Invalid initialized');
}

#[test]
fn test_approve_token() {
    let (contract_address, _) = setup();

    let dispatcher = IaccountDispatcher { contract_address };

    let token_address: ContractAddress = contract_address_const::<
        0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d,
    >();

    start_cheat_caller_address(contract_address, contract_address);

    dispatcher.initialize(1, 2.try_into().unwrap());

    dispatcher.approve_token('STRK', token_address);

    stop_cheat_caller_address(contract_address);

    let approved_token = dispatcher.get_approved_token('STRK');
    assert(approved_token == token_address, 'Invalid approved token');
}


#[test]
fn test_deposit_fiat() {
    let (contract_address, _) = setup();
    let dispatcher = IaccountDispatcher { contract_address };
    let currency = 'USD';
    let amount: u128 = 1000;

    start_cheat_caller_address(contract_address, contract_address);
    dispatcher.initialize(1, 2.try_into().unwrap());

    dispatcher.deposit_fiat(currency, amount);

    let balance = dispatcher.get_fiat_balance(contract_address, currency);
    assert(balance == amount.into(), 'Bal equal to deposited amount');

    stop_cheat_caller_address(contract_address);
}


#[test]
#[should_panic(expected: ('Insufficient balance',))]
fn test_withdraw_fiat_insufficient_balance() {
    let (contract_address, _) = setup();
    let dispatcher = IaccountDispatcher { contract_address };
    let currency = 'USD';
    let recipient: ContractAddress = contract_address_const::<'2'>();

    start_cheat_caller_address(contract_address, contract_address);
    dispatcher.initialize(1, 2.try_into().unwrap());

    dispatcher.withdraw_fiat(currency, 1000, recipient);

    stop_cheat_caller_address(contract_address);
}


#[test]
fn test_multiple_deposits() {
    let (contract_address, _) = setup();
    let dispatcher = IaccountDispatcher { contract_address };
    let currency = 'USD';
    let amount1: u128 = 1000;
    let amount2: u128 = 500;

    start_cheat_caller_address(contract_address, contract_address);
    dispatcher.initialize(1, 2.try_into().unwrap());

    dispatcher.deposit_fiat(currency, amount1);
    // Second deposit
    dispatcher.deposit_fiat(currency, amount2);

    let balance = dispatcher.get_fiat_balance(contract_address, currency);
    assert(balance == (amount1 + amount2).into(), 'Bal equ sum of both deposits');

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_different_currencies() {
    let (contract_address, _) = setup();
    let dispatcher = IaccountDispatcher { contract_address };
    let usd_amount: u128 = 1000;
    let eur_amount: u128 = 500;

    start_cheat_caller_address(contract_address, contract_address);
    dispatcher.initialize(1, 2.try_into().unwrap());

    dispatcher.deposit_fiat('USD', usd_amount);
    dispatcher.deposit_fiat('EUR', eur_amount);

    let usd_balance = dispatcher.get_fiat_balance(contract_address, 'USD');
    let eur_balance = dispatcher.get_fiat_balance(contract_address, 'EUR');

    assert(usd_balance == usd_amount.into(), 'USD balance incorrect');
    assert(eur_balance == eur_amount.into(), 'EUR balance incorrect');

    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Amount cannot be Zero',))]
fn test_deposit_zero_amount() {
    let (contract_address, _) = setup();
    let dispatcher = IaccountDispatcher { contract_address };

    start_cheat_caller_address(contract_address, contract_address);
    dispatcher.initialize(1, 2.try_into().unwrap());

    dispatcher.deposit_fiat('USD', 0);
}

