module admin::commemorative{
    //==============================================================================================
    // Dependencies
    //==============================================================================================

    use std::object;
    use std::signer;
    use aptos_token_objects::token;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::{AptosCoin};
    use std::string::{Self, String};
    use aptos_token_objects::collection;
    use aptos_framework::timestamp;
    use aptos_framework::option;
    use std::string_utils;
    use std::vector;
    //use std::debug;

    #[test_only]
    use aptos_token_objects::royalty;

    //==============================================================================================
    // Errors
    //==============================================================================================

    const ERROR_SIGNER_NOT_ADMIN: u64 = 0;
    const ERROR_SUPPLY_EXCEEDED: u64 = 1;
    const ERROR_SIGNER_NOT_OPERATOR: u64 = 2;
    const ERROR_OTHERS: u64 = 4;

    //==============================================================================================
    // Constants
    //==============================================================================================

    // Seed for resource account creation
    const SEED: vector<u8> = b"netsepiogo";

    // Supply limit
    const SUPPLY: u64 = 500;

    // NFT collection information
    const COLLECTION_NAME: vector<u8> = b"Beta test NFT";
    const COLLECTION_DESCRIPTION: vector<u8> = b"Commemorative collection";
    const COLLECTION_URI: vector<u8> = b"NFT collection uri";

    // Token information
    const TOKEN_DESCRIPTION: vector<u8> = b"NFT token description";

    //==============================================================================================
    // Module Structs
    //==============================================================================================

    struct NftToken has key {
        // Used for editing the token data
        mutator_ref: token::MutatorRef,
        // Used for burning the token
        burn_ref: token::BurnRef,
        // Used for transfering the token
        transfer_ref: object::TransferRef
    }

    struct State has key {
        // signer cap of the module's resource account
        signer_cap: SignerCapability,
        // NFT count
        minted: u64,
        // minted_nft_obj_add
        nft_list: vector<address>,
        // Events
        nft_minted_events: EventHandle<NftMintedEvent>
    }
    //==============================================================================================
    // Event structs
    //==============================================================================================

    struct NftMintedEvent has store, drop {
        // minter
        user: address,
        // nft #
        nft_no: u64,
        // nft object address
        obj_add: address,
        // timestamp
        timestamp: u64
    }

    //==============================================================================================
    // Functions
    //==============================================================================================

    /*
        Initializes the module by creating a resource account, registering with AptosCoin, creating
        the token collectiions, and setting up the State resource.
        @param account - signer representing the module publisher
    */
    fun init_module(admin: &signer) {
        assert_admin(signer::address_of(admin));
        let (resource_signer, resource_cap) = account::create_resource_account(admin, SEED);

        coin::register<AptosCoin>(&resource_signer);

        // Create an NFT collection with an unlimied supply and the following aspects:
        collection::create_fixed_collection(
            &resource_signer,
            string::utf8(COLLECTION_DESCRIPTION),
            SUPPLY,
            string::utf8(COLLECTION_NAME),
            option::none(),
            string::utf8(COLLECTION_URI)
        );

        // Create the State global resource and move it to the admin account
        let state = State{
            signer_cap: resource_cap,
            minted: 0,
            nft_list: vector::empty(),
            nft_minted_events: account::new_event_handle<NftMintedEvent>(&resource_signer)
        };
        move_to<State>(admin, state);
    }

    public entry fun user_mint_NFT(minter: &signer, nft_uri: String) acquires State{
        let user_add = signer::address_of(minter);
        mint_internal(user_add, nft_uri);
    }

    public entry fun delegate_mint_NFT(operator: &signer, minter: address, nft_uri: String) acquires State{
        assert_operator(admin::reviews::check_role(signer::address_of(operator)));
        mint_internal(minter, nft_uri);
    }

    //==============================================================================================
    // Helper functions
    //==============================================================================================

