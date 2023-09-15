module zkme::sbt{
    use std::bcs;
    use std::error;
    use std::signer;
    use std::string::{Self, String};
    // use std::vector;
    use aptos_std::simple_map::{Self, SimpleMap};
    use aptos_framework::account;
    use aptos_framework::event::{EventHandle};
    use aptos_framework::timestamp;
    use aptos_token::token::{Self, TokenDataId};
    use zkme::role;


    const E_ZKME_SBT_EXISTS: u64 = 1;
    const E_ZKME_SBT_NOT_EXISTS: u64 = 2;
    const E_INVALID_VALIDITY: u64 = 3;
    const E_NOT_KYC_PASSED: u64 = 4;
    const E_NOT_SET_BASE_TOKEN_URI: u64 = 5;

    struct UserData has copy, drop, store {
        threhold_key: vector<u8>,
        validity: u64,
        data: vector<u8>,
        question: vector<vector<u8>>,
    }

    struct Data has key{
        owner_map: SimpleMap<u64,address>,
        token_map: SimpleMap<address,u64>,
        kyc_map: SimpleMap<u64,UserData>,
        mint_id: u64,
        base_token_uri: String,
    }

    struct TokenMintingEvent has drop, store {
        token_receiver_address: address,
        token_data_id: TokenDataId,
    }

    struct ModuleData has key {
        token_data_id: TokenDataId,
        token_minting_events: EventHandle<TokenMintingEvent>,
    }


    fun init_module(admin:&signer) {
        init_sbt(admin);

        let data = Data {
            owner_map: simple_map::create(),
            token_map: simple_map::create(),
            kyc_map: simple_map::create(),
            mint_id:0,
            base_token_uri: string::utf8(b""),
        };

        move_to(admin,data);
    }

    fun init_sbt(admin: &signer){

        let collection_name = string::utf8(b"zkme");
        let description = string::utf8(b"zkme sbt");
        let collection_uri = string::utf8(b"");
        let token_name = string::utf8(b"zkme sbt");
        let token_uri = string::utf8(b"");

        let maximum_supply = 0;
        let mutate_setting = vector<bool>[ false, true, false ];

        token::create_collection(admin, collection_name, description, collection_uri, maximum_supply, mutate_setting);

        let token_data_id = token::create_tokendata(
            admin,
            collection_name,
            token_name,
            description,
            maximum_supply,
            token_uri,
            signer::address_of(admin),
            1,
            0,
            token::create_token_mutability_config(
                &vector<bool>[ false, false, false, false, true ]
            ),
            vector<String>[string::utf8(b"given_to")],
            vector<vector<u8>>[b""],
            vector<String>[ string::utf8(b"address") ],
        );
        
        move_to(admin, ModuleData {
            token_data_id,
            token_minting_events: account::new_event_handle<TokenMintingEvent>(admin),
        });
    }

    #[view]
    public fun attest(
        admin: &signer, 
        receiver:&signer
    ): u64 acquires Data, ModuleData {
        role::assert_admin(admin);

        let receiver_addr = signer::address_of(receiver);
        let data = borrow_global_mut<Data>(@zkme);
        assert!(!simple_map::contains_key(&data.token_map, &receiver_addr), error::already_exists(E_ZKME_SBT_EXISTS));
        assert!(string::is_empty(&data.base_token_uri),error::not_found(E_NOT_SET_BASE_TOKEN_URI));

        data.mint_id = data.mint_id + 1;

        let module_data = borrow_global_mut<ModuleData>(@zkme);
        let base_token_uri = data.base_token_uri;
        string::append(&mut base_token_uri, string::utf8(bcs::to_bytes(&data.mint_id)));
        token::mutate_tokendata_uri(admin,module_data.token_data_id,base_token_uri);
        let token_id = token::mint_token(admin, module_data.token_data_id, 1);
        token::direct_transfer(admin, receiver, token_id, 1);

        let (creator_address, collection, name) = token::get_token_data_id_fields(&module_data.token_data_id);
        token::mutate_token_properties(
            admin,
            receiver_addr,
            creator_address,
            collection,
            name,
            0,
            1,
            vector<String>[string::utf8(b"given_to")],
            vector<vector<u8>>[bcs::to_bytes(&receiver_addr)],
            vector<String>[ string::utf8(b"address") ],
        );

        data.mint_id = data.mint_id + 1;
        simple_map::add(&mut data.token_map, receiver_addr, data.mint_id);
        simple_map::add(&mut data.owner_map, data.mint_id, receiver_addr);
        data.mint_id
    }

    public entry fun set_kyc_data(
        operator: &signer,
        mint_id:u64,
        threhold_key:vector<u8>,
        validity:u64,
        data:vector<u8>,
        question:vector<vector<u8>>
    ) acquires Data{

        role::assert_operator(signer::address_of(operator));

        let zkme_data = borrow_global_mut<Data>(@zkme);
        assert!(simple_map::contains_key(&zkme_data.owner_map, &mint_id), error::not_found(E_ZKME_SBT_NOT_EXISTS));
        let now = timestamp::now_seconds();
        assert!(validity > now,error::invalid_argument(E_INVALID_VALIDITY));

        let user_data = UserData{
            threhold_key: threhold_key,
            validity: validity,
            data: data,
            question: question,
        };
        simple_map::add(&mut zkme_data.kyc_map, mint_id, user_data);
    }

    #[view]
    public fun get_kyc_data(
        mint_id:u64
    ):UserData acquires Data{
        get_kyc_data_inner(mint_id)
    }

    public fun get_kyc_threhold(
        mint_id: u64
    ):vector<u8> acquires Data{
        let user_data = get_kyc_data_inner(mint_id);
        user_data.threhold_key
    }

    public fun get_kyc_validity(
        mint_id:u64
    ):u64 acquires Data{
        let user_data = get_kyc_data_inner(mint_id);
        user_data.validity
    }

    public fun get_kyc_data_data(
        mint_id:u64
    ):vector<u8> acquires Data{
        let user_data = get_kyc_data_inner(mint_id);
        user_data.data
    }

    public fun get_kyc_question(
        mint_id: u64
    ):vector<vector<u8>> acquires Data{
        let user_data = get_kyc_data_inner(mint_id);
        user_data.question
    }

    fun get_kyc_data_inner(
        mint_id:u64
    ):UserData acquires Data{
        let data = borrow_global_mut<Data>(@zkme);
        assert!(simple_map::contains_key(&data.kyc_map, &mint_id), error::not_found(E_ZKME_SBT_NOT_EXISTS));
        *simple_map::borrow(&data.kyc_map, &mint_id)
    }

    public entry fun revoke(
        operator: &signer,
        owner:address,
        mint_id: u64
    ) acquires Data{
        role::assert_operator(signer::address_of(operator));
        let data = borrow_global_mut<Data>(@zkme);
        assert!(simple_map::contains_key(&data.owner_map, &mint_id), error::not_found(E_ZKME_SBT_NOT_EXISTS));
        simple_map::remove(&mut data.owner_map, &mint_id);
        assert!(simple_map::contains_key(&data.token_map, &owner), error::not_found(E_ZKME_SBT_NOT_EXISTS));
        simple_map::remove(&mut data.token_map, &owner);
    }

    public entry fun burn(
        owner: &signer,
        mint_id:u64
    ) acquires Data{
        let owner_address = signer::address_of(owner);
        let data = borrow_global_mut<Data>(@zkme);
        assert!(simple_map::contains_key(&data.token_map, &owner_address), error::not_found(E_ZKME_SBT_NOT_EXISTS));
        simple_map::remove(&mut data.token_map, &owner_address);
        assert!(simple_map::contains_key(&data.owner_map, &mint_id), error::not_found(E_ZKME_SBT_NOT_EXISTS));
        simple_map::remove(&mut data.owner_map, &mint_id);
    }

    #[view]
    public fun token_id_of(
        owner:address
    ):u64 acquires Data{
        let data = borrow_global_mut<Data>(@zkme);
        assert!(simple_map::contains_key(&data.token_map, &owner), error::not_found(E_ZKME_SBT_NOT_EXISTS));
        *simple_map::borrow(&data.token_map, &owner)
    }
    
    #[view]
    public fun owner_of(
        mint_id:u64
    ):address acquires Data{
        let data = borrow_global_mut<Data>(@zkme);
        assert!(simple_map::contains_key(&data.owner_map, &mint_id), error::not_found(E_ZKME_SBT_NOT_EXISTS));
        *simple_map::borrow(&data.owner_map, &mint_id)
    }

    #[view]
    public fun balance_of(
        owner:address
    ):u64 acquires Data{
        let data = borrow_global_mut<Data>(@zkme);
        if(simple_map::contains_key(&data.token_map, &owner)){
            return 1
        };
        return 0
    }

    public fun set_base_token_uri(
        operator: &signer,
        uri: vector<u8>
    ) acquires Data{
        role::assert_operator(signer::address_of(operator));
        let data = borrow_global_mut<Data>(@zkme);
        data.base_token_uri = string::utf8(uri);
    }

    #[view]
    public fun token_uri(
        mint_id:u64
    ): vector<u8> acquires Data{
        let data = borrow_global_mut<Data>(@zkme);
        let mint_id_str = string::utf8(bcs::to_bytes(&mint_id));
        string::append(&mut data.base_token_uri, mint_id_str);
        *string::bytes(&data.base_token_uri)
    }

    #[view]
    public fun total_supply():u64 acquires Data{
        let data = borrow_global_mut<Data>(@zkme);
        data.mint_id
    }

}