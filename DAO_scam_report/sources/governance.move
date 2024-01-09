module admin::report_dao_v1{
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
    use aptos_std::simple_map;
    use aptos_std::simple_map::SimpleMap;
    //use std::debug;

    #[test_only]
    use aptos_token_objects::royalty;

    //==============================================================================================
    // Errors
    //==============================================================================================

    const ERROR_SIGNER_NOT_ADMIN: u64 = 0;
    const ERROR_SIGNER_NOT_OPERATOR: u64 = 1;
    const ERROR_PROPOSAL_ALREADY_EXISTS: u64 = 2;
    const ERROR_PROPOSAL_DOES_NOT_EXIST: u64 = 3;
    const ERROR_PROPOSAL_ALREADY_CLOSED: u64 = 4;
    const ERROR_OTHERS: u64 = 5;

    //==============================================================================================
    // Constants
    //==============================================================================================

    // Seed for resource account creation
    const SEED: vector<u8> = b"dao";


    // NFT collection information
    const COLLECTION_DESCRIPTION: vector<u8> = b"Scam Report DAO Proposals";

    const NEW_COLLECTION_NAME: vector<u8> = b"Report Proposals";
    const NEW_COLLECTION_URI: vector<u8> = b"New collection uri";

    const RESOLVED_COLLECTION_NAME: vector<u8> = b"Resolved Proposals";
    const RESOLVED_COLLECTION_URI: vector<u8> = b"Resolved collection uri";

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
        //metadata, proposal_nft_obj_add
        metadatas: SimpleMap<String, address>,
        // proposal_nft_obj_add, true for resolved, false for open
        proposal_list: SimpleMap<address, bool>,
        // Events
        proposal_created_events: EventHandle<ProposalCreatedEvent>,
        proposal_resolved_events: EventHandle<ProposalResolvedEvent>,
        proposal_deleted_events: EventHandle<ProposalDeletedEvent>
    }
    //==============================================================================================
    // Event structs
    //==============================================================================================

    struct ProposalCreatedEvent has store, drop {
        // proposer
        user: address,
        // proposal #
        proposal_no: u64,
        // prpoposal nft object address
        obj_add: address,
        // timestamp
        timestamp: u64
    }

    struct ProposalResolvedEvent has store, drop {
        // resolver
        user: address,
        // prpoposal nft object address
        obj_add: address,
        // timestamp
        timestamp: u64
    }

    struct ProposalDeletedEvent has store, drop {
        // deleter
        user: address,
        // prpoposal nft object address
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

        // Create an NFT collection with an unlimited supply and the following aspects:
        collection::create_unlimited_collection(
            &resource_signer,
            string::utf8(COLLECTION_DESCRIPTION),
            string::utf8(NEW_COLLECTION_NAME),
            option::none(),
            string::utf8(NEW_COLLECTION_URI)
        );

        collection::create_unlimited_collection(
            &resource_signer,
            string::utf8(COLLECTION_DESCRIPTION),
            string::utf8(RESOLVED_COLLECTION_NAME),
            option::none(),
            string::utf8(RESOLVED_COLLECTION_URI)
        );

        // Create the State global resource and move it to the admin account
        let state = State{
            signer_cap: resource_cap,
            minted: 0,
            metadatas: simple_map::create(),
            proposal_list: simple_map::create(),
            proposal_created_events: account::new_event_handle<ProposalCreatedEvent>(&resource_signer),
            proposal_resolved_events: account::new_event_handle<ProposalResolvedEvent>(&resource_signer),
            proposal_deleted_events: account::new_event_handle<ProposalDeletedEvent>(&resource_signer)
        };
        move_to<State>(admin, state);
    }

    public entry fun submit_proposal(operator: &signer, proposer: address, metadata: String) acquires State{
        assert_operator(admin::reviews::check_role(signer::address_of(operator)));
        let state = borrow_global_mut<State>(@admin);
        assert_proposal_does_not_already_exists(state.metadatas, metadata);
        let current_proposal = state.minted + 1;
        let res_signer = account::create_signer_with_capability(&state.signer_cap);
        // Create a new named token:
        let token_const_ref = token::create_named_token(
            &res_signer,
            string::utf8(NEW_COLLECTION_NAME),
            metadata,
            string_utils::format2(&b"{}#{}", string::utf8(b"proposal"), string_utils::to_string_with_integer_types(&current_proposal)),
            option::none(),
            string::utf8(NEW_COLLECTION_URI)
        );

        let obj_signer = object::generate_signer(&token_const_ref);
        let obj_add = object::address_from_constructor_ref(&token_const_ref);

        // Transfer the token to the reviewer account
        object::transfer_raw(&res_signer, object::address_from_constructor_ref(&token_const_ref), proposer);

        // Create the ReviewToken object and move it to the new token object signer
        let new_nft_token = NftToken {
            mutator_ref: token::generate_mutator_ref(&token_const_ref),
            burn_ref: token::generate_burn_ref(&token_const_ref),
            transfer_ref: object::generate_transfer_ref(&token_const_ref),
        };

        move_to<NftToken>(&obj_signer, new_nft_token);

        state.minted = current_proposal;
        simple_map::add(&mut state.metadatas, metadata, obj_add);
        simple_map::add(&mut state.proposal_list, obj_add, false);

        //block transfer between normal users
        object::disable_ungated_transfer(&object::generate_transfer_ref(&token_const_ref));

        // Emit a new ProposalCreatedEvent
        event::emit_event<ProposalCreatedEvent>(
            &mut state.proposal_created_events,
            ProposalCreatedEvent {
                user: proposer,
                proposal_no: current_proposal,
                obj_add,
                timestamp: timestamp::now_seconds()
            });
    }

    public entry fun resolve_proposal(operator: &signer, old_metadata: String, new_metadata: String) acquires State, NftToken{
        assert_operator(admin::reviews::check_role(signer::address_of(operator)));
        let obj_add;
        {
            let state = borrow_global<State>(@admin);
            assert_proposal_exists(state.metadatas, old_metadata);
            obj_add = *simple_map::borrow(&state.metadatas, &old_metadata);
            assert_proposal_is_open(state.proposal_list, obj_add);
        };
        let token_obj = object::address_to_object<NftToken>(obj_add);
        let token_name = token::name(token_obj);
        let token_owner = object::owner(token_obj);

        {
            burn_token_internal(old_metadata, obj_add);
        };

        let state = borrow_global_mut<State>(@admin);
        let res_signer = account::create_signer_with_capability(&state.signer_cap);

        // Create a new named token:
        let token_const_ref = token::create_named_token(
            &res_signer,
            string::utf8(RESOLVED_COLLECTION_NAME),
            new_metadata,
            token_name,
            option::none(),
            string::utf8(RESOLVED_COLLECTION_URI)
        );

        let obj_signer = object::generate_signer(&token_const_ref);
        let new_obj_add = object::address_from_constructor_ref(&token_const_ref);

        // Transfer the token to the reviewer account
        object::transfer_raw(&res_signer, object::address_from_constructor_ref(&token_const_ref), token_owner);

        // Create the ReviewToken object and move it to the new token object signer
        let new_nft_token = NftToken {
            mutator_ref: token::generate_mutator_ref(&token_const_ref),
            burn_ref: token::generate_burn_ref(&token_const_ref),
            transfer_ref: object::generate_transfer_ref(&token_const_ref),
        };

        move_to<NftToken>(&obj_signer, new_nft_token);

        simple_map::add(&mut state.metadatas, new_metadata, new_obj_add);
        simple_map::add(&mut state.proposal_list, new_obj_add, true);

        //block transfer between normal users
        object::disable_ungated_transfer(&object::generate_transfer_ref(&token_const_ref));

        // Emit a new ProposalCreatedEvent
        event::emit_event<ProposalResolvedEvent>(
            &mut state.proposal_resolved_events,
            ProposalResolvedEvent {
                user: signer::address_of(operator),
                obj_add,
                timestamp: timestamp::now_seconds()
            });
    }

    public entry fun delete_proposal(operator: &signer, metadata: String) acquires State, NftToken{
        assert_operator(admin::reviews::check_role(signer::address_of(operator)));
        let obj_add;
        {
            let state = borrow_global<State>(@admin);
            assert_proposal_exists(state.metadatas, metadata);
            obj_add = *simple_map::borrow(& state.metadatas, &metadata);
            assert_proposal_is_open(state.proposal_list, obj_add);
        };

        {
            burn_token_internal(metadata, obj_add);
        };

        let state = borrow_global_mut<State>(@admin);
        // Emit a new ProposalCreatedEvent
        event::emit_event<ProposalDeletedEvent>(
            &mut state.proposal_deleted_events,
            ProposalDeletedEvent {
                user: signer::address_of(operator),
                obj_add,
                timestamp: timestamp::now_seconds()
            });
    }

    //==============================================================================================
    // Helper functions
    //==============================================================================================

    inline fun burn_token_internal(metdata: String, obj_add: address) {
        let state = borrow_global_mut<State>(@admin);
        let review_token = move_from<NftToken>(obj_add);
        let NftToken{mutator_ref: _, burn_ref, transfer_ref: _} = review_token;

        // Burn the the token
        token::burn(burn_ref);
        simple_map::remove(&mut state.metadatas, &metdata);
        simple_map::remove(&mut state.proposal_list, &obj_add);
    }

    #[view]
    public fun total_proposals(): u64 acquires State {
        let state = borrow_global<State>(@admin);
        state.minted
    }

    #[view]
    public fun view_nft_address(metadata: String): address acquires State {
        let state = borrow_global<State>(@admin);
        *simple_map::borrow(&state.metadatas, &metadata)
    }

    #[view]
    public fun is_proposal_open(metadata: String): bool acquires State {
        let state = borrow_global<State>(@admin);
        let obj_add = *simple_map::borrow(&state.metadatas, &metadata);
        !*simple_map::borrow(&state.proposal_list, &obj_add)
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

    inline fun assert_proposal_does_not_already_exists(metadatas: SimpleMap<String, address>, metadata: String) {
        assert!(!simple_map::contains_key(&metadatas, &metadata), ERROR_PROPOSAL_ALREADY_EXISTS);
    }

    inline fun assert_proposal_exists(metadatas: SimpleMap<String, address>, metadata: String) {
        assert!(simple_map::contains_key(&metadatas, &metadata), ERROR_PROPOSAL_DOES_NOT_EXIST);
    }

    inline fun assert_proposal_is_open(proposals: SimpleMap<address,bool>, obj_add: address) {
        assert!(!*simple_map::borrow(&proposals, &obj_add), ERROR_PROPOSAL_ALREADY_CLOSED);
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
            &string::utf8(b"Report Proposals")
        );
        let collection_object = object::address_to_object<collection::Collection>(expected_collection_address);
        assert!(
            collection::creator<collection::Collection>(collection_object) == expected_resource_account_address,
            4
        );
        assert!(
            collection::name<collection::Collection>(collection_object) == string::utf8(b"Report Proposals"),
            4
        );
        assert!(
            collection::description<collection::Collection>(collection_object) == string::utf8(b"Scam Report DAO Proposals"),
            4
        );
        assert!(
            collection::uri<collection::Collection>(collection_object) == string::utf8(b"New collection uri"),
            4
        );

        assert!(event::counter(&state.proposal_created_events) == 0, 5);
    }

    #[test(admin = @admin, operator = @0xA, user = @0xB)]
    fun test_delegate_mint_success(
        admin: &signer,
        operator: &signer,
        user: &signer,
    ) acquires State {
        let admin_address = signer::address_of(admin);
        let operator_address = signer::address_of(operator);
        let user_address = signer::address_of(user);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(operator_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        admin::reviews::init_module_for_test(admin);
        init_module(admin);

        admin::reviews::grant_role(
            admin,
            operator_address,
            string::utf8(b"operator")
        );

        let metadata = string::utf8(b"QmSYRXWGGqVDAHKTwfnYQDR74d4bfwXxudFosbGA695AWS");

        let resource_account_address = account::create_resource_address(&@admin, SEED);

        submit_proposal(operator, user_address, metadata);

        let state = borrow_global<State>(admin_address);

        let expected_nft_token_address = token::create_token_address(
            &resource_account_address,
            &string::utf8(b"Report Proposals"),
            &string_utils::format2(&b"{}#{}", string::utf8(b"proposal"), string_utils::to_string_with_integer_types(&state.minted))
        );
        let nft_token_object = object::address_to_object<token::Token>(expected_nft_token_address);
        assert!(
            object::is_owner(nft_token_object, user_address) == true,
            5
        );
        assert!(
            token::creator(nft_token_object) == resource_account_address,
            5
        );
        assert!(
            token::name(nft_token_object) == string_utils::format2(&b"{}#{}", string::utf8(b"proposal"), string_utils::to_string_with_integer_types(&state.minted)),
            5
        );
        assert!(
            token::description(nft_token_object) == metadata,
            5
        );
        assert!(
            token::uri(nft_token_object) == string::utf8(b"New collection uri"),
            5
        );
        assert!(
            option::is_none<royalty::Royalty>(&token::royalty(nft_token_object)),
            5
        );
        assert!(
            simple_map::contains_key(&state.proposal_list, &expected_nft_token_address),
            5
        );

        assert!(event::counter(&state.proposal_created_events) == 1, 5);
    }

    #[test(admin = @admin, user = @0xA)]
    #[expected_failure(abort_code = ERROR_SIGNER_NOT_OPERATOR)]
    fun test_delegate_mint_failure_not_operator(
        admin: &signer,
        user: &signer,
    ) acquires State {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        admin::reviews::init_module_for_test(admin);
        init_module(admin);

        let metadata = string::utf8(b"QmSYRXWGGqVDAHKTwfnYQDR74d4bfwXxudFosbGA695AWS");

        submit_proposal(admin, user_address, metadata);
    }

}
