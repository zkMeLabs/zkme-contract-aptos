module zkme::verify{
    use std::error;
    use std::signer;
    use std::vector;
    use aptos_std::simple_map::{Self, SimpleMap};
    use aptos_std::aptos_hash;
    use aptos_framework::timestamp;
    use zkme::simple_set::{Self, SimpleSet};
    use zkme::role;
    use zkme::conf;
    use zkme::sbt;

    const E_NOT_HAVE_ZKME_SBT: u64 = 1;
    const E_HAVE_APPROVED: u64 = 2;
    const E_NOT_APPROVED: u64 = 3;
    const E_INVALID_ARGUMENT: u64 = 4;


    struct Verify has key{
        pu_map: SimpleMap<address,SimpleMap<address,u64>>,
        approve_map: SimpleMap<address,SimpleSet<u64>>,
        kyc_data_map: SimpleMap<address,SimpleMap<u64,UserData>>,
    }

    struct UserData has copy, drop, store {
        threhold_key: vector<u8>,
        validity: u64,
        data: vector<u8>,
        question: vector<vector<u8>>,
    }

    fun init_module(admin:&signer){
        move_to(admin,Verify{
            pu_map:simple_map::create(),
            approve_map: simple_map::create(),
            kyc_data_map: simple_map::create(),
        });
    }

    public entry fun approve(
        owner: &signer,
        cooperator:address,
        mint_id:u64,
        cooperator_threshold: vector<u8>,
    ) acquires Verify{
        role::assert_cooperator(cooperator);

        let owner_address = signer::address_of(owner);
        let sbt_owner = sbt::owner_of(mint_id);

        assert!(&owner_address == &sbt_owner || role::is_operator(owner_address),error::permission_denied(E_NOT_HAVE_ZKME_SBT));
        
        let verify = borrow_global_mut<Verify>(@zkme);

        let pu_map = &mut verify.pu_map;
        if(!simple_map::contains_key(pu_map,&cooperator)){
            simple_map::add(pu_map,cooperator,simple_map::create());
        }else{
            let pu_cooperator_map = simple_map::borrow_mut(pu_map,&cooperator);
            if(!simple_map::contains_key(pu_cooperator_map,&owner_address)){
                simple_map::add(pu_cooperator_map,sbt_owner,mint_id);
            };
        };
        
        let approve_map = &mut verify.approve_map;
        if(!simple_map::contains_key(approve_map,&cooperator)){
            simple_map::add(approve_map,cooperator,simple_set::create());
        }else{
            let approve_cooperator_tokenid_set = simple_map::borrow_mut(approve_map,&cooperator);
            if(!simple_set::contains(approve_cooperator_tokenid_set,&mint_id)){
                simple_set::add(approve_cooperator_tokenid_set,mint_id);
            };
        };

        let kyc_data_map = &mut verify.kyc_data_map;
        let user_kyc_validity = sbt::get_kyc_validity(mint_id);
        let user_kyc_data = sbt::get_kyc_data_data(mint_id);
        let user_kyc_question = sbt::get_kyc_question(mint_id);
        if(!simple_map::contains_key(kyc_data_map,&cooperator)){
            simple_map::add(kyc_data_map,cooperator,simple_map::create());
            let kyc_cooperator_map = simple_map::borrow_mut(kyc_data_map,&cooperator);
            simple_map::add(kyc_cooperator_map,mint_id,UserData{
                threhold_key: cooperator_threshold,
                validity: user_kyc_validity,
                data: user_kyc_data,
                question: user_kyc_question,
            });
        }else{
            let kyc_cooperator_map = simple_map::borrow_mut(kyc_data_map,&cooperator);
            simple_map::upsert(kyc_cooperator_map, mint_id, UserData{
                threhold_key: cooperator_threshold,
                validity: user_kyc_validity,
                data: user_kyc_data,
                question: user_kyc_question,
            });
        };
    }

    public entry fun revoke(
        owner: &signer,
        cooperator: address,
        mint_id:u64
    ) acquires Verify{
        role::assert_cooperator(cooperator);

        let owner_address = signer::address_of(owner);
        let sbt_owner = sbt::owner_of(mint_id);

        assert!(&owner_address == &sbt_owner || role::is_operator(owner_address),error::permission_denied(E_NOT_HAVE_ZKME_SBT));

        let verify = borrow_global_mut<Verify>(@zkme);
        let approve_map = &mut verify.approve_map;
        let approve_cooperator_tokenid_set = simple_map::borrow_mut(approve_map,&cooperator);
        assert!(!simple_set::contains(approve_cooperator_tokenid_set,&mint_id),error::not_found(E_NOT_APPROVED));
        simple_set::remove(approve_cooperator_tokenid_set,&mint_id);
    }

    #[view]
    public fun verify(
        cooperator:address,
        user:address
    ):bool{
        let mint_id = sbt::token_id_of(user);
        let validity = sbt::get_kyc_validity(mint_id);
        let user_question = sbt::get_kyc_question(mint_id);
        let now_sec = timestamp::now_seconds();
        if (validity < now_sec){
            return false
        };
        let project = conf::get_question(cooperator);
        if(vector::length(&project) == 0){
            return false
        };
        return matching(project,user_question)
    }

    fun matching(
        project: vector<vector<u8>>,
        user: vector<vector<u8>>
    ):bool {
        let project_len = vector::length(&project);
        let user_len = vector::length(&user);
        let i = 0;
        let j = 0;
        let found = false;
        while(i < project_len){
            while(j < user_len){
                let p = vector::borrow(&project,i);
                let u = vector::borrow(&user,j);
                if(aptos_hash::keccak256(*p) == aptos_hash::keccak256(*u)){
                   found = true;
                };
                j = j + 1;
            };

            if(found){
                found =  false;
            }else{
                return false
            };
            i = i + 1;
        };
        return true
    }

    #[view]
    public fun has_approved(
        cooperator:address,
        user:address
    ):bool acquires Verify{
        let mint_id = get_mint_id(cooperator,user);
        let verify = borrow_global<Verify>(@zkme);
        return mint_id != 0 && simple_map::contains_key(&verify.approve_map,&user)
    }

    #[view]
    public fun get_user_tokenid(
        cooperator:&signer,
        user:address
    ): u64 acquires Verify{
        let cooperator_address = signer::address_of(cooperator);
        role::assert_cooperator(cooperator_address);

        if(has_approved(cooperator_address,user)){
            return get_mint_id(cooperator_address,user)
        };
        return 0
    }

    #[view]
    public fun get_user_tokenid_for_operator(
        operator: &signer,
        cooperator:address,
        user:address
    ): u64 acquires Verify{
        role::assert_operator(signer::address_of(operator));
        role::assert_cooperator(cooperator);
        if(has_approved(cooperator,user)){
            return get_mint_id(cooperator,user)
        };
        return 0
    }

    #[view]
    public fun get_user_data(
        cooperator:&signer,
        user:address
    ):UserData acquires Verify{
        let cooperator_address = signer::address_of(cooperator);
        role::assert_cooperator(cooperator_address);
        assert!(has_approved(cooperator_address,user),error::not_found(E_NOT_APPROVED));
        let mint_id = get_mint_id(cooperator_address,user);
        get_user_kyc_data(cooperator_address,mint_id)
    }

    #[view]
    public fun get_user_data_for_operator(
        operator: &signer,
        cooperator:address,
        user:address
    ):UserData acquires Verify{
        role::assert_operator(signer::address_of(operator));
        assert!(has_approved(cooperator,user),error::not_found(E_NOT_APPROVED));
        let mint_id = get_mint_id(cooperator,user);
        get_user_kyc_data(cooperator,mint_id)
    }

    #[view]
    public fun get_user_data_for_inspector(
        inspector: &signer,
        cooperator:address,
        user:address
    ):UserData acquires Verify{
        role::assert_inspector(signer::address_of(inspector));
        assert!(has_approved(cooperator,user),error::not_found(E_NOT_APPROVED));
        let mint_id = get_mint_id(cooperator,user);
        get_user_kyc_data(cooperator,mint_id)
    }

    fun get_user_kyc_data(
        cooperator: address,
        mint_id:u64,
    ):UserData acquires Verify{
        let verify = borrow_global<Verify>(@zkme);
        let cooperator_kyc_data_map = simple_map::borrow(&verify.kyc_data_map,&cooperator);
        let exists = simple_map::contains_key(cooperator_kyc_data_map,&mint_id);
        assert!(exists,error::not_found(E_NOT_APPROVED));
        *simple_map::borrow(cooperator_kyc_data_map,&mint_id)
    }

    fun get_mint_id(
        cooperator:address,
        user:address
    ): u64 acquires Verify{
        let verify = borrow_global<Verify>(@zkme);
        let pu_map = &verify.pu_map;
        let pu_cooperator_map = simple_map::borrow(pu_map,&cooperator);
        let exists = simple_map::contains_key(pu_cooperator_map,&user);
        if (exists){
            return *simple_map::borrow(pu_cooperator_map,&user)
        };
        return 0
    }

    #[view]
    public fun get_approved_tokenid(
        cooperator:&signer,
        start:u64,
        page_size:u64
    ):vector<u64> acquires Verify{
        role::assert_cooperator(signer::address_of(cooperator));
        get_approved_tokenid_list(signer::address_of(cooperator),start,page_size)
    }

    #[view]
    public fun get_approved_tokenid_for_operator(
        operator: &signer,
        cooperator:address,
        start:u64,
        page_size:u64
    ):vector<u64> acquires Verify{
        role::assert_operator(signer::address_of(operator));
        get_approved_tokenid_list(cooperator,start,page_size)
    }

    #[view]
    public fun get_approved_length(
        cooperator:&signer
    ):u64 acquires Verify{
        let cooperator_address = signer::address_of(cooperator);
        role::assert_cooperator(cooperator_address);
        let verify = borrow_global<Verify>(@zkme);
        let approve_tokenid_set = simple_map::borrow(&verify.approve_map,&cooperator_address);
        simple_set::length(approve_tokenid_set)
    }

    #[view]
    public fun get_approved_length_for_operator(
        operator: &signer,
        cooperator:address,
    ):u64 acquires Verify{
        role::assert_operator(signer::address_of(operator));
        let verify = borrow_global<Verify>(@zkme);
        let approve_tokenid_set = simple_map::borrow(&verify.approve_map,&cooperator);
        simple_set::length(approve_tokenid_set)
    }

    fun get_approved_tokenid_list(
        cooperator:address,
        start:u64,
        page_size:u64
    ):vector<u64> acquires Verify{
        assert!(start >= 0 && page_size > 0 && page_size <= 50,error::invalid_argument(E_INVALID_ARGUMENT));
        let tokenid_list = vector::empty<u64>();
        let verify = borrow_global<Verify>(@zkme);
        let approve_tokenid_set = simple_map::borrow(&verify.approve_map,&cooperator);
        let len = simple_set::length(approve_tokenid_set);
        let end = len;
        if (start + page_size < len){
            end = start + page_size;
        };
        let i = 0;
        while(i < end){
            vector::push_back(&mut tokenid_list,*simple_set::at(approve_tokenid_set,i));
            i = i + 1;
        };
        return tokenid_list
    }
}
