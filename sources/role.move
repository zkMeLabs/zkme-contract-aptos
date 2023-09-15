module zkme::role{
    use std::vector;
    use std::error;
    use std::signer;

    const E_NOT_ADMIN: u64 =  1;
    const E_NOT_OPERATOR: u64 =  2;
    const E_NOT_COOPERATOR: u64 =  3;
    const E_NOT_INSPECTOR: u64 =  4;

    struct Role has key{
        admin:address,
        operator:vector<address>,
        cooperator:vector<address>,
        inspector:vector<address>
    }

    fun init_module(zkme: &signer){
        move_to(zkme, Role{
            admin: signer::address_of(zkme),
            operator: vector::empty<address>(),
            cooperator: vector::empty<address>(),
            inspector: vector::empty<address>()
        });
    }

    public fun assert_admin(admin:&signer) acquires Role{
        let role = borrow_global_mut<Role>(@zkme);
        assert!(&signer::address_of(admin) == &role.admin,
            error::permission_denied(E_NOT_ADMIN)
        );
    }

    fun is_admin(
        admin:&signer
    ):bool acquires Role{
        let role = borrow_global_mut<Role>(@zkme);
        if (&signer::address_of(admin) == &role.admin){
            return true
        };
        return false
    }

    public entry fun grant_operator(
        admin: &signer,
        account: address
    ) acquires Role{
        assert_admin(admin);
        let role = borrow_global_mut<Role>(@zkme);
        if (!vector::contains(&role.operator, &account)){
            vector::push_back(&mut role.operator, account);
        }
    }

    public entry fun revoke_operator(
        admin: &signer,
        account: address
    ) acquires Role{
        assert_admin(admin);
        let role = borrow_global_mut<Role>(@zkme);
        let (b,i) = vector::index_of(&role.operator, &account);
        if (b) {
            vector::remove(&mut role.operator, i);
        }
    }

    public fun assert_operator(
        account: address
    ) acquires Role{
        let role = borrow_global<Role>(@zkme);
        assert!(vector::contains(&role.operator, &account),
            error::permission_denied(E_NOT_OPERATOR)
        );
    }

    #[view]
    public fun is_operator(
        account: address
    ):bool acquires Role{
        let role = borrow_global<Role>(@zkme);
        vector::contains(&role.operator, &account)
    }


    public entry fun grant_cooperator(
        admin: &signer,
        account: address
    ) acquires Role{
        assert!(!is_admin(admin) || !is_operator(signer::address_of(admin)),error::permission_denied(E_NOT_ADMIN));
        let role = borrow_global_mut<Role>(@zkme);
        if (!vector::contains(&role.cooperator, &account)){
            vector::push_back(&mut role.cooperator, account);
        };
    }

    public entry fun revoke_cooperator(
        admin: &signer,
        account: address
    ) acquires Role{
        assert!(!is_admin(admin) || !is_operator(signer::address_of(admin)),error::permission_denied(E_NOT_ADMIN));
        let role = borrow_global_mut<Role>(@zkme);
        let (b,i) = vector::index_of(&role.cooperator, &account);
        if (b) {
            vector::remove(&mut role.cooperator, i);
        }
    }

    public fun assert_cooperator(
        account: address
    ) acquires Role{
        let role = borrow_global<Role>(@zkme);
        assert!(vector::contains(&role.cooperator, &account),
            error::permission_denied(E_NOT_COOPERATOR)
        );
    }

    #[view]
    public fun is_cooperator(
        account: address
    ):bool acquires Role{
        let role = borrow_global<Role>(@zkme);
        vector::contains(&role.cooperator, &account)
    }

    public entry fun grant_inspector(
        admin: &signer,
        account: address
    ) acquires Role{
        assert!(!is_admin(admin) || !is_operator(signer::address_of(admin)),error::permission_denied(E_NOT_ADMIN));
        let role = borrow_global_mut<Role>(@zkme);
        if (!vector::contains(&role.inspector, &account)){
            vector::push_back(&mut role.inspector, account);
        }
    }

    public entry fun revoke_inspector(
        admin: &signer, 
        account: address
    ) acquires Role{
        assert!(!is_admin(admin) || !is_operator(signer::address_of(admin)),error::permission_denied(E_NOT_ADMIN));
        let role = borrow_global_mut<Role>(@zkme);
        let (b,i) = vector::index_of(&role.inspector, &account);
        if (b) {
            vector::remove(&mut role.inspector, i);
        }
    }

    public fun assert_inspector(
        account: address
    ) acquires Role{
        let role = borrow_global<Role>(@zkme);
        assert!(vector::contains(&role.inspector, &account),
            error::permission_denied(E_NOT_INSPECTOR)
        );
    }

    #[view]
    public fun is_inspector(
        account: address
    ):bool acquires Role{
        let role = borrow_global<Role>(@zkme);
        vector::contains(&role.inspector, &account)
    }


    #[test(admin=@zkme,operator_a=@0x11,operator_b=@0x12,cooperator_a=@0x21,cooperator_b=@0x22,inspector_a=@0x31,inspector_b=@0x32)]
    public fun add_remove_role(
        admin: signer,
        operator_a: signer,
        operator_b: signer,
        cooperator_a: signer,
        cooperator_b: signer,
        inspector_a: signer,
        inspector_b: signer,
    ) acquires Role{

        use aptos_framework::account;
        account::create_account_for_test(signer::address_of(&admin));
        account::create_account_for_test(signer::address_of(&operator_a));
        account::create_account_for_test(signer::address_of(&operator_b));
        account::create_account_for_test(signer::address_of(&cooperator_a));
        account::create_account_for_test(signer::address_of(&cooperator_b));
        account::create_account_for_test(signer::address_of(&inspector_a));
        account::create_account_for_test(signer::address_of(&inspector_b));
        init_module(&admin);
        grant_operator(&admin, signer::address_of(&operator_a));
        assert_operator(signer::address_of(&operator_a));
        assert!(is_operator(signer::address_of(&operator_a)),1);
        grant_operator(&admin, signer::address_of(&operator_b));
        assert_operator(signer::address_of(&operator_b));
        assert!(is_operator(signer::address_of(&operator_b)),2);
        revoke_operator(&admin, signer::address_of(&operator_a));
        assert!(!is_operator(signer::address_of(&operator_a)),3);
        grant_cooperator(&admin, signer::address_of(&cooperator_a));
        grant_cooperator(&admin, signer::address_of(&cooperator_b));
        assert_cooperator(signer::address_of(&cooperator_a));
        assert!(is_cooperator(signer::address_of(&cooperator_a)),4);
        assert_cooperator(signer::address_of(&cooperator_b));
        assert!(is_cooperator(signer::address_of(&cooperator_b)),5);
        revoke_cooperator(&admin, signer::address_of(&cooperator_a));
        assert!(!is_cooperator(signer::address_of(&cooperator_a)),6);

        grant_inspector(&admin, signer::address_of(&inspector_a));
        grant_inspector(&admin, signer::address_of(&inspector_b));
        assert_inspector(signer::address_of(&inspector_a));
        assert!(is_inspector(signer::address_of(&inspector_a)),7);
        assert_inspector(signer::address_of(&inspector_b));
        assert!(is_inspector(signer::address_of(&inspector_b)),8);
        revoke_inspector(&admin, signer::address_of(&inspector_a));
        assert!(!is_inspector(signer::address_of(&inspector_a)),9);
    }

    #[test(admin=@zkme,operator_a=@0x11,operator_b=@0x12,cooperator_a=@0x21,cooperator_b=@0x22,inspector_a=@0x31,inspector_b=@0x32)]
    #[expected_failure]
    public fun grant_twice(
        admin: signer,
        operator_a: signer,
        cooperator_a: signer,
        inspector_a: signer,
    )acquires Role{
        use aptos_framework::account;
        account::create_account_for_test(signer::address_of(&admin));
        account::create_account_for_test(signer::address_of(&operator_a));
        account::create_account_for_test(signer::address_of(&cooperator_a));
        account::create_account_for_test(signer::address_of(&inspector_a));

        init_module(&admin);
        grant_operator(&admin, signer::address_of(&operator_a));
        grant_operator(&admin, signer::address_of(&operator_a));
        assert!(!is_operator(signer::address_of(&operator_a)),1);
        grant_cooperator(&admin, signer::address_of(&cooperator_a));
        grant_cooperator(&admin, signer::address_of(&cooperator_a));
        assert!(!is_cooperator(signer::address_of(&cooperator_a)),2);
        grant_inspector(&admin, signer::address_of(&inspector_a));
        grant_inspector(&admin, signer::address_of(&inspector_a));
        assert!(!is_inspector(signer::address_of(&inspector_a)),3);
    }

    #[test(admin=@zkme,operator_a=@0x11,operator_b=@0x12,cooperator_a=@0x21,cooperator_b=@0x22,inspector_a=@0x31,inspector_b=@0x32)]
    #[expected_failure]
    public fun revoke_twice(
        admin: signer,
        operator_a: signer,
        cooperator_a: signer,
        inspector_a: signer,
    )acquires Role{
        use aptos_framework::account;
        account::create_account_for_test(signer::address_of(&admin));
        account::create_account_for_test(signer::address_of(&operator_a));
        account::create_account_for_test(signer::address_of(&cooperator_a));
        account::create_account_for_test(signer::address_of(&inspector_a));
        init_module(&admin);
        grant_operator(&admin, signer::address_of(&operator_a));
        revoke_operator(&admin, signer::address_of(&operator_a));
        revoke_operator(&admin, signer::address_of(&operator_a));
        assert!(is_operator(signer::address_of(&operator_a)),1);
        grant_cooperator(&admin, signer::address_of(&cooperator_a));
        revoke_cooperator(&admin, signer::address_of(&cooperator_a));
        revoke_cooperator(&admin, signer::address_of(&cooperator_a));
        assert!(is_cooperator(signer::address_of(&cooperator_a)),2);
        grant_inspector(&admin, signer::address_of(&inspector_a));
        revoke_inspector(&admin, signer::address_of(&inspector_a));
        revoke_inspector(&admin, signer::address_of(&inspector_a));
        assert!(is_inspector(signer::address_of(&inspector_a)),3);
    }
}