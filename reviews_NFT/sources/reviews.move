module admin::reviews{

    //==============================================================================================
    // Dependencies
    //==============================================================================================

    use std::object;
    use std::signer;
    use aptos_framework::option;
    use aptos_token_objects::token;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::account::{Self, SignerCapability};
    use std::string::{Self, String};
    use aptos_token_objects::collection;
    use aptos_framework::timestamp;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::{AptosCoin};
    use aptos_std::simple_map;
    use aptos_std::simple_map::SimpleMap;
    use std::bcs;
    use std::vector;
    use aptos_std::string_utils;

    #[test_only]
    use aptos_token_objects::royalty;

    //==============================================================================================
    // Errors
    //==============================================================================================

    const ERROR_SIGNER_NOT_ADMIN: u64 = 0;
    const ERROR_SIGNER_NOT_REVIEWER: u64 = 1;
    const ERROR_SIGNER_NOT_OPERATOR: u64 = 2;
    const ERROR_METADATA_DUPLICATED: u64 = 3;
    const ERROR_OTHERS: u64 = 4;
    const ERROR_REVIEW_DOES_NOT_EXIST: u64 = 5;
    const ERROR_USER_NO_ROLE: u64 = 6;
    const ERROR_USER_ALREADY_HAS_ROLE: u64 = 7;
    const ERROR_INVALID_ROLE_NAME: u64 = 8;
    const ERROR_NOT_REVIEW_OWNER: u64 = 9;

    //==============================================================================================
    // Constants
    //==============================================================================================

    // Contract Version
    const VERSION: u64 = 1;

    // Token collection information
    const COLLECTION_NAME: vector<u8> = b"NETSEPIO REVIEWS";
    const COLLECTION_DESCRIPTION: vector<u8> = b"Share your web3 insight on NetSepio";
    const COLLECTION_URI: vector<u8> = b"ipfs://bafybeiejnrheh6inrlkwrafytrpzyy4oqcxmxqqeclci4wmlostah2iw2q/collection_uri.png";

    // Token information
    const TOKEN_DESCRIPTION: vector<u8> = b"REVIEW NFT";


    //==============================================================================================
    // Module Structs
    //==============================================================================================

    struct ReviewToken has key {
        // Used for editing the token data
        mutator_ref: token::MutatorRef,
        // Used for burning the token
        burn_ref: token::BurnRef
    }

    struct Archive has key {
        // count
        count: u64,
        // latest ipfs_hash of website
        hash: String,
        // latest timestamp
        timestamp: u64
    }

    struct Roles has store, copy, drop{
        operator: vector<address>,
        reviewer: vector<address>
    }

    /*
        Information to be used in the module
    */
    struct State has key {
        // signer cap of the module's resource account
        signer_cap: SignerCapability,
        // reviews minted
        count: u128,
        // SimpleMap<Metadata, review_token_address>
        metadatas: SimpleMap<vector<u8>, address>,
        // SimpleMap<siteURL, site_token_address>
        websites: SimpleMap<String, address>,
        //roles
        roles: Roles,
        // Events
        role_granted_events: EventHandle<RoleGrantedEvent>,
        role_revoked_events: EventHandle<RoleRevokedEvent>,
        archive_link_events: EventHandle<ArchiveLinkEvent>,
        review_submitted_events: EventHandle<ReviewSubmittedEvent>,
        review_deleted_events: EventHandle<ReviewDeletedEvent>
    }

    //==============================================================================================
    // Event structs
    //==============================================================================================

    struct RoleGrantedEvent has store, drop {
        // approver
        approver: address,
        // role
        role: String,
        // user address
        user: address,
        // timestamp
        timestamp: u64
    }

    struct RoleRevokedEvent has store, drop {
        // executor
        executor: address,
        // role
        role: String,
        // user address
        user: address,
        // timestamp
        timestamp: u64
    }

    struct ArchiveLinkEvent has store, drop {
        // archive logger
        logger: address,
        // previous archive link, current archive link
        previous_archive_link: String,
        current_archive_link: String,
        // timestamp
        timestamp: u64
    }

    struct ReviewSubmittedEvent has store, drop {
        // address of the account submitting the review
        reviewer: address,
        // token address of review
        review_token_address: address,
        // review hash
        metadata: String,
        //output log for frontend
        category: String,
        domain_address: String,
        site_url: String,
        site_type: String,
        site_tag: String,
        site_safety: String,
        // timestamp
        timestamp: u64
    }

    struct ReviewDeletedEvent has store, drop {
        // review_hash
        metadata: String,
        // address of the account deleting the review
        deleter: address,
        // address of the account owning the review
        reviewer: address,
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

        let seed = bcs::to_bytes(&@RSEED);
        let (resource_signer, resource_cap) = account::create_resource_account(admin, seed);

        coin::register<AptosCoin>(&resource_signer);

        // Create a NFT collection with an unlimited supply with the following aspects:
        collection::create_unlimited_collection(
            &resource_signer,
            string::utf8(COLLECTION_DESCRIPTION),
            string::utf8(COLLECTION_NAME),
            option::none(),
            string::utf8(COLLECTION_URI)
        );

        let roles = Roles{
            operator: vector::empty<address>(),
            reviewer: vector::empty<address>()
        };

        // Create the State global resource and move it to the admin account
        let state = State{
            signer_cap: resource_cap,
            count: 0,
            metadatas: simple_map::new(),
            websites: simple_map::new(),
            roles,
            role_granted_events: account::new_event_handle<RoleGrantedEvent>(&resource_signer),
            role_revoked_events: account::new_event_handle<RoleRevokedEvent>(&resource_signer),
            archive_link_events: account::new_event_handle<ArchiveLinkEvent>(&resource_signer),
            review_submitted_events: account::new_event_handle<ReviewSubmittedEvent>(&resource_signer),
            review_deleted_events: account::new_event_handle<ReviewDeletedEvent>(&resource_signer)
        };
        move_to<State>(admin, state);
    }

    /*
    Grants reviewer/operator roles
    @param admin - admin signer
    @param user - user address
    @param role - reviewer/operator
*/
    public entry fun grant_role(
        admin: &signer,
        user: address,
        role: String
    ) acquires State {
        let state = borrow_global_mut<State>(@admin);
        assert_appropriate_role(role);
        assert_user_does_not_have_role(user, state.roles);
        if(role == string::utf8(b"operator")){
            assert_admin(signer::address_of(admin));
            vector::push_back(&mut state.roles.operator, user);
        }else{
            assert_admin_or_operator(signer::address_of(admin), state.roles);
            vector::push_back(&mut state.roles.reviewer, user);
        };
        // Emit a new RoleGrantedEvent
        event::emit_event<RoleGrantedEvent>(
            &mut state.role_granted_events,
            RoleGrantedEvent {
                approver: signer::address_of(admin),
                role,
                user,
                timestamp: timestamp::now_seconds()
            });
    }

    /*
    Revoke reviewer/operator roles
    @param admin - admin signer
    @param user - user address
    @param role - reviewer/operator
*/
    public entry fun revoke_role(
        admin: &signer,
        user: address
    ) acquires State {
        let state = borrow_global_mut<State>(@admin);
        assert_user_has_role(user, state.roles);
        let role;
        if(vector::contains(&state.roles.operator, &user)){
            assert_admin(signer::address_of(admin));
            vector::remove_value(&mut state.roles.operator, &user);
            role = string::utf8(b"operator");
        }else{
            assert_admin_or_operator(signer::address_of(admin), state.roles);
            vector::remove_value(&mut state.roles.reviewer, &user);
            role = string::utf8(b"reviewer");
        };
        // Emit a new RoleRevokedEvent
        event::emit_event<RoleRevokedEvent>(
            &mut state.role_revoked_events,
            RoleRevokedEvent {
                executor: signer::address_of(admin),
                role,
                user,
                timestamp: timestamp::now_seconds()
            });
    }

    /*
    Mints a new ReviewToken for the reviewer account
    @param admin - admin signer
    @param reviewer - signer representing the account reviewing the project
*/
    public entry fun submit_review(
        reviewer: &signer,
        metadata: String,
        category: String,
        domain_address: String,
        site_url: String,
        site_type: String,
        site_tag: String,
        site_safety: String,
        site_ipfs_hash: String
    ) acquires State, Archive {
        {
            let reviewer_address = signer::address_of(reviewer);
            {
                let state = borrow_global_mut<State>(@admin);
                assert_reviewer(reviewer_address, state.roles);
            };
            submit_review_internal(reviewer_address, metadata, category, domain_address, site_url, site_type, site_tag, site_safety);
        };

        // add archive only if ipfs_hash is not null
        if(!string::is_empty(&site_ipfs_hash)){
            archive_link(reviewer, site_url, site_ipfs_hash);
        };
    }

    //delegate mint - will not cost users to mint reviews
    public entry fun delegate_submit_review(
        operator: &signer,
        reviewer_address: address,
        metadata: String,
        category: String,
        domain_address: String,
        site_url: String,
        site_type: String,
        site_tag: String,
        site_safety: String,
        site_ipfs_hash: String
    ) acquires State, Archive {
        {
            {
                let state = borrow_global_mut<State>(@admin);
                assert_operator(signer::address_of(operator), state.roles);
            };
            submit_review_internal(reviewer_address, metadata, category, domain_address, site_url, site_type, site_tag, site_safety);
        };

        // add archive only if ipfs_hash is not null
        if(!string::is_empty(&site_ipfs_hash)){
            archive_link(operator, site_url, site_ipfs_hash);
        };
    }

    public entry fun delete_review(
        deleter: &signer,
        metadata: String
    ) acquires State, ReviewToken {
        let review_hash = bcs::to_bytes(&metadata);
        let state = borrow_global_mut<State>(@admin);
        assert_metadata_exists(review_hash, state.metadatas);
        let review_token_address = *simple_map::borrow(&state.metadatas, &review_hash);
        let review_token_object = object::address_to_object<ReviewToken>(review_token_address);
        let reviewer = object::owner(review_token_object);
        let deleter_address = signer::address_of(deleter);
        assert_owner(deleter_address, reviewer);
        let review_token = move_from<ReviewToken>(review_token_address);
        let ReviewToken{mutator_ref: _, burn_ref} = review_token;

        // Burn the the token
        token::burn(burn_ref);

        // Emit a new ReviewDeletedEvent
        simple_map::remove(&mut state.metadatas, &review_hash);
        event::emit_event<ReviewDeletedEvent>(
            &mut state.review_deleted_events,
            ReviewDeletedEvent {
                metadata,
                deleter: deleter_address,
                reviewer,
                timestamp: timestamp::now_seconds()
            });
    }

    public entry fun archive_link(
        user: &signer,
        site_url: String,
        site_ipfs_hash: String
    ) acquires State, Archive {
        let state = borrow_global_mut<State>(@admin);
        let previous_archive = string::utf8(b"");
        if(!simple_map::contains_key(&state.websites, &site_url)){
            //let site_object_address = object::create_object_address(&@admin, bcs::to_bytes(&site_url));
            let res_Signer = account::create_signer_with_capability(&state.signer_cap);
            let obj_signer = object::generate_signer(&object::create_named_object(&res_Signer, bcs::to_bytes(&site_url)));
            let new_archive = Archive {
                count: 1,
                hash: site_ipfs_hash,
                timestamp: timestamp::now_seconds()
            };
            simple_map::add(&mut state.websites, site_url, signer::address_of(&obj_signer));
            move_to<Archive>(&obj_signer, new_archive);
        }else{
            let archive = borrow_global_mut<Archive>(*simple_map::borrow(&state.websites, &site_url));
            archive.count = archive.count + 1;
            previous_archive = archive.hash;
            archive.hash = site_ipfs_hash;
            archive.timestamp = timestamp::now_seconds();
        };

        // Emit a new ArchiveLinkEvent
        event::emit_event<ArchiveLinkEvent>(
            &mut state.archive_link_events,
            ArchiveLinkEvent {
                logger: signer::address_of(user),
                previous_archive_link: previous_archive,
                current_archive_link: site_ipfs_hash,
                timestamp: timestamp::now_seconds()
            });
    }

    //==============================================================================================
    // Helper functions
    //==============================================================================================

    #[view]
    public fun check_if_metadata_exists(metadata: String): bool acquires State {
        let state = borrow_global<State>(@admin);
        simple_map::contains_key(&state.metadatas, &bcs::to_bytes(&metadata))
    }

    #[view]
    public fun check_role(user: address): String acquires State {
        let state = borrow_global<State>(@admin);
        if(vector::contains(&state.roles.reviewer, &user)){
            string::utf8(b"reviewer")
        }else if(vector::contains(&state.roles.operator, &user)){
            string::utf8(b"operator")
        }else{
            string::utf8(b"N/A")
        }
    }

    #[view]
    public fun total_reviews(): u64 acquires State {
        let state = borrow_global<State>(@admin);
        simple_map::length(&state.metadatas)
    }

    #[view]
    public fun total_sites_reviewed(): u64 acquires State {
        let state = borrow_global<State>(@admin);
        simple_map::length(&state.websites)
    }

    // submit review logic
    inline fun submit_review_internal(
        reviewer_address: address,
        metadata: String,
        category: String,
        domain_address: String,
        site_url: String,
        site_type: String,
        site_tag: String,
        site_safety: String
    ) acquires State {
        {
            let review_hash = bcs::to_bytes(&metadata);
            let state = borrow_global_mut<State>(@admin);
            assert_metadata_not_duplicated(review_hash, state.metadatas);
            let res_signer = account::create_signer_with_capability(&state.signer_cap);
            let count = state.count +1;
            let name = string_utils::format1(&b"Review #{}", count);
            // Create a new named token:
            let token_const_ref = token::create_named_token(
                &res_signer,
                string::utf8(COLLECTION_NAME),
                string::utf8(TOKEN_DESCRIPTION),
                name,
                option::none(),
                metadata
            );

            let obj_signer = object::generate_signer(&token_const_ref);

            // Transfer the token to the reviewer account
            object::transfer_raw(&res_signer, object::address_from_constructor_ref(&token_const_ref), reviewer_address);

            // Create the ReviewToken object and move it to the new token object signer
            let new_review_token = ReviewToken {
                mutator_ref: token::generate_mutator_ref(&token_const_ref),
                burn_ref: token::generate_burn_ref(&token_const_ref),
            };

            move_to<ReviewToken>(&obj_signer, new_review_token);
            simple_map::add(&mut state.metadatas, review_hash, object::address_from_constructor_ref(&token_const_ref));

            //block transfer between normal users
            object::disable_ungated_transfer(&object::generate_transfer_ref(&token_const_ref));

            state.count = count;
            // Emit a new ReviewSubmittedEvent
            event::emit_event<ReviewSubmittedEvent>(
                &mut state.review_submitted_events,
                ReviewSubmittedEvent {
                    reviewer: reviewer_address,
                    review_token_address: object::address_from_constructor_ref(&token_const_ref),
                    metadata,
                    category,
                    domain_address,
                    site_url,
                    site_type,
                    site_tag,
                    site_safety,
                    timestamp: timestamp::now_seconds()
                });
        };
    }

    //==============================================================================================
    // Validation functions
    //==============================================================================================

    inline fun assert_admin(admin: address) {
        assert!(admin == @admin, ERROR_SIGNER_NOT_ADMIN);
    }

    inline fun assert_metadata_not_duplicated(review_hash: vector<u8>, metadatas: SimpleMap<vector<u8>, address>) {
        assert!(!simple_map::contains_key(&metadatas, &review_hash), ERROR_METADATA_DUPLICATED);
    }

    inline fun assert_metadata_exists(review_hash: vector<u8>, metadatas: SimpleMap<vector<u8>, address>) {
        assert!(simple_map::contains_key(&metadatas, &review_hash), ERROR_REVIEW_DOES_NOT_EXIST);
    }

    inline fun assert_reviewer(user: address, roles: Roles) {
        assert!(vector::contains(&roles.reviewer, &user) , ERROR_SIGNER_NOT_REVIEWER);
    }

    inline fun assert_operator(user: address, roles: Roles) {
        assert!(vector::contains(&roles.operator, &user) , ERROR_SIGNER_NOT_OPERATOR);
    }

    inline fun assert_appropriate_role(role: String) {
        assert!(role == string::utf8(b"operator") || role == string::utf8(b"reviewer") , ERROR_INVALID_ROLE_NAME);
    }

    inline fun assert_user_has_role(user: address, roles: Roles) {
        assert!(vector::contains(&roles.reviewer, &user) || vector::contains(&roles.operator, &user) , ERROR_USER_NO_ROLE);
    }

    inline fun assert_user_does_not_have_role(user: address, roles: Roles) {
        assert!(!vector::contains(&roles.reviewer, &user) && !vector::contains(&roles.operator, &user) , ERROR_USER_ALREADY_HAS_ROLE);
    }

    inline fun assert_admin_or_operator(user: address, roles: Roles) {
        assert!(vector::contains(&roles.operator, &user) || user == @admin, ERROR_SIGNER_NOT_OPERATOR);
    }

    inline fun assert_owner(user: address, owner: address) {
        assert!(user == owner, ERROR_NOT_REVIEW_OWNER);
    }

    //==============================================================================================
    // Test functions
    //==============================================================================================

    #[test_only(admin = @admin)]
    public fun init_module_for_test(admin: &signer){
        init_module(admin);
    }

    #[test(admin = @admin)]
    fun test_init_module_success(
        admin: &signer
    ) acquires State {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let seed = bcs::to_bytes(&@RSEED);
        let expected_resource_account_address = account::create_resource_address(&admin_address, seed);
        assert!(account::exists_at(expected_resource_account_address), 0);

        let state = borrow_global<State>(admin_address);
        assert!(
            account::get_signer_capability_address(&state.signer_cap) == expected_resource_account_address,
            0
        );
        assert!(
            simple_map::length(&state.metadatas) == 0,
            4
        );

        assert!(
            coin::is_account_registered<AptosCoin>(expected_resource_account_address),
            4
        );

        let expected_collection_address = collection::create_collection_address(
            &expected_resource_account_address,
            &string::utf8(COLLECTION_NAME)
        );
        let collection_object = object::address_to_object<collection::Collection>(expected_collection_address);
        assert!(
            collection::creator<collection::Collection>(collection_object) == expected_resource_account_address,
            4
        );
        assert!(
            collection::name<collection::Collection>(collection_object) == string::utf8(COLLECTION_NAME),
            4
        );
        assert!(
            collection::description<collection::Collection>(collection_object) == string::utf8(COLLECTION_DESCRIPTION),
            4
        );
        assert!(
            collection::uri<collection::Collection>(collection_object) == string::utf8(COLLECTION_URI),
            4
        );
        assert!(state.count == 0, 4);
        assert!(event::counter(&state.review_submitted_events) == 0, 4);
        assert!(event::counter(&state.review_deleted_events) == 0, 4);
    }

    #[test(admin = @admin, reviewer = @0xA)]
    fun test_reviewer_success(
        admin: &signer,
        reviewer: &signer
    ) acquires State, Archive {
        let admin_address = signer::address_of(admin);
        let reviewer_address = signer::address_of(reviewer);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(reviewer_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        grant_role(
            admin,
            reviewer_address,
            string::utf8(b"reviewer")
        );

        let metadata = string::utf8(b"QmSYRXWGGqVDAHKTwfnYQDR74d4bfwXxudFosbGA695AWS");
        let category = string::utf8(b"Website");
        let domain_address = string::utf8(b"mystic.com");
        let site_url = string::utf8(b"todo.mystic.com");
        let site_type = string::utf8(b"Productivity app");
        let site_tag = string::utf8(b"Web3 Project");
        let site_safety = string::utf8(b"Genuine");
        let site_ipfs_hash = string::utf8(b"QmSYRXWGGqVDAHKTwfnYQDR74d4bfwXxudFosbGA695AWS");

        submit_review(
            reviewer,
            metadata,
            category,
            domain_address,
            site_url,
            site_type,
            site_tag,
            site_safety,
            site_ipfs_hash
        );

        let seed = bcs::to_bytes(&@RSEED);
        let resource_account_address = account::create_resource_address(&@admin, seed);

        let expected_name = string_utils::format1(&b"Review #{}", 1);
        let expected_review_token_address = token::create_token_address(
            &resource_account_address,
            &string::utf8(COLLECTION_NAME),
            &expected_name
        );
        let review_token_object = object::address_to_object<token::Token>(expected_review_token_address);
        assert!(
            object::is_owner(review_token_object, reviewer_address) == true,
            1
        );
        assert!(
            token::creator(review_token_object) == resource_account_address,
            4
        );
        assert!(
            token::name(review_token_object) == expected_name,
            4
        );
        assert!(
            token::description(review_token_object) == string::utf8(TOKEN_DESCRIPTION),
            4
        );
        assert!(
            token::uri(review_token_object) == metadata,
            4
        );
        assert!(
            option::is_none<royalty::Royalty>(&token::royalty(review_token_object)),
            4
        );

        let state = borrow_global<State>(admin_address);

        assert!(vector::contains(&state.roles.reviewer, &reviewer_address), 4);
        assert!(event::counter(&state.role_granted_events) == 1, 4);

        assert!(
            simple_map::length(&state.metadatas) == 1,
            4
        );

        assert!(event::counter(&state.review_submitted_events) == 1, 4);
        assert!(event::counter(&state.review_deleted_events) == 0, 4);
    }

    #[test(admin = @admin, reviewer = @0xA)]
    #[expected_failure(abort_code = ERROR_SIGNER_NOT_REVIEWER)]
    fun test_reviewer_failure_not_reviewer_role(
        admin: &signer,
        reviewer: &signer
    ) acquires State, Archive {
        let admin_address = signer::address_of(admin);
        let reviewer_address = signer::address_of(reviewer);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(reviewer_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let metadata = string::utf8(b"QmSYRXWGGqVDAHKTwfnYQDR74d4bfwXxudFosbGA695AWS");
        let category = string::utf8(b"Website");
        let domain_address = string::utf8(b"mystic.com");
        let site_url = string::utf8(b"todo.mystic.com");
        let site_type = string::utf8(b"Productivity app");
        let site_tag = string::utf8(b"Web3 Project");
        let site_safety = string::utf8(b"Genuine");
        let site_ipfs_hash = string::utf8(b"QmSYRXWGGqVDAHKTwfnYQDR74d4bfwXxudFosbGA695AWS");

        submit_review(
            reviewer,
            metadata,
            category,
            domain_address,
            site_url,
            site_type,
            site_tag,
            site_safety,
            site_ipfs_hash
        );
    }

    #[test(admin = @admin, reviewer = @0xA)]
    #[expected_failure(abort_code = ERROR_METADATA_DUPLICATED)]
    fun test_reviewer_failure_duplicated_review(
        admin: &signer,
        reviewer: &signer
    ) acquires State, Archive {
        let admin_address = signer::address_of(admin);
        let reviewer_address = signer::address_of(reviewer);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(reviewer_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        grant_role(
            admin,
            reviewer_address,
            string::utf8(b"reviewer")
        );

        let metadata = string::utf8(b"QmSYRXWGGqVDAHKTwfnYQDR74d4bfwXxudFosbGA695AWS");
        let category = string::utf8(b"Website");
        let domain_address = string::utf8(b"mystic.com");
        let site_url = string::utf8(b"todo.mystic.com");
        let site_type = string::utf8(b"Productivity app");
        let site_tag = string::utf8(b"Web3 Project");
        let site_safety = string::utf8(b"Genuine");
        let site_ipfs_hash = string::utf8(b"QmSYRXWGGqVDAHKTwfnYQDR74d4bfwXxudFosbGA695AWS");

        submit_review(
            reviewer,
            metadata,
            category,
            domain_address,
            site_url,
            site_type,
            site_tag,
            site_safety,
            site_ipfs_hash
        );

        submit_review(
            reviewer,
            metadata,
            category,
            domain_address,
            site_url,
            site_type,
            site_tag,
            site_safety,
            site_ipfs_hash
        );
    }

    #[test(admin = @admin, reviewer = @0xA, operator = @0xB)]
    fun test_delegate_review_success(
        admin: &signer,
        operator: &signer,
        reviewer: &signer
    ) acquires State, Archive {
        let admin_address = signer::address_of(admin);
        let reviewer_address = signer::address_of(reviewer);
        let operator_address = signer::address_of(operator);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(reviewer_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        grant_role(
            admin,
            operator_address,
            string::utf8(b"operator")
        );

        let metadata = string::utf8(b"QmSYRXWGGqVDAHKTwfnYQDR74d4bfwXxudFosbGA695AWS");
        let category = string::utf8(b"Website");
        let domain_address = string::utf8(b"mystic.com");
        let site_url = string::utf8(b"todo.mystic.com");
        let site_type = string::utf8(b"Productivity app");
        let site_tag = string::utf8(b"Web3 Project");
        let site_safety = string::utf8(b"Genuine");
        let site_ipfs_hash = string::utf8(b"QmSYRXWGGqVDAHKTwfnYQDR74d4bfwXxudFosbGA695AWS");

        delegate_submit_review(
            operator,
            reviewer_address,
            metadata,
            category,
            domain_address,
            site_url,
            site_type,
            site_tag,
            site_safety,
            site_ipfs_hash
        );

        let seed = bcs::to_bytes(&@RSEED);
        let resource_account_address = account::create_resource_address(&@admin, seed);

        let expected_name = string_utils::format1(&b"Review #{}", 1);
        let expected_review_token_address = token::create_token_address(
            &resource_account_address,
            &string::utf8(COLLECTION_NAME),
            &expected_name
        );
        let review_token_object = object::address_to_object<token::Token>(expected_review_token_address);
        assert!(
            object::is_owner(review_token_object, reviewer_address) == true,
            1
        );
        assert!(
            token::creator(review_token_object) == resource_account_address,
            4
        );
        assert!(
            token::name(review_token_object) == expected_name,
            4
        );
        assert!(
            token::description(review_token_object) == string::utf8(TOKEN_DESCRIPTION),
            4
        );
        assert!(
            token::uri(review_token_object) == metadata,
            4
        );
        assert!(
            option::is_none<royalty::Royalty>(&token::royalty(review_token_object)),
            4
        );

        let state = borrow_global<State>(admin_address);

        assert!(
            simple_map::length(&state.metadatas) == 1,
            4
        );

        assert!(vector::contains(&state.roles.operator, &operator_address), 4);
        assert!(event::counter(&state.role_granted_events) == 1, 4);
        assert!(event::counter(&state.review_submitted_events) == 1, 4);
        assert!(event::counter(&state.review_deleted_events) == 0, 4);
    }

    #[test(admin = @admin, reviewer = @0xA, operator = @0xB)]
    #[expected_failure(abort_code = ERROR_SIGNER_NOT_OPERATOR)]
    fun test_delegate_review_failure_not_operator(
        admin: &signer,
        operator: &signer,
        reviewer: &signer
    ) acquires State, Archive {
        let admin_address = signer::address_of(admin);
        let reviewer_address = signer::address_of(reviewer);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(reviewer_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let metadata = string::utf8(b"QmSYRXWGGqVDAHKTwfnYQDR74d4bfwXxudFosbGA695AWS");
        let category = string::utf8(b"Website");
        let domain_address = string::utf8(b"mystic.com");
        let site_url = string::utf8(b"todo.mystic.com");
        let site_type = string::utf8(b"Productivity app");
        let site_tag = string::utf8(b"Web3 Project");
        let site_safety = string::utf8(b"Genuine");
        let site_ipfs_hash = string::utf8(b"QmSYRXWGGqVDAHKTwfnYQDR74d4bfwXxudFosbGA695AWS");

        delegate_submit_review(
            operator,
            reviewer_address,
            metadata,
            category,
            domain_address,
            site_url,
            site_type,
            site_tag,
            site_safety,
            site_ipfs_hash
        );
    }

    #[test(admin = @admin, reviewer = @0xA, operator = @0xB)]
    fun test_delete_review_success(
        admin: &signer,
        operator: &signer,
        reviewer: &signer
    ) acquires State, ReviewToken, Archive {
        let admin_address = signer::address_of(admin);
        let reviewer_address = signer::address_of(reviewer);
        let operator_address = signer::address_of(operator);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(reviewer_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        grant_role(
            admin,
            reviewer_address,
            string::utf8(b"reviewer")
        );

        let metadata = string::utf8(b"QmSYRXWGGqVDAHKTwfnYQDR74d4bfwXxudFosbGA695AWS");
        let category = string::utf8(b"Website");
        let domain_address = string::utf8(b"mystic.com");
        let site_url = string::utf8(b"todo.mystic.com");
        let site_type = string::utf8(b"Productivity app");
        let site_tag = string::utf8(b"Web3 Project");
        let site_safety = string::utf8(b"Genuine");
        let site_ipfs_hash = string::utf8(b"QmSYRXWGGqVDAHKTwfnYQDR74d4bfwXxudFosbGA695AWS");

        submit_review(
            reviewer,
            metadata,
            category,
            domain_address,
            site_url,
            site_type,
            site_tag,
            site_safety,
            site_ipfs_hash
        );

        let seed = bcs::to_bytes(&@RSEED);
        let resource_account_address = account::create_resource_address(&@admin, seed);

        let expected_name = string_utils::format1(&b"Review #{}", 1);
        let expected_review_token_address = token::create_token_address(
            &resource_account_address,
            &string::utf8(COLLECTION_NAME),
            &expected_name
        );

        grant_role(
            admin,
            operator_address,
            string::utf8(b"operator")
        );

        delete_review(reviewer, metadata);

        assert!(!exists<ReviewToken>(expected_review_token_address), 3);

        let state = borrow_global<State>(admin_address);

        assert!(vector::contains(&state.roles.reviewer, &reviewer_address), 4);
        assert!(vector::contains(&state.roles.operator, &operator_address), 4);
        assert!(event::counter(&state.role_granted_events) == 2, 4);
        assert!(simple_map::length(&state.metadatas) == 0, 4);
        assert!(event::counter(&state.review_submitted_events) == 1, 4);
        assert!(event::counter(&state.review_deleted_events) == 1, 4);
    }

    #[test(admin = @admin, reviewer = @0xA, operator = @0xB)]
    #[expected_failure(abort_code = ERROR_NOT_REVIEW_OWNER)]
    fun test_delete_review_failure_not_operator_nor_owner(
        admin: &signer,
        operator: &signer,
        reviewer: &signer
    ) acquires State, ReviewToken, Archive {
        let admin_address = signer::address_of(admin);
        let reviewer_address = signer::address_of(reviewer);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(reviewer_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        grant_role(
            admin,
            reviewer_address,
            string::utf8(b"reviewer")
        );

        {
            let state = borrow_global<State>(admin_address);
            assert!(vector::contains(&state.roles.reviewer, &reviewer_address), 4);
            assert!(event::counter(&state.role_granted_events) == 1, 4);
        };

        let metadata = string::utf8(b"QmSYRXWGGqVDAHKTwfnYQDR74d4bfwXxudFosbGA695AWS");
        let category = string::utf8(b"Website");
        let domain_address = string::utf8(b"mystic.com");
        let site_url = string::utf8(b"todo.mystic.com");
        let site_type = string::utf8(b"Productivity app");
        let site_tag = string::utf8(b"Web3 Project");
        let site_safety = string::utf8(b"Genuine");
        let site_ipfs_hash = string::utf8(b"QmSYRXWGGqVDAHKTwfnYQDR74d4bfwXxudFosbGA695AWS");

        submit_review(
            reviewer,
            metadata,
            category,
            domain_address,
            site_url,
            site_type,
            site_tag,
            site_safety,
            site_ipfs_hash
        );

        {
            let state = borrow_global<State>(admin_address);
            assert!(simple_map::length(&state.metadatas) == 1, 4);
            assert!(event::counter(&state.review_submitted_events) == 1, 4);
        };

        delete_review(operator, metadata);
    }

    #[test(admin = @admin, reviewer = @0xA)]
    fun test_grant_reviewer_role_success(
        admin: &signer,
        reviewer: &signer
    ) acquires State {
        let admin_address = signer::address_of(admin);
        let reviewer_address = signer::address_of(reviewer);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(reviewer_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        grant_role(
            admin,
            reviewer_address,
            string::utf8(b"reviewer")
        );

        let state = borrow_global<State>(admin_address);
        assert!(vector::contains(&state.roles.reviewer, &reviewer_address), 4);
        assert!(event::counter(&state.role_granted_events) == 1, 4);
    }

    #[test(admin = @admin, reviewer = @0xA)]
    #[expected_failure(abort_code = ERROR_INVALID_ROLE_NAME)]
    fun test_grant_role_failure_wrong_role(
        admin: &signer,
        reviewer: &signer
    ) acquires State {
        let admin_address = signer::address_of(admin);
        let reviewer_address = signer::address_of(reviewer);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(reviewer_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        grant_role(
            admin,
            reviewer_address,
            string::utf8(b"")
        );
    }

    #[test(admin = @admin, operator = @0xB)]
    fun test_grant_operator_role_success(
        admin: &signer,
        operator: &signer
    ) acquires State {
        let admin_address = signer::address_of(admin);
        let operator_address = signer::address_of(operator);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(operator_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        grant_role(
            admin,
            operator_address,
            string::utf8(b"operator")
        );

        let state = borrow_global<State>(admin_address);
        assert!(vector::contains(&state.roles.operator, &operator_address), 4);
        assert!(event::counter(&state.role_granted_events) == 1, 4);
    }

    #[test(admin = @admin, operator = @0xB)]
    fun test_revoke_operator_role_success(
        admin: &signer,
        operator: &signer
    ) acquires State {
        let admin_address = signer::address_of(admin);
        let operator_address = signer::address_of(operator);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(operator_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        grant_role(
            admin,
            operator_address,
            string::utf8(b"operator")
        );

        {
            let state = borrow_global<State>(admin_address);
            assert!(vector::contains(&state.roles.operator, &operator_address), 4);
            assert!(event::counter(&state.role_granted_events) == 1, 4);
        };

        revoke_role(
            admin,
            operator_address
        );

        let state = borrow_global<State>(admin_address);
        assert!(!vector::contains(&state.roles.operator, &operator_address), 4);
        assert!(event::counter(&state.role_revoked_events) == 1, 4);
    }

    #[test(admin = @admin, user = @0xB)]
    #[expected_failure(abort_code = ERROR_USER_NO_ROLE)]
    fun test_revoke_role_failure_user_has_no_role(
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
        revoke_role(
            admin,
            user_address
        );
    }

    #[test(admin = @admin, user = @0xA)]
    fun test_archive(
        admin: &signer,
        user: &signer
    ) acquires State, Archive {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        grant_role(
            admin,
            user_address,
            string::utf8(b"reviewer")
        );

        let metadata = string::utf8(b"QmSYRXWGGqVDAHKTwfnYQDR74d4bfwXxudFosbGA695AWS");
        let category = string::utf8(b"Website");
        let domain_address = string::utf8(b"mystic.com");
        let site_url = string::utf8(b"todo.mystic.com");
        let site_type = string::utf8(b"Productivity app");
        let site_tag = string::utf8(b"Web3 Project");
        let site_safety = string::utf8(b"Genuine");
        let site_ipfs_hash = string::utf8(b"QmSYRXWGGqVDAHKTwfnYQDR74d4bfwXxudFosbGA695AWS");

        submit_review(
            user,
            metadata,
            category,
            domain_address,
            site_url,
            site_type,
            site_tag,
            site_safety,
            site_ipfs_hash
        );

        let seed = bcs::to_bytes(&@RSEED);
        let resource_account_address = account::create_resource_address(&@admin, seed);

        let expected_name = string_utils::format1(&b"Review #{}", 1);
        let expected_review_token_address = token::create_token_address(
            &resource_account_address,
            &string::utf8(COLLECTION_NAME),
            &expected_name
        );
        let review_token_object = object::address_to_object<token::Token>(expected_review_token_address);
        assert!(
            object::is_owner(review_token_object, user_address) == true,
            1
        );
        assert!(
            token::creator(review_token_object) == resource_account_address,
            4
        );
        assert!(
            token::name(review_token_object) == expected_name,
            4
        );
        assert!(
            token::description(review_token_object) == string::utf8(TOKEN_DESCRIPTION),
            4
        );
        assert!(
            token::uri(review_token_object) == metadata,
            4
        );
        assert!(
            option::is_none<royalty::Royalty>(&token::royalty(review_token_object)),
            4
        );

        {
            let state = borrow_global<State>(admin_address);

            assert!(vector::contains(&state.roles.reviewer, &user_address), 4);
            assert!(event::counter(&state.role_granted_events) == 1, 4);

            assert!(
                simple_map::length(&state.metadatas) == 1,
                4
            );

            assert!(event::counter(&state.review_submitted_events) == 1, 4);
            assert!(event::counter(&state.review_deleted_events) == 0, 4);
        };

        let site_ipfs_hash = string::utf8(b"QmSYRXWGGqVDAHKTwfnYQDR74d4bfwXxudFosbGA695AWS");
        archive_link(user, site_url, site_ipfs_hash);
        let state = borrow_global<State>(admin_address);
        assert!(simple_map::contains_key(&state.websites, &site_url), 4);
        let archive = borrow_global<Archive>(*simple_map::borrow(&state.websites, &site_url));
        assert!(archive.hash == site_ipfs_hash, 4);
        assert!(archive.count == 2, 4);
        assert!(event::counter(&state.archive_link_events) == 2, 4);
    }
}