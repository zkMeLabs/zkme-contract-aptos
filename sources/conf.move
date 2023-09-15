module zkme::conf{
    use std::signer;
    use std::vector;
    use aptos_std::simple_map::{Self, SimpleMap};
    use aptos_framework::account;
    use aptos_framework::event::{Self, EventHandle};
    use zkme::role;

    struct Conf has key{
        question_map: SimpleMap<address,vector<vector<u8>>>,
        set_question_event:EventHandle<SetQuestionEvent>,
    }

    struct SetQuestionEvent has copy, drop, store {
        operator_address:address,
        zkme_address:address,
        cooperator_address: address,
        questions: vector<vector<u8>>,
    }

    fun init_module(admin: &signer) {
        let conf = Conf {
            question_map: simple_map::create(),
            set_question_event: account::new_event_handle<SetQuestionEvent>(admin),
        };
        move_to(admin,conf);
    }
    
    public fun set_question(
        operator:&signer,
        cooperator:address,
        questions: vector<vector<u8>>
    ) acquires Conf{
        let operator_address = signer::address_of(operator);
        role::assert_operator(operator_address);

        let conf = borrow_global_mut<Conf>(@zkme);
        simple_map::upsert(&mut conf.question_map,cooperator,questions);

        event::emit_event<SetQuestionEvent>(
            &mut conf.set_question_event,
            SetQuestionEvent{
                operator_address:operator_address,
                zkme_address:@zkme,
                cooperator_address:cooperator,
                questions:questions,
            }
        );
    }

    public fun get_question(
        cooperator:address
    ):vector<vector<u8>> acquires Conf{
        let conf = borrow_global<Conf>(@zkme);
        *simple_map::borrow(&conf.question_map,&cooperator)
    }

    #[test(admin=@zkme,operator=@0x11,cooperator=@0x22)]
    public entry fun test_conf(
        admin: signer,
        operator:signer,
        cooperator:signer
    ) acquires Conf{
        use std::string;
        account::create_account_for_test(signer::address_of(&admin));
        account::create_account_for_test(signer::address_of(&operator));
        account::create_account_for_test(signer::address_of(&cooperator));
        let cooperator_address = signer::address_of(&cooperator);
        
        init_module(&admin);
        let questions: vector<vector<u8>> = vector::empty<vector<u8>>();
        let q1 = string::utf8(b"6168752826443568356578851982882135008485");
        let q2 = string::utf8(b"7721528705884867793143365084876737116315");
        
        vector::push_back(&mut questions,q1);
        vector::push_back(&mut questions,q2);

        set_question(&operator,cooperator_address,questions);
        let questions_1 = get_question(cooperator_address);
        assert!(&questions == &questions_1,1);
    }

    #[test(admin=@zkme,operator=@0x11,cooperator=@0x22)]
    #[expected_failure]
    public entry fun get_empty(
        admin: signer,
        operator:signer,
        cooperator:signer
    ) acquires Conf{
        account::create_account_for_test(signer::address_of(&admin));
        account::create_account_for_test(signer::address_of(&operator));
        account::create_account_for_test(signer::address_of(&cooperator));
        let cooperator_address = signer::address_of(&cooperator);
        
        init_module(&admin);
        get_question(cooperator_address);
    }
}