    inline fun mint_internal(user: address, nft_uri: String){
        let state = borrow_global_mut<State>(@admin);
        assert_supply_not_exceeded(state.minted);
        let current_nft = state.minted + 1;
        let res_signer = account::create_signer_with_capability(&state.signer_cap);
        // Create a new named token:
        let token_const_ref = token::create_named_token(
            &res_signer,
            string::utf8(COLLECTION_NAME),
            string::utf8(TOKEN_DESCRIPTION),
            string_utils::format2(&b"{}#{}", string::utf8(b"nft"), string_utils::to_string_with_integer_types(&current_nft)),
            option::none(),
            nft_uri
        );

        let obj_signer = object::generate_signer(&token_const_ref);
        let obj_add = object::address_from_constructor_ref(&token_const_ref);

        // Transfer the token to the reviewer account
        object::transfer_raw(&res_signer, obj_add, user);

        // Create the ReviewToken object and move it to the new token object signer
        let new_nft_token = NftToken {
            mutator_ref: token::generate_mutator_ref(&token_const_ref),
            burn_ref: token::generate_burn_ref(&token_const_ref),
            transfer_ref: object::generate_transfer_ref(&token_const_ref),
        };

        move_to<NftToken>(&obj_signer, new_nft_token);

        state.minted = current_nft;
        vector::push_back(&mut state.nft_list, obj_add);

        // Emit a new NftMintedEvent
        event::emit_event<NftMintedEvent>(
            &mut state.nft_minted_events,
            NftMintedEvent {
                user,
                nft_no: current_nft,
                obj_add,
                timestamp: timestamp::now_seconds()
            });
    }

    #[view]
    public fun total_minted_NFTs(): u64 acquires State {
        let state = borrow_global<State>(@admin);
        state.minted
    }

    //==============================================================================================
    // Validation functions
    //==============================================================================================

    inline fun assert_admin(admin: address) {
        assert!(admin == @admin, ERROR_SIGNER_NOT_ADMIN);
    }

    inline fun assert_operator(check_role_return: String) {
        assert!(check_role_return == string::utf8(b"operator") , ERROR_SIGNER_NOT_OPERATOR);
    }

    inline fun assert_supply_not_exceeded(minted: u64) {
        assert!(minted < SUPPLY, ERROR_SUPPLY_EXCEEDED);
    }

    //==============================================================================================
    // Test functions
    //==============================================================================================

    #[test(admin = @admin)]
    fun test_init_module_success(
        admin: &signer
    ) acquires State {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let expected_resource_account_address = account::create_resource_address(&admin_address, SEED);
        assert!(account::exists_at(expected_resource_account_address), 0);

        let state = borrow_global<State>(admin_address);
        assert!(
            account::get_signer_capability_address(&state.signer_cap) == expected_resource_account_address,
            0
        );

        assert!(
            coin::is_account_registered<AptosCoin>(expected_resource_account_address),
            4
        );

        let expected_collection_address = collection::create_collection_address(
            &expected_resource_account_address,
            &string::utf8(b"Beta test NFT")
        );
        let collection_object = object::address_to_object<collection::Collection>(expected_collection_address);
        assert!(
            collection::creator<collection::Collection>(collection_object) == expected_resource_account_address,
            4
        );
        assert!(
            collection::name<collection::Collection>(collection_object) == string::utf8(b"Beta test NFT"),
            4
        );
        assert!(
            collection::description<collection::Collection>(collection_object) == string::utf8(b"Commemorative collection"),
            4
        );
        assert!(
            collection::uri<collection::Collection>(collection_object) == string::utf8(b"NFT collection uri"),
            4
        );

        assert!(event::counter(&state.nft_minted_events) == 0, 4);
    }

