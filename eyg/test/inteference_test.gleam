import gleam/io
import gleeunit/should

pub type Expression {
  Let
  Fn(String, Expression)
  Call
  Var
  Number
}

fn continue(typ, k) {
  k(typ)
}

pub type Type {
  Unbound(Int)
  TFn(Type, Type)
  TNumber
}

pub fn do_infer(exp, expected, env, k) {
  case exp {
    Fn(x, body) -> {
      use to <- do_infer(body, expected, env)
      continue(TFn(Unbound(1), to), k)
    }
    Number -> continue(TNumber, k)
    _ -> todo
  }
}
// pub fn foo_test() {
//   use x <- do_infer(Fn("x", Number), Nil, Nil)
//   should.equal(x, TNumber)
// }
