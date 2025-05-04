use contracts::Counter::{
    Counter, ICounterDispatcher, ICounterDispatcherTrait, ICounterSafeDispatcher,
    ICounterSafeDispatcherTrait,
};
use openzeppelin_access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ContractAddress;
const ZERO_COUNT: u32 = 0;

fn OWNER() -> ContractAddress {
    'OWNER'.try_into().unwrap()
}
fn USER_1() -> ContractAddress {
    'USER_1'.try_into().unwrap()
}
fn __deploy__(initial_value: u32) -> (ICounterDispatcher, IOwnableDispatcher, ICounterSafeDispatcher) {
    // declare the contract
    let contract = declare("Counter").unwrap().contract_class();

    // serialize constructor
    let mut calldata: Array<felt252> = array![];
    initial_value.serialize(ref calldata);
    OWNER().serialize(ref calldata);

    // deploy the contract
    let (contract_address, _) = contract.deploy(@calldata).unwrap();

    let counter = ICounterDispatcher { contract_address };
    let ownable = IOwnableDispatcher { contract_address };
    let safe_dispatcher = ICounterSafeDispatcher { contract_address };

    (counter, ownable, safe_dispatcher)
}

#[test]
fn test_counter_deployment() {
    let (counter, ownable, _) = __deploy__(ZERO_COUNT);
    let count_1 = counter.get_counter();
    assert(count_1 == ZERO_COUNT, 'Counter is not set');
    assert(ownable.owner() == OWNER(), 'Owner is not set');
}

#[test]
fn test_counter_increase() {
    let (counter, _, _) = __deploy__(ZERO_COUNT);
    let count_1 = counter.get_counter();
    assert(count_1 == ZERO_COUNT, 'Counter is not set');
    counter.increase_counter();
    let count_2 = counter.get_counter();
    assert(count_2 == count_1 + 1, 'Counter is not increased');
}

#[test]
fn test_emitted_increased_event() {
    let (counter, _, _) = __deploy__(ZERO_COUNT);
    let mut spy = spy_events();
    start_cheat_caller_address(counter.contract_address, USER_1());
    counter.increase_counter();
    stop_cheat_caller_address(counter.contract_address);
    
    spy.assert_emitted(
        @array![
            (
                counter.contract_address,
                Counter::Event::Increased(Counter::Increased { account: USER_1() })
            )
        ]
    );
    
    spy.assert_not_emitted(
        @array![
            (
                counter.contract_address,
                Counter::Event::Decreased(Counter::Decreased { account: USER_1() })
            )
        ]
    );
}

#[test]
fn test_counter_decrease() {
    let (counter, _, _) = __deploy__(ZERO_COUNT);
    let count_1 = counter.get_counter();
    assert(count_1 == ZERO_COUNT, 'Counter is not set');
    counter.increase_counter();
    let count_2 = counter.get_counter();
    assert(count_2 == count_1 + 1, 'Counter is not increased');
    counter.decrease_counter();
    let count_3 = counter.get_counter();
    assert(count_3 == count_2 - 1, 'Counter is not decreased');
}

#[test]
#[feature("safe_dispatcher")]
fn test_safe_panic_decrease_counter() {
    let (counter, _, safe_dispatcher) = __deploy__(ZERO_COUNT);
    assert(counter.get_counter() == ZERO_COUNT, 'invalid count');
    match safe_dispatcher.decrease_counter() {
        Result::Ok(_) => panic!("cannot decrease 0"),
        Result::Err(e) => {
            assert(e.len() > 0, 'No error message');
            assert(*e[0] == 'Decreasing empty counter', 'Unexpected error message');
        }
    }
}

#[test]
#[should_panic(expected: ('Decreasing empty counter',))]
fn test_panic_decrease_counter() {
    let (counter, _, _) = __deploy__(ZERO_COUNT);
    assert(counter.get_counter() == ZERO_COUNT, 'invalid count');
    counter.decrease_counter();
}

#[test]
fn test_successful_decrease_counter() {
    let (counter, _, _) = __deploy__(5);
    let count_1 = counter.get_counter();
    assert(count_1 == 5, 'invalid count');
    counter.decrease_counter();
    let count_2 = counter.get_counter();
    assert(count_2 == count_1 - 1, 'invalid decrease count');
}

#[test]
fn test_counter_reset_by_owner() {
    let (counter, ownable, _) = __deploy__(ZERO_COUNT);
    let count_1 = counter.get_counter();
    assert(count_1 == ZERO_COUNT, 'Counter is not set');
    counter.increase_counter();
    let count_2 = counter.get_counter();
    assert(count_2 == count_1 + 1, 'Counter is not increased');
    start_cheat_caller_address(counter.contract_address, OWNER());
    counter.reset_counter();
    stop_cheat_caller_address(counter.contract_address);
    let count_3 = counter.get_counter();
    assert(count_3 == ZERO_COUNT, 'Counter is not reset by owner');
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_counter_reset_by_non_owner() {
    let (counter, ownable, _) = __deploy__(ZERO_COUNT);
    let count_1 = counter.get_counter();
    assert(count_1 == ZERO_COUNT, 'Counter is not set');
    counter.increase_counter();
    let count_2 = counter.get_counter();
    assert(count_2 == count_1 + 1, 'Counter is not increased');
    start_cheat_caller_address(counter.contract_address, USER_1());
    counter.reset_counter();
    stop_cheat_caller_address(counter.contract_address);
}

#[test]
#[feature("safe_dispatcher")]
fn test_safe_panic_reset_counter_by_no_owner() {
    let (counter, _, safe_dispatcher) = __deploy__(ZERO_COUNT);
    assert(counter.get_counter() == ZERO_COUNT, 'invalid count');
    start_cheat_caller_address(counter.contract_address, USER_1());
    match safe_dispatcher.reset_counter() {
        Result::Ok(_) => panic!("cannot reset"),
        Result::Err(e) => {
            assert(e.len() > 0, 'No error message');
            assert(*e[0] == 'Caller is not the owner', 'Unexpected error message');
        }
    }
}

#[test]
fn test_successful_reset_counter() {
    let (counter, _, _) = __deploy__(5);
    let count_1 = counter.get_counter();
    assert(count_1 == 5, 'invalid count');
    start_cheat_caller_address(counter.contract_address, OWNER());
    counter.reset_counter();
    stop_cheat_caller_address(counter.contract_address);
    let count_2 = counter.get_counter();
    assert(count_2 == 0, 'counter not reset');
}
