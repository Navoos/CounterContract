use snforge_std::EventSpyAssertionsTrait;
use contracts::counter::ICounterDispatcherTrait;
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address};
use starknet::ContractAddress;
use contracts::counter::ICounterDispatcher;
use contracts::counter::CounterContract::{CounterChanged, ChangeReason, Event};


fn deploy_counter(init_value: u32, owner: ContractAddress) -> ICounterDispatcher {
    let contract = declare("CounterContract").unwrap().contract_class();
    
    let mut constructor_args = array![];
    init_value.serialize(ref constructor_args);
    owner.serialize(ref constructor_args);
    
    let (contract_address, _) = contract.deploy(@constructor_args).unwrap();
    let dispatcher = ICounterDispatcher{ contract_address };

    dispatcher
}

#[test]
fn test_contract_initialization() {
    let to_be_matched_value = 5;
    let initial_value = to_be_matched_value;
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_counter(initial_value, owner);
    
    let current_counter_value = dispatcher.get_counter();
    let expected_counter_value = to_be_matched_value;
    
    assert!(current_counter_value == expected_counter_value, "Initialization of counter failed");
}

#[test]
fn test_increment_counter() {
    let initial_value = 5;
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let user: ContractAddress = 'user'.try_into().unwrap();
    let dispatcher = deploy_counter(initial_value, owner);
    let mut spy = spy_events();

    start_cheat_caller_address(dispatcher.contract_address, user);
    dispatcher.increment_counter();
    stop_cheat_caller_address(dispatcher.contract_address);

    let current_counter_value = dispatcher.get_counter();
    let expected_counter_value = initial_value + 1;
    assert!(current_counter_value == expected_counter_value, "Increasing counter failed");

    let expected_event: CounterChanged = CounterChanged {
        caller: user,
        old_value: initial_value,
        new_value: initial_value + 1,
        reason: ChangeReason::Increment,
    };
    spy.assert_emitted(@array![(
        dispatcher.contract_address,
        Event::CounterChanged(expected_event)
    )]);
}

#[test]
fn test_decrement_counter_happy() {
    let initial_value = 5;
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let user: ContractAddress = 'user'.try_into().unwrap();
    let dispatcher = deploy_counter(initial_value, owner);
    let mut spy = spy_events();
    
    start_cheat_caller_address(dispatcher.contract_address, user);
    dispatcher.decrement_counter();
    stop_cheat_caller_address(dispatcher.contract_address);

    let current_counter_value = dispatcher.get_counter();
    let expected_counter_value = initial_value - 1;
    assert!(current_counter_value == expected_counter_value, "Decreasing counter failed");

    let expected_event: CounterChanged = CounterChanged {
        caller: user,
        old_value: initial_value,
        new_value: initial_value - 1,
        reason: ChangeReason::Decrement,
    };
    spy.assert_emitted(@array![(
        dispatcher.contract_address,
        Event::CounterChanged(expected_event)
    )]);
}

#[test]
#[should_panic(expected: "Cannot decrement counter")]
fn test_decrement_counter_unhappy() {
    let initial_value = 0;
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let dispatcher = deploy_counter(initial_value, owner);
    dispatcher.decrement_counter();
}