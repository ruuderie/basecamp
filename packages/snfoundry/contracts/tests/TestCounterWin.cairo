use contracts::Counter::{
    Counter, ICounterDispatcher, ICounterDispatcherTrait, ICounterSafeDispatcher,
    ICounterSafeDispatcherTrait, Counter::FELT_STRK_CONTRACT
};
use openzeppelin_access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::EventSpyAssertionsTrait;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, spy_events, start_cheat_caller_address,
    stop_cheat_caller_address,
};

use starknet::{ContractAddress};


const ZERO_COUNT: u32 = 0;
const STRK_AMOUNT: u256 = 5000000000000000000;
const WIN_NUMBER: u32 = 10;


fn OWNER() -> ContractAddress {
    'OWNER'.try_into().unwrap()
}

fn USER_1() -> ContractAddress {
    'USER_1'.try_into().unwrap()
}

fn STRK() -> ContractAddress {
    FELT_STRK_CONTRACT.try_into().unwrap()
}

pub const STRK_TOKEN_ADDRESS: felt252 =
    0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d;

fn STRK_TOKEN_HOLDER() -> ContractAddress {
    STRK_TOKEN_ADDRESS.try_into().unwrap()
}

fn __deploy__(
    init_value: u32,
) -> (ICounterDispatcher, IOwnableDispatcher, ICounterSafeDispatcher, IERC20Dispatcher) {
    let contract_class = declare("Counter").expect('failed to declare').contract_class();

    let mut calldata: Array<felt252> = array![];
    init_value.serialize(ref calldata);
    OWNER().serialize(ref calldata);

    let (contract_address, _) = contract_class.deploy(@calldata).expect('failed to deploy');

    let counter = ICounterDispatcher { contract_address };
    let ownable = IOwnableDispatcher { contract_address };
    let safe_dispatcher = ICounterSafeDispatcher { contract_address };
    let strk_token = IERC20Dispatcher { contract_address: STRK() };

    // Mock the STRK token transfer for testing purposes
    // Disabled to avoid issues with undeployed contract
    // transfer_strk(STRK_TOKEN_HOLDER(), contract_address, STRK_AMOUNT);
    
    (counter, ownable, safe_dispatcher, strk_token)
}

// Functions that interact with STRK contract directly - disabled for testing
// fn get_strk_token_balance(account: ContractAddress) -> u256 {
//     IERC20Dispatcher { contract_address: STRK() }.balance_of(account)
// }

// fn transfer_strk(caller: ContractAddress, recipient: ContractAddress, amount: u256) {
//     start_cheat_caller_address(STRK(), caller);
//     let token_dispatcher = IERC20Dispatcher { contract_address: STRK() };
//     token_dispatcher.transfer(recipient, amount);
//     stop_cheat_caller_address(STRK());
// }

// fn approve_strk(owner: ContractAddress, spender: ContractAddress, amount: u256) {
//     start_cheat_caller_address(STRK(), owner);
//     let token_dispatcher = IERC20Dispatcher { contract_address: STRK() };
//     token_dispatcher.approve(spender, amount);
//     stop_cheat_caller_address(STRK());
// }

#[test]
//#[fork("MAINNET_LATEST", block_tag: latest)]
fn test_counter_deployment() {
    let (counter, ownable, _, _) = __deploy__(ZERO_COUNT);

    let count_1 = counter.get_counter();

    assert(count_1 == ZERO_COUNT, 'count not set');
    assert(ownable.owner() == OWNER(), 'owner not set');
}

#[test]
// Removed fork attribute to run locally without network dependency
fn test_increase_counter() {
    let (counter, _, _, _) = __deploy__(ZERO_COUNT);

    let count_1 = counter.get_counter();

    assert(count_1 == ZERO_COUNT, 'count not set');

    counter.increase_counter();

    let count_2 = counter.get_counter();
    assert(count_2 == count_1 + 1, 'invalid count');
}

