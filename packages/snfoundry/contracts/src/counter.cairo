#[starknet::interface]
pub trait ICounter<TContractState> {
    fn get_counter(self: @TContractState) -> u32;
    fn increase_counter(ref self: TContractState);
    fn decrease_counter(ref self: TContractState);
    fn reset_counter(ref self: TContractState);
}

#[starknet::contract]
pub mod Counter {
    use super::ICounter;
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
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
    enum Event {
        Increased: Increased,
        Decreased: Decreased,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        Reset: Reset,
    }

    #[derive(Drop, starknet::Event)]
    struct Increased {
        #[key]
        account: ContractAddress,
        increased_by: u32,
    }
    #[derive(Drop, starknet::Event)]
    struct Decreased {
        #[key]
        decreased_by: u32,
    }
    #[derive(Drop, starknet::Event)]
    struct Reset {
        #[key]
        reset_to: u32,
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
            let new_value = self.counter.read() + 1;
            self.counter.write(new_value);
            self.emit(Increased {account: get_caller_address(), increased_by: new_value - self.counter.read()});
        }
        fn decrease_counter(ref self: ContractState) {
            let old_value = self.counter.read();
            assert(old_value > 0, Error::EMPTY_COUNTER);
            self.counter.write(old_value - 1);
            self.emit(Decreased {decreased_by: old_value - self.counter.read()});
        }
        fn reset_counter(ref self: ContractState) {
            //only the owner can reset the counter
            self.ownable.assert_only_owner();
            let old_value = self.counter.read();
            self.counter.write(0);
            self.emit(Reset {reset_to: old_value});
        }
    }
}
    
    

