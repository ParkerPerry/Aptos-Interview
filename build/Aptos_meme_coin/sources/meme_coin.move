module 0xfb96ca518d16ccf812c5bac6ca27f5c45b4e3a358e376cfb14f29c5a88a4d86c::meme_coin {
    use std::signer;
    use std::timestamp;
    use aptos_std::table;
    use aptos_framework::managed_coin;
    use aptos_framework::coin;

    const DECIMALS: u8 = 6;
    const CLAIM_AMOUNT: u64 = 100_000_000; // 100.000000 tokens
    const CLAIM_DURATION_SECS: u64 = 86400; // 1 day

    struct CoinInfo has store {}

    struct Whitelist has key {
        addresses: table::Table<address, bool>
    }

    struct ClaimConfig has key {
        end_time: u64
    }

    /// Initialize the coin, whitelist, and config with embedded end_time
    public entry fun initialize(admin: &signer) {
        managed_coin::initialize<CoinInfo>(
            admin,
            b"Intergalactic Creatures",
            b"IGC",
            DECIMALS,
            false
        );

        let now = timestamp::now_seconds();

        move_to(admin, Whitelist {
            addresses: table::new()
        });

        move_to(admin, ClaimConfig {
            end_time: now + CLAIM_DURATION_SECS
        });
    }

    /// Add a user to the whitelist
    public entry fun add_to_whitelist(admin: &signer, user: address) acquires Whitelist {
        let whitelist = borrow_global_mut<Whitelist>(signer::address_of(admin));
        table::add(&mut whitelist.addresses, user, true);
    }

    /// Admin executes a claim on behalf of a whitelisted user
    public entry fun claim(admin: &signer, user: address) acquires Whitelist, ClaimConfig {
        let admin_address = signer::address_of(admin);

        let config = borrow_global<ClaimConfig>(admin_address);
        assert!(timestamp::now_seconds() < config.end_time, 1);

        let whitelist = borrow_global_mut<Whitelist>(admin_address);
        let is_whitelisted = table::remove(&mut whitelist.addresses, user);
        assert!(is_whitelisted, 2);

        managed_coin::mint<CoinInfo>(admin, user, CLAIM_AMOUNT);
    }

    #[view]
    public fun get_igc_balance(account: address): u64 {
        coin::balance<0xfb96ca518d16ccf812c5bac6ca27f5c45b4e3a358e376cfb14f29c5a88a4d86c::meme_coin::CoinInfo>(account)
    }
}