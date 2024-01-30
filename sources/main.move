/*
Disclaimer: Use of Unaudited Code for Educational Purposes Only
This code is provided strictly for educational purposes and has not undergone any formal security audit. 
It may contain errors, vulnerabilities, or other issues that could pose risks to the integrity of your system or data.

By using this code, you acknowledge and agree that:
    - No Warranty: The code is provided "as is" without any warranty of any kind, either express or implied. The entire risk as to the quality and performance of the code is with you.
    - Educational Use Only: This code is intended solely for educational and learning purposes. It is not intended for use in any mission-critical or production systems.
    - No Liability: In no event shall the authors or copyright holders be liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, out of, or in connection with the use or performance of this code.
    - Security Risks: The code may not have been tested for security vulnerabilities. It is your responsibility to conduct a thorough security review before using this code in any sensitive or production environment.
    - No Support: The authors of this code may not provide any support, assistance, or updates. You are using the code at your own risk and discretion.

Before using this code, it is recommended to consult with a qualified professional and perform a comprehensive security assessment. By proceeding to use this code, you agree to assume all associated risks and responsibilities.
*/

module bank::bc_coin {
    use sui::coin::{Coin, TreasuryCap, Self};
    use std::option;
    use sui::transfer;
    use sui::tx_context::{TxContext, Self};


    /// Transferrable object for storing the vesting coins
    struct Account has key, store {
        id: UID,
        create_date: u64,
        updated_date: u64,
        current_balance: Balance<LOCKED_COIN>

    }

    struct BC_COIN has drop {}

    #[allow(unused_function)]
    fun init(witness: BC_COIN, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(witness, 6, b"BC_COIN", b"", b"", option::none(), ctx);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx))
    }

    // public entry fun mint(
    //     treasury_cap: &mut TreasuryCap<BC_COIN>, amount: u64, recipient: address, ctx: &mut TxContext
    // ) {
    //     coin::mint_and_transfer(treasury_cap, amount, recipient, ctx)
    // }

    /// Mints and transfers a locker object with the input amount of coins and specified vesting schedule
    public fun locked_mint(treasury_cap: &mut TreasuryCap<LOCKED_COIN>, recipient: address, amount: u64, clock: &Clock, ctx: &mut TxContext){
        
        let coin = coin::mint(treasury_cap, amount, ctx);
        let current_date = clock::timestamp_ms(clock);

        transfer::public_transfer(Account {
            id: object::new(ctx),
            create_date: current_date,
            updated_date: current_date,
            original_balance: amount,
            current_balance: coin::into_balance(coin)
        }, recipient);
    }

    // public entry fun burn(treasury_cap: &mut TreasuryCap<BC_COIN>, coin: Coin<BC_COIN>) {
    //     coin::burn(treasury_cap, coin);
    // }
}
