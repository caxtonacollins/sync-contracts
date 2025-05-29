// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts for Cairo 2.0.0-alpha.1

#[starknet::contract(account)]
mod Account {
    use account::interfaces::Iaccount::Iaccount;
    use openzeppelin::account::AccountComponent;
    use openzeppelin::account::extensions::SRC9Component;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ClassHash, ContractAddress, get_caller_address};
    use openzeppelin::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};


    component!(path: AccountComponent, storage: account, event: AccountEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: SRC9Component, storage: src9, event: SRC9Event);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // External
    #[abi(embed_v0)]
    impl AccountMixinImpl = AccountComponent::AccountMixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl OutsideExecutionV2Impl =
        SRC9Component::OutsideExecutionV2Impl<ContractState>;

    // Internal
    impl AccountInternalImpl = AccountComponent::InternalImpl<ContractState>;
    impl OutsideExecutionInternalImpl = SRC9Component::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        account: AccountComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        src9: SRC9Component::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        // Custom storage for SyncPayment functionality
        fiat_balance: Map<(ContractAddress, felt252), u128>, // (user, currency) => balance
        token_address: Map<felt252, ContractAddress>, // symbol => token_address
        default_fiat_currency: felt252,
        liquidity_bridge: ContractAddress,
        initialized: bool,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccountEvent: AccountComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        SRC9Event: SRC9Component::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        TokenApproved: TokenApproved,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenApproved {
        pub user: ContractAddress,
        pub symbol: felt252,
        pub token_address: ContractAddress,
        pub amount: u128,
    }

    #[constructor]
    fn constructor(ref self: ContractState, public_key: felt252) {
        self.account.initializer(public_key);
        self.src9.initializer();
    }

    //
    // Upgradeable
    //

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.account.assert_only_self();
            self.upgradeable.upgrade(new_class_hash);
        }
    }


    // contract impl
    #[abi(embed_v0)]
    impl AccountImpl of Iaccount<ContractState> {
        fn increase_balance(ref self: ContractState, amount: felt252) {
            assert(amount != 0, 'Amount cannot be 0');
            let caller = get_caller_address();
            let currency = self.default_fiat_currency.read();
            let current_balance = self.fiat_balance.read((caller, currency));

            self
                .fiat_balance
                .write((caller, currency), current_balance + amount.try_into().unwrap());
        }

        fn get_balance(self: @ContractState) -> felt252 {
            let caller = get_caller_address();
            let currency = self.default_fiat_currency.read();
            self.fiat_balance.read((caller, currency)).into()
        }

        fn initialize(ref self: ContractState, public_key: felt252, liquidity_bridge: ContractAddress) {
            self.public_key.write(public_key);
            self.liquidity_bridge.write(liquidity_bridge);
        }

        fn approve_token(ref self: ContractState, symbol: felt252, token_address: ContractAddress) {
            // Store the approved token
            self.approved_tokens.write(symbol, token_address);
            
            // Get the liquidity bridge address
            let bridge_address = self.liquidity_bridge.read();
            
            // Create dispatcher for the token contract
            let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
            
            // Approve maximum amount to the liquidity bridge
            token_dispatcher.approve(bridge_address, 10000000000000000000);
            
            // Emit event
            self.emit(TokenApproved {
                user: get_caller_address(),
                symbol,
                token_address,
                amount: 10000000000000000000,
            });
        }
    }
}

