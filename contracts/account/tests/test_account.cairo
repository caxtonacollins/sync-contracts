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
        0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d
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

    // Initialize the contract
    start_cheat_caller_address(contract_address, contract_address);
    dispatcher.initialize(1, 2.try_into().unwrap());
    
    // Test deposit
    dispatcher.deposit_fiat(currency, amount);
    
    // Verify balance
    let balance = dispatcher.get_fiat_balance(contract_address, currency);
    assert(balance == amount.into(), 'Bal equal to deposited amount');
    
    stop_cheat_caller_address(contract_address);
}








fn withdraw_fiat(
    ref self: ContractState, currency: felt252, amount: u128, recipient: ContractAddress,
) {
    self.account.assert_only_self();
    assert(!amount.is_zero(), AccountErrors::AMOUNT_CANNOT_BE_ZERO);
    assert(!currency.is_zero(), AccountErrors::CURRENCY_IS_REQUIRED);
    assert(!recipient.is_zero(), AccountErrors::CANNOT_BE_ADDR_ZERO);

    let account_address = get_contract_address();
    let current_balance = self.fiat_balance.read((account_address, currency));
    assert(current_balance >= amount, 'Insufficient balance');

    // Deduct from sender's balance
    self.fiat_balance.write((account_address, currency), current_balance - amount);
    
    // Add to recipient's balance
    let recipient_balance = self.fiat_balance.read((recipient, currency));
    self.fiat_balance.write((recipient, currency), recipient_balance + amount);

    self
        .emit(
            FiatWithdrawal {
                account_address,
                currency,
                amount: current_balance - amount,
                recipient,
            },
        );
}

#[test]
#[should_panic(expected: ('Insufficient balance',))]
fn test_withdraw_fiat_insufficient_balance() {
    let (contract_address, _) = setup();
    let dispatcher = IaccountDispatcher { contract_address };
    let currency = 'USD';
    let recipient: ContractAddress = contract_address_const::<'2'>();

    // Initialize the contract
    start_cheat_caller_address(contract_address, contract_address);
    dispatcher.initialize(1, 2.try_into().unwrap());
    
    // Try to withdraw without depositing first
    dispatcher.withdraw_fiat(currency, 1000, recipient);
    
    stop_cheat_caller_address(contract_address);
}