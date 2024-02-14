
#[allow(lint(self_transfer))]
module bank::bank {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, ID, UID};
    use sui::coin::{Self, Coin};
    use sui::table::{Table, Self};
    use sui::transfer;
    use sui::clock::{Self, Clock};
    use std::string::{Self, String};
    use std::vector;
    use std::option::{Option, none, some, borrow, contains};


    /// For when someone tries to interact with account specific functions without an account
    const ENoAccount: u64 = 0;
    // For when the balance of an amount is less than the amount specified
    const EInsufficientBalance: u64 = 1;

    // Type that stores the following data for a transaction:
    // 1. transactionType: type of the transaction. Currently, can only be either deposit, transfer or withdraw
    // 2. Amount: the COIN amount
    struct Transaction has store, copy {
        transactionType: String,
        amount: u64,
        to: Option<address>,
        from: Option<address>

    }

    // Type that stores the following data for an account:
    // 1. id: ObjectId of the account
    // 2. create_date: The timestamp of the creation time for the account
    // 3. updated_date: The timestamp of the last updated time for the account,
    // 4. current_balance: The account's current Coin<COIN> balance,
    // 5. account_address: The address associated with the account,
    // 6. transactions: A vector storing the transaction history of the account
    struct Account<phantom COIN> has key, store {
        id: UID,
        create_date: u64,
        updated_date: u64,
        current_balance: Coin<COIN>,
        account_address: address,
        transactions: vector<Transaction>
    }

    // Type that stores the following data for a bank:
    // 1. id: ObjectId of the bank
    // 2. accounts: A table storing all the accounts associated with a bank
    // 3. bank_address: The address associated with a bank
    struct Bank<phantom COIN> has key {
        id: UID,
        accounts: Table<address, Account<COIN>>,
        bank_address: address
    }


    /// Create a new shared Bank.
    public fun create_bank<COIN>(ctx: &mut TxContext) {
        let id = object::new(ctx);
        let accounts = table::new<address, Account<COIN>>(ctx);
        // let transactions = table::new<address, vector<Transaction>>(ctx);
        // create and initialize bank with the specified COIN
        transfer::share_object(Bank<COIN> { 
            id, 
            accounts,
            bank_address: tx_context::sender(ctx)
        })
    }

    // Create a new account in a Bank.
    public fun create_account<COIN>(
        bank: &mut Bank<COIN>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let account = Account {
            id: object::new(ctx),
            create_date: clock::timestamp_ms(clock),
            updated_date: 0,
            current_balance: coin::zero(ctx),
            account_address: tx_context::sender(ctx),
            transactions: vector::empty<Transaction>()
        };
        // save account to the bank
        table::add(&mut bank.accounts, tx_context::sender(ctx), account)
    }


    // Deposit COIN into the sender's account for a bank
    public fun deposit<COIN>(
        bank: &mut Bank<COIN>,
        clock: &Clock,
        amount: Coin<COIN>,
        ctx: &mut TxContext
    )
    {   // sender must have an account for the bank
        assert!(table::contains<address, Account<COIN>>(&bank.accounts, tx_context::sender(ctx)), ENoAccount);
        let account = table::borrow_mut<address, Account<COIN>>(&mut bank.accounts, tx_context::sender(ctx));
        // create a deposit transaction to store in the transactions vector
        let transaction = Transaction {
            transactionType: string::utf8(b"deposit"),
            amount: coin::value(&amount),
            to: none(),
            from: none()
        };
        // add COIN to the account's current_balance and update the other respective fields
        coin::join(
            &mut account.current_balance,
            amount
        );
        account.updated_date = clock::timestamp_ms(clock);
        vector::push_back(&mut account.transactions, transaction);
    }
    // Transfer COIN amount between two accounts in a bank
    public fun transfer<COIN>(
        bank: &mut Bank<COIN>,
        clock: &Clock,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    )
    {
        assert!(table::contains<address, Account<COIN>>(&bank.accounts, tx_context::sender(ctx)), ENoAccount);
        assert!(table::contains<address, Account<COIN>>(&bank.accounts, recipient), ENoAccount);
        let sender_account = table::borrow_mut<address, Account<COIN>>(&mut bank.accounts, tx_context::sender(ctx));
        assert!(coin::value(&sender_account.current_balance) >= amount, EInsufficientBalance);
        sender_account.updated_date = clock::timestamp_ms(clock);
        // create a transfer transaction to store in the transactions vector for both the sender and recipient
        let transaction = Transaction {
            transactionType: string::utf8(b"transfer"),
            amount: amount,
            to: some(recipient),
            from: some(tx_context::sender(ctx))
        };
        vector::push_back(&mut sender_account.transactions, *&transaction);
        let transfer_coin = coin::split(
            &mut sender_account.current_balance,
            amount,
            ctx
        );
        let recipient_account = table::borrow_mut<address, Account<COIN>>(&mut bank.accounts, recipient);
        recipient_account.updated_date = clock::timestamp_ms(clock);
        vector::push_back(&mut recipient_account.transactions, transaction);
        coin::join(&mut recipient_account.current_balance, transfer_coin);
    }
    // Withdraw COIN amount from the sender's account in a bank
    public fun withdraw<COIN>(
        bank: &mut Bank<COIN>,
        clock: &Clock,
        amount: u64,
        ctx: &mut TxContext
    )
    {
        assert!(table::contains<address, Account<COIN>>(&bank.accounts, tx_context::sender(ctx)), ENoAccount);
        let account = table::borrow_mut<address, Account<COIN>>(&mut bank.accounts, tx_context::sender(ctx));
        assert!(coin::value(&account.current_balance) >= amount, EInsufficientBalance);
        // create a transfer transaction to store in the transactions vector for both the sender and recipient
        let transaction = Transaction {
            transactionType: string::utf8(b"withdraw"),
            amount: amount,
            to: none(),
            from: none()
        };
        vector::push_back(&mut account.transactions, transaction);
        account.updated_date = clock::timestamp_ms(clock);
        let transfer_coin = coin::split(
            &mut account.current_balance,
            amount,
            ctx
        );
        transfer::public_transfer(transfer_coin, tx_context::sender(ctx));
    }

    // public entry fun view_account<COIN>(bank: &Bank<COIN>, ctx: &mut TxContext): (u64, u64, u64, address, u64){
    //     let account = table::borrow<address, Account<COIN>>(&bank.accounts, tx_context::sender(ctx));
    //     (account.create_date,account.updated_date,coin::value(&account.current_balance),account.account_address,vector::length(&account.transactions))
    // }
    // public fun view_account_transactions<COIN>(bank: &Bank<COIN>, ctx: &mut TxContext): &vector<Transaction>{
    //     let account = table::borrow<address, Account<COIN>>(&bank.accounts, tx_context::sender(ctx));
    //     &account.transactions
    // }

}