#[test]
fn test_emitted_increase_event() {
    let (counter, _, _, _) = __deploy__(ZERO_COUNT);
    let mut spy = spy_events();

    start_cheat_caller_address(counter.contract_address, USER_1());
    counter.increase_counter();
    stop_cheat_caller_address(counter.contract_address);
    spy
        .assert_emitted(
            @array![
                (
                    counter.contract_address,
                    Counter::Event::Increased(Counter::Increased { account: USER_1() }),
                ),
            ],
        );

    spy
        .assert_not_emitted(
            @array![
                (
                    counter.contract_address,
                    Counter::Event::Decreased(Counter::Decreased { account: USER_1() }),
                ),
            ],
        );
}

#[test]
#[feature("safe_dispatcher")]
fn test_safe_panic_decrease_counter() {
    let (counter, _, safe_dispatcher, _) = __deploy__(ZERO_COUNT);

    assert(counter.get_counter() == ZERO_COUNT, 'invalid count');

    match safe_dispatcher.decrease_counter() {
        Result::Ok(_) => panic!("cannot decrease 0"),
        Result::Err(e) => assert(*e[0] == 'Decreasing Empty counter', *e.at(0)),
    }
}

#[test]
#[should_panic(expected: 'Decreasing Empty counter')]
fn test_panic_decrease_counter() {
    let (counter, _, _, _) = __deploy__(ZERO_COUNT);

    assert(counter.get_counter() == ZERO_COUNT, 'invalid count');

    counter.decrease_counter()
}

#[test]
fn test_successful_decrease_counter() {
    let (counter, _, _, _) = __deploy__(5);
    let count_1 = counter.get_counter();

    assert(count_1 == 5, 'invalid count');

    counter.decrease_counter();

    let count_2 = counter.get_counter();
    assert(count_2 == count_1 - 1, 'invalid decrease count');
}

#[test]
fn test_emitted_decrease_event() {
    let (counter, _, _, _) = __deploy__(5);
    let mut spy = spy_events();

    start_cheat_caller_address(counter.contract_address, USER_1());
    counter.decrease_counter();
    stop_cheat_caller_address(counter.contract_address);
    spy
        .assert_emitted(
            @array![
                (
                    counter.contract_address,
                    Counter::Event::Decreased(Counter::Decreased { account: USER_1() }),
                ),
            ],
        );

    spy
        .assert_not_emitted(
            @array![
                (
                    counter.contract_address,
                    Counter::Event::Increased(Counter::Increased { account: USER_1() }),
                ),
            ],
        );
}

#[test]
#[feature("safe_dispatcher")]
#[fork("SEPOLIA_LATEST", block_tag: latest)]
fn test_safe_panic_reset_counter_by_no_owner() {
    let (counter, _, safe_dispatcher, _) = __deploy__(ZERO_COUNT);

    assert(counter.get_counter() == ZERO_COUNT, 'invalid count');

    start_cheat_caller_address(counter.contract_address, USER_1());

    let result = safe_dispatcher.reset_counter();
    match result {
        Result::Ok(_) => {
            panic!("Non-owner reset should fail");
        },
        Result::Err(e) => {
            assert(e.len() > 0, 'No error message');
            assert(*e[0] == 'Caller is not the owner', 'Unexpected error message');
            // Test passes if we reach here with the correct error
        }
    }
    stop_cheat_caller_address(counter.contract_address);
}

#[test]
#[fork("SEPOLIA_LATEST", block_tag: latest)]
fn test_successful_reset_counter() {
    let (counter, _, _, _) = __deploy__(5);
    let count_1 = counter.get_counter();

    assert(count_1 == 5, 'invalid count');

    start_cheat_caller_address(counter.contract_address, OWNER());

    counter.reset_counter();
    stop_cheat_caller_address(counter.contract_address);
    let count_2 = counter.get_counter();

    assert(count_2 == 0, 'counter not reset');
}
