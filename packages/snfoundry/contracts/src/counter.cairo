#[starknet::interface]
pub trait ICounter<T> {
    fn get_counter(self: @T) -> u32;
    fn increment_counter(ref self: T);
    fn decrement_counter(ref self: T);
    fn set_counter(ref self: T, value: u32);
    fn reset_counter(ref self: T);
}

#[starknet::contract]
pub mod CounterContract {
    use OwnableComponent::InternalTrait;
    use super::ICounter;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess}; 
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl InternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
       CounterChanged: CounterChanged,
       #[flat]
       OwnableEvent: OwnableComponent::Event,
    }
    
    #[derive(Drop, starknet::Event)]
    pub struct CounterChanged {
        #[key]
        pub caller: ContractAddress,
        pub old_value: u32,
        pub new_value: u32,
        pub reason: ChangeReason
    }
    
    #[derive(Drop, Copy, Serde)]
    pub enum ChangeReason {
        Increment,
        Decrement,
        Set,
        Reset
    }

    #[storage]
    struct Storage {
       counter: u32,
       #[substorage(v0)]
       ownable: OwnableComponent::Storage,
    } 
    
    #[constructor]
    fn constructor(ref self: ContractState, init_value: u32, owner: ContractAddress) {
        self.counter.write(init_value);
        self.ownable.initializer(owner);
    }
    
    #[abi(embed_v0)]
    impl CounterImpl of ICounter<ContractState> {
        
        fn get_counter(self: @ContractState) -> u32 {
            self.counter.read()
        }
        fn increment_counter(ref self: ContractState) {
            let current_counter_value = self.counter.read();
            let next_counter_value = current_counter_value + 1;
            self.counter.write(next_counter_value);

            let event: CounterChanged = CounterChanged {
                caller: get_caller_address(),
                old_value: current_counter_value,
                new_value: next_counter_value,
                reason: ChangeReason::Increment
            };
            self.emit(event);
        }
        fn decrement_counter(ref self: ContractState) {
            let current_counter_value = self.counter.read();
            assert!(current_counter_value > 0, "Cannot decrement counter");
            let next_counter_value = current_counter_value - 1;
            self.counter.write(next_counter_value);

            let event: CounterChanged = CounterChanged {
                caller: get_caller_address(),
                old_value: current_counter_value,
                new_value: next_counter_value,
                reason: ChangeReason::Decrement
            };
            self.emit(event);
        }
        fn set_counter(ref self: ContractState, value: u32) {
            self.ownable.assert_only_owner();
            let current_counter_value = self.counter.read();
            self.counter.write(value);

            let event: CounterChanged = CounterChanged {
                caller: get_caller_address(),
                old_value: current_counter_value,
                new_value: value,
                reason: ChangeReason::Set
            };
            self.emit(event);
        }
        
        fn reset_counter(ref self: ContractState) {
            let PAYMENT_AMOUNT: u256 = 1_000_000_000_000_000_000;
            let STRK_TOKEN: ContractAddress = 0x04718f5a0Fc34cC1AF16A1cdee98fFB20C31f5cD61D6Ab07201858f4287c938D.try_into().unwrap();
            let caller = get_caller_address();
            let contract = get_contract_address();
            let dispatcher = IERC20Dispatcher {contract_address: STRK_TOKEN};
            let balance = dispatcher.balance_of(caller);
            assert!(balance >= PAYMENT_AMOUNT, "Not enough balance");
            let allowance = dispatcher.allowance(caller, contract);
            assert!(allowance >= PAYMENT_AMOUNT, "Not enough allowance");
            
            let owner = self.ownable.owner();
            let success = dispatcher.transfer_from(caller, owner, PAYMENT_AMOUNT);
            assert!(success, "Transfer of token failed");

            let current_counter_value = self.counter.read();
            self.counter.write(0);
            let event: CounterChanged = CounterChanged {
                caller: get_caller_address(),
                old_value: current_counter_value,
                new_value: 0,
                reason: ChangeReason::Reset,
            };
            self.emit(event);

        }
        
    }
}