/// This Module implements a simple set data structure
module zkme::simple_set {
    use std::error;
    use std::vector;

    const E_OUT_OF_RANGE: u64 = 1;
    const E_INVALID_ARGUMENT: u64 = 2;
    const E_VALUE_EXISTS: u64 = 3;

    struct SimpleSet<Value> has copy, drop, store {
        data: vector<Value>,
    }

    public fun create<Value: store>(): SimpleSet<Value>{
        SimpleSet<Value>{
            data: vector::empty(),
        }
    }

    public fun length<Value: store>(
        set: &SimpleSet<Value>
    ):u64{
        vector::length(&set.data)
    }


    public fun add<Value: store>(
        set: &mut SimpleSet<Value>, 
        value: Value,
    ){
        let (exists,_) = vector::index_of(&set.data, &value);
        assert!(!exists, error::invalid_argument(E_VALUE_EXISTS));
        vector::push_back(&mut set.data, value);
    }

    public fun remove<Value: store>(
        set: &mut SimpleSet<Value>,
        value: &Value,
    ): Value{
        let (b,i) = vector::index_of(&set.data, value);
        assert!(b,error::invalid_argument(E_INVALID_ARGUMENT));
        vector::swap_remove(&mut set.data, i)
    }


    public fun at<Value: store>(
        set: &SimpleSet<Value>,
        idx: u64,
    ):&Value{
        let len = vector::length(&set.data);
        assert!(idx < len || len != 0, error::out_of_range(E_OUT_OF_RANGE));
        vector::borrow(&set.data, idx)
    }

    public fun destroy_empty<Value: store>(
        set: SimpleSet<Value>,
    ){
        let SimpleSet{data} = set;
        vector::destroy_empty(data);
    }


    public fun contains<Value: store>(
        set: &SimpleSet<Value>,
        value: &Value,
    ): bool {
        let len = vector::length(&set.data);
        let i = 0;
        while(i < len){
            let v = vector::borrow(&set.data, i);
            if (v == value){
                return true
            };
            i = i + 1;
        };
        false
    }

    #[test]
    public fun add_remove_many(){
        let set = create<u64>();
        
        assert!(length(&set) == 0, 0);
        assert!(!contains(&set, &11), 1);
        add(&mut set, 11);
        assert!(length(&set) == 1,2);
        assert!(contains(&set, &11),3);
        assert!(at(&set, 0) == &11,4);
        add(&mut set, 12);
        add(&mut set, 13);
        add(&mut set, 14);
        assert!(length(&set) == 4,5);
        remove(&mut set, &11);
        assert!(!contains(&set, &11), 1);
        assert!(length(&set) == 3,6);
        remove(&mut set, &12);
        remove(&mut set, &13);
        remove(&mut set, &14);
        destroy_empty(set);
    }

    #[test]
    #[expected_failure]
    public fun add_twice(){
        let set = create<u64>();
        add(&mut set, 11);
        add(&mut set, 11);

        remove(&mut set, &11);
        destroy_empty(set);
    }

    #[test]
    #[expected_failure]
    public fun remove_twice(){
        let set = create<u64>();
        add(&mut set, 11);
        remove(&mut set, &11);
        remove(&mut set, &11);
        destroy_empty(set);
    }
}