    #[test(admin = @admin, user = @0xA)]
    fun test_mint_success(
        admin: &signer,
        user: &signer
    ) acquires State {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let image_uri = string::utf8(b"QmSYRXWGGqVDAHKTwfnYQDR74d4bfwXxudFosbGA695AWS");

        let resource_account_address = account::create_resource_address(&@admin, SEED);

        user_mint_NFT(user, image_uri);

        let state = borrow_global<State>(admin_address);

        let expected_nft_token_address = token::create_token_address(
            &resource_account_address,
            &string::utf8(b"Beta test NFT"),
            &string_utils::format2(&b"{}#{}", string::utf8(b"nft"), string_utils::to_string_with_integer_types(&state.minted))
        );
        let nft_token_object = object::address_to_object<token::Token>(expected_nft_token_address);
        assert!(
            object::is_owner(nft_token_object, user_address) == true,
            1
        );
        assert!(
            token::creator(nft_token_object) == resource_account_address,
            4
        );
        assert!(
            token::name(nft_token_object) == string_utils::format2(&b"{}#{}", string::utf8(b"nft"), string_utils::to_string_with_integer_types(&state.minted)),
            4
        );
        assert!(
            token::description(nft_token_object) == string::utf8(b"NFT token description"),
            4
        );
        assert!(
            token::uri(nft_token_object) == image_uri,
            4
        );
        assert!(
            option::is_none<royalty::Royalty>(&token::royalty(nft_token_object)),
            4
        );
        assert!(
            vector::contains(&state.nft_list, &expected_nft_token_address),
            4
        );

        assert!(event::counter(&state.nft_minted_events) == 1, 4);

    }

    #[test(admin = @admin, user = @0xA)]
    #[expected_failure(abort_code = ERROR_SUPPLY_EXCEEDED)]
    fun test_mint_failed(
        admin: &signer,
        user: &signer
    ) acquires State {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let image_uri = string::utf8(b"QmSYRXWGGqVDAHKTwfnYQDR74d4bfwXxudFosbGA695AWS");

        {
            let state = borrow_global_mut<State>(admin_address);
            state.minted = 500;
        };

        user_mint_NFT(user, image_uri);
    }

    #[test(admin = @admin, user = @0xA, operator = @0xB)]
    fun test_delegate_mint_success(
        admin: &signer,
        operator: &signer,
        user: &signer
    ) acquires State {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        admin::reviews::init_module_for_test(admin);
        init_module(admin);

        admin::reviews::grant_role(
            admin,
            signer::address_of(operator),
            string::utf8(b"operator")
        );

        let image_uri = string::utf8(b"QmSYRXWGGqVDAHKTwfnYQDR74d4bfwXxudFosbGA695AWS");

        let resource_account_address = account::create_resource_address(&@admin, SEED);

        delegate_mint_NFT(operator, user_address, image_uri);

        let state = borrow_global<State>(admin_address);

        let expected_nft_token_address = token::create_token_address(
            &resource_account_address,
            &string::utf8(b"Beta test NFT"),
            &string_utils::format2(&b"{}#{}", string::utf8(b"nft"), string_utils::to_string_with_integer_types(&state.minted))
        );
        let nft_token_object = object::address_to_object<token::Token>(expected_nft_token_address);
        assert!(
            object::is_owner(nft_token_object, user_address) == true,
            1
        );
        assert!(
            token::creator(nft_token_object) == resource_account_address,
            4
        );
        assert!(
            token::name(nft_token_object) == string_utils::format2(&b"{}#{}", string::utf8(b"nft"), string_utils::to_string_with_integer_types(&state.minted)),
            4
        );
        assert!(
            token::description(nft_token_object) == string::utf8(b"NFT token description"),
            4
        );
        assert!(
            token::uri(nft_token_object) == image_uri,
            4
        );
        assert!(
            option::is_none<royalty::Royalty>(&token::royalty(nft_token_object)),
            4
        );
        assert!(
            vector::contains(&state.nft_list, &expected_nft_token_address),
            4
        );

        assert!(event::counter(&state.nft_minted_events) == 1, 4);
    }

    #[test(admin = @admin, user = @0xA, operator = @0xB)]
    #[expected_failure(abort_code = ERROR_SIGNER_NOT_OPERATOR)]
    fun test_delegate_mint_failure_not_operator(
        admin: &signer,
        operator: &signer,
        user: &signer
    ) acquires State {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        admin::reviews::init_module_for_test(admin);
        init_module(admin);

        let image_uri = string::utf8(b"QmSYRXWGGqVDAHKTwfnYQDR74d4bfwXxudFosbGA695AWS");

        delegate_mint_NFT(operator, user_address, image_uri);
    }

}