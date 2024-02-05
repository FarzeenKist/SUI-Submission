#[allow(unused_use)]
module bank::bank {
    use sui::dynamic_object_field as ofield;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, ID, UID};
    use sui::coin::{Self, Coin};
    use sui::bag::{Bag, Self};
    use sui::table::{Table, Self};
    use sui::transfer;
    use sui::clock::{Self, Clock};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;

    /// For when amount paid does not match the expected.
    const EAmountIncorrect: u64 = 0;
    /// For when someone tries to delist without ownership.
    const ENotOwner: u64 = 1;


    struct Bank<phantom COIN> has key {
        id: UID,
        accounts: Bag,
        bank_address: address
    }

    struct Account has key, store {
        id: UID,
        create_date: u64,
        updated_date: u64,
        current_balance: Balance<SUI>,
        account_address: address
    }

    /// Create a new shared Bank.
    public fun create_bank<COIN>(ctx: &mut TxContext) {
        let id = object::new(ctx);
        let accounts = bag::new(ctx);
        transfer::share_object(Bank<COIN> { 
            id, 
            accounts,
            bank_address: tx_context::sender(ctx)
        })
    }

    public fun create_account<T: key + store, COIN>(
        bank: &mut Bank<COIN>,
        acc: T,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let account_id = object::id(&acc);
        let account = Account {
            id: object::new(ctx),
            create_date: clock::timestamp_ms(clock),
            updated_date: clock::timestamp_ms(clock),
            current_balance: balance::zero(),
            account_address: tx_context::sender(ctx)
        };

        bag::add(&mut bank.accounts, account_id, account)
    }


    // deposit function
    public fun deposit<COIN>(
            bank: &mut Bank<COIN>,
            account_id: ID,
            amount: Coin<SUI>, 
            clock: &Clock,
            ctx: &mut TxContext)
    {
        let Account{
            id,
            create_date,
            updated_date,
            current_balance,
            account_address
        } = bag::borrow_mut(&mut bank.accounts, account_id);
        assert!(&mut tx_context::sender(ctx) == account_address, ENotOwner);

        let deposit_amount = coin::balance(amount);
        public_transfer(amount, bank.bank_address);
        updated_date = &mut clock::timestamp_ms(clock);
        
        balance::join(current_balance, deposit_amount);
    }

}