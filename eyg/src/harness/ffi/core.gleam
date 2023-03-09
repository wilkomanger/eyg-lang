import gleam/io
import eyg/analysis/typ as t
import eygir/encode
import eyg/runtime/interpreter as r
import eyg/runtime/capture

pub fn equal() {
  let type_ =
    t.Fun(t.Unbound(0), t.Open(1), t.Fun(t.Unbound(0), t.Open(2), t.boolean))
  #(type_, r.Arity2(do_equal))
}

fn do_equal(left, right, _builtins, k) {
  case left == right {
    True -> r.true
    False -> r.false
  }
  |> r.continue(k, _)
}

pub fn debug() {
  r.Arity1(do_debug)
}

fn do_debug(term, _builtins, k) {
  r.continue(k, r.Binary(r.to_string(term)))
}

pub fn fix() {
  r.Arity1(do_fix)
}

fn do_fix(builder, builtins, k) {
  r.eval_call(builder, builder, builtins, k)
}

fn fixed(builder) {
  io.debug(builder)
  // let builtins = todo
  // r.Builtin(fn(arg, inner_k) {
  //   r.eval_call(
  //     builder,
  //     fixed(builder),
  //     builtins,
  //     r.eval_call(_, arg, builtins, inner_k),
  //   )
  // })
}

// A Defunc where the switch takes all options for stdlib is effctive
// but it ties implementation of the interpreter to the std library that is used
// Also what AST node do we capture to. Variables could always be over written

// // THis should be replaced by capture which returns ast
pub fn serialize() {
  r.Arity1(do_serialize)
  //   // let typ =
  //   //   t.Fun(t.Fun(t.Unbound(-1), t.Open(-2), t.Unbound(-2)), t.Open(-3), t.Binary)

  //   // let value =
  //   //   r.Builtin(fn(builder, _builtins,  k) {
  //   //   })
  //   // #(typ, value)
}

pub fn do_serialize(term, _builtins, k) {
  let exp = capture.capture(term)
  r.continue(k, r.Binary(encode.to_json(exp)))
}
