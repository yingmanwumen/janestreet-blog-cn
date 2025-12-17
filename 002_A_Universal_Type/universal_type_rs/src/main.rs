use std::any::{Any, TypeId};

struct UnivT {
    type_id: TypeId,
    value: Box<dyn Any>,
}

impl UnivT {
    fn new<A: Any + Clone>(val: &A) -> Self {
        UnivT {
            type_id: TypeId::of::<A>(),
            value: Box::new(val.clone()),
        }
    }

    fn unembed_ref<A: Any + 'static>(&self) -> Option<&A> {
        match self.type_id == TypeId::of::<A>() {
            true => self.value.downcast_ref(),
            _ => None,
        }
    }

    pub fn embed<A: Any + Clone>() -> (impl Fn(&A) -> UnivT, impl Fn(&UnivT) -> Option<A>) {
        let of_t = |val: &A| UnivT::new(val);
        let to_t = |val: &UnivT| val.unembed_ref::<A>().cloned();
        (of_t, to_t)
    }
}

mod test_module {
    use super::*;

    pub fn run_test() {
        let (of_int, to_int) = UnivT::embed::<i32>();
        let (_, to_int2) = UnivT::embed::<i32>();
        let (of_string, to_string) = UnivT::embed::<String>();

        let r = of_int(&13); // r := of_int 13

        assert_eq!(to_int(&r), Some(13));
        assert_eq!(to_int2(&r), None); // Different place between Rust and OCaml
        assert_eq!(to_string(&r), None);

        let r = of_string(&"foo".to_string()); // r := of_string "foo"

        assert_eq!(to_int(&r), None);
        assert_eq!(to_string(&r), Some("foo".to_string()));

        println!("Rust Test Passed!");
    }
}

fn main() {
    test_module::run_test();
}
