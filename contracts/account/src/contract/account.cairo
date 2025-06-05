// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts for Cairo 2.0.0-alpha.1

#[starknet::contract(account)]
mod Account {
    use core::num::traits::Zero;
    use account::interfaces::Iaccount::Iaccount;
    use account::interfaces::ILiquidityBridge::{ILiquidityBridge, ILiquidityBridgeDispatcher};
    use account::base::errors::AccountErrors;
    use openzeppelin::account::AccountComponent;
    use openzeppelin::account::extensions::SRC9Component;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ClassHash, ContractAddress, get_caller_address, get_contract_address};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};


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
        public_key: felt252,
        approved_tokens: Map<felt252, ContractAddress>, // symbol => token_address
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
        TokenApproved: TokenApproved,
        PaymentMade: PaymentMade
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenApproved {
        pub user: ContractAddress,
        pub symbol: felt252,
        pub token_address: ContractAddress,
        pub amount: u128,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PaymentMade {
        pub from: ContractAddress,
        pub to: ContractAddress,
        pub currency: felt252,
        pub amount: u128,
        pub used_bridge: bool,
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

        fn make_payment(
            ref self: ContractState,
            recipient: ContractAddress,
            currency: felt252,
            amount: u128,
            use_liquidity_bridge: bool,
        ) -> bool {
            self.account.assert_only_self();
            let account_address = get_contract_address();
            assert(!recipient.is_zero(), AccountErrors::CANNOT_BE_ADDR_ZERO);
            assert(!amount.is_zero(), AccountErrors::AMOUNT_CANNOT_BE_ZERO);
            assert(!currency.is_zero(), AccountErrors::CURRENCY_IS_REQUIRED);
            let current_balance = self.fiat_balance.read((account_address, currency));

            if current_balance >= amount {
                self.fiat_balance.write((account_address, currency), current_balance - amount);
                let recipient_balance = self.fiat_balance.read((recipient, currency));
                self.fiat_balance.write((recipient, currency), recipient_balance + amount);
                self
                    .emit(
                        PaymentMade {
                            from: account_address,
                            to: recipient,
                            currency,
                            amount: current_balance - amount,
                            used_bridge: use_liquidity_bridge,
                        },
                    );

                return true;
            } else if use_liquidity_bridge && current_balance < amount {
                // If the balance is insufficient, try to swap crypto to fiat using the liquidity
                // bridge
                let bridge = self.liquidity_bridge.read();
                let bridge_dispatcher = ILiquidityBridgeDispatcher { contract_address: bridge };

                let crypto_symbol = 'STRK';
                assert(!crypto_symbol.is_zero(), AccountErrors::CURRENCY_IS_REQUIRED);

                // The amount to swap will be the difference between the current balance and the
                // amount
                let amount_to_swap = amount - current_balance;
                assert(amount_to_swap > 0, AccountErrors::AMOUNT_CANNOT_BE_ZERO);

                // The swap_crypto_to_fiat will use the liquidity bridge to swap crypto to fiat
                // It will use the account_address to see if the user has enough crypto to swap
                // Deduct the amount from the token account after successful swap
                // Credit user with the amount required to complete the payment
                let success = bridge_dispatcher
                    .swap_crypto_to_fiat(
                        account_address, crypto_symbol, currency, amount_to_swap.into(),
                    ); // the swap_crypto_to_fiat will use the liquidity bridge to swap crypto to fiat 

                if success {
                    // If the swap was successful, update the fiat balance
                    let new_balance = self.get_fiat_balance(currency);
                    assert(new_balance >= amount, 'Insufficient balance after swap');

                    // Deduct the amount after successful swap
                    self.fiat_balance.write((account_address, currency), new_balance - amount);

                    // Credit recipient
                    let recipient_balance = self.fiat_balance.read((recipient, currency));
                    self.fiat_balance.write((recipient, currency), recipient_balance + amount);

                    self
                        .emit(
                            PaymentMade {
                                from: account_address,
                                to: recipient,
                                currency,
                                amount,
                                used_bridge: true,
                            },
                        );
                    return true;
                }
            }
            return false;
        }

        fn get_balance(self: @ContractState) -> felt252 {
            let caller = get_caller_address();
            let currency = self.default_fiat_currency.read();
            self.fiat_balance.read((caller, currency)).into()
        }

        fn initialize(
            ref self: ContractState, public_key: felt252, liquidity_bridge: ContractAddress
        ) {
            assert(!self.initialized.read(), 'Already initialized');
            self.public_key.write(public_key);
            self.liquidity_bridge.write(liquidity_bridge);
            self.initialized.write(true);
        }

        fn approve_token(ref self: ContractState, symbol: felt252, token_address: ContractAddress) {
            self.account.assert_only_self();
            assert(self.initialized.read(), 'Not initialized');
            assert(
                self.approved_tokens.read(symbol) == 0.try_into().unwrap(), 'Token already approved'
            );
            assert(token_address != 0.try_into().unwrap(), 'Token address cannot be 0');

            self.approved_tokens.write(symbol, token_address);

            let bridge_address = self.liquidity_bridge.read();

            let token_dispatcher = IERC20Dispatcher { contract_address: token_address };

            token_dispatcher.approve(bridge_address, 10000000000000000000);

            self
                .emit(
                    TokenApproved {
                        user: get_caller_address(),
                        symbol,
                        token_address,
                        amount: 10000000000000000000,
                    }
                );
        }

        fn get_liquidity_bridge(self: @ContractState) -> ContractAddress {
            self.liquidity_bridge.read()
        }

        fn get_key_public(self: @ContractState) -> felt252 {
            self.public_key.read()
        }

        fn get_approved_token(self: @ContractState, symbol: felt252) -> ContractAddress {
            self.approved_tokens.read(symbol)
        }

        fn get_initialized_status(self: @ContractState) -> bool {
            self.initialized.read()
        }
    }
}

