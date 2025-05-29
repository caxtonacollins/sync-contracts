use account::contract::account::Account;
use account::interfaces::Iaccount::{
    IaccountDispatcher, IaccountDispatcherTrait, IaccountSafeDispatcher,
    IaccountSafeDispatcherTrait,
};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::{ContractAddress, contract_address_const};


fn setup() -> (ContractAddress, ContractAddress) {
    let admin_address: ContractAddress = contract_address_const::<'1'>();

    let declare_result = declare("Account");
    assert(declare_result.is_ok(), 'contract decleration failed');

    let contract_class = declare_result.unwrap().contract_class();
    let mut calldata = array![admin_address.into()];

    let deploy_result = contract_class.deploy(@calldata);
    assert(deploy_result.is_ok(), 'contract deployment failed');

    let (contract_address, _) = deploy_result.unwrap();

    (contract_address, admin_address)
}


#[test]
fn test_increase_balance() {
    let (contract_address, admin_address_) = setup();
    let owner = contract_address_const::<'1'>();

    let dispatcher = IaccountDispatcher { contract_address };

    start_cheat_caller_address(dispatcher.contract_address, owner);

    let balance_before = dispatcher.get_balance();
    assert(balance_before == 0, 'Invalid balance');

    dispatcher.increase_balance(42);

    stop_cheat_caller_address(owner);

    let balance_after = dispatcher.get_balance();
    assert(balance_after == 42, 'Invalid balance');
}

#[test]
#[feature("safe_dispatcher")]
fn test_cannot_increase_balance_with_zero_value() {
    let (contract_address, admin_address_) = setup();
    let owner = contract_address_const::<'1'>();

    let dispatcher = IaccountDispatcher { contract_address };

    start_cheat_caller_address(dispatcher.contract_address, owner);

    let safe_dispatcher = IaccountSafeDispatcher { contract_address };

    let balance_before = safe_dispatcher.get_balance().unwrap();
    assert(balance_before == 0, 'Invalid balance');

    match safe_dispatcher.increase_balance(0) {
        Result::Ok(_) => core::panic_with_felt252('Should have panicked'),
        Result::Err(panic_data) => {
            assert(*panic_data.at(0) == 'Amount cannot be 0', *panic_data.at(0));
        },
    };
}
