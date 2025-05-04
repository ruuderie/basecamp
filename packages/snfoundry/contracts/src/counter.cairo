#[starknet::interface]
pub trait ICounter<TContractState> {
    fn get_counter(self: @TContractState) -> u32;
    fn increase_counter(ref self: TContractState);
    fn decrease_counter(ref self: TContractState);
    fn reset_counter(ref self: TContractState);
}

#[starknet::contract]
pub mod Counter {
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use super::ICounter;
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableTwoStepImpl = OwnableComponent::OwnableTwoStepImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        counter: u32,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[constructor]
    fn constructor(ref self: ContractState, initial_value: u32, owner: ContractAddress) {
        self.counter.write(initial_value);
        self.ownable.initializer(owner);
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Increased: Increased,
        Decreased: Decreased,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        Reset: Reset,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Increased {
        #[key]
        pub account: ContractAddress,
    }
    #[derive(Drop, starknet::Event)]
    pub struct Decreased {
        #[key]
        pub account: ContractAddress,
    }
    #[derive(Drop, starknet::Event)]
    pub struct Reset {
        #[key]
        pub account: ContractAddress,
    }

    pub mod Error {
        pub const EMPTY_COUNTER: felt252 = 'Decreasing empty counter';
    }


    #[abi(embed_v0)]
    impl CounterImpl of ICounter<ContractState> {
        fn get_counter(self: @ContractState) -> u32 {
            self.counter.read()
        }
        fn increase_counter(ref self: ContractState) {
            let old_value = self.counter.read();
            let new_value = old_value + 1;
            self.counter.write(new_value);
            self.emit(Increased { account: get_caller_address() });
        }
        fn decrease_counter(ref self: ContractState) {
            let old_value = self.counter.read();
            assert(old_value > 0, Error::EMPTY_COUNTER);
            self.counter.write(old_value - 1);
            self.emit(Decreased { account: get_caller_address() });
        }
        fn reset_counter(ref self: ContractState) {
            //only the owner can reset the counter
            self.ownable.assert_only_owner();
            let old_value = self.counter.read();
            self.counter.write(0);
            self.emit(Reset { account: get_caller_address() });
        }
    }
}

