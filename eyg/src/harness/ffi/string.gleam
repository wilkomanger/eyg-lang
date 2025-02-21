import gleam/list
import gleam/string
import eyg/analysis/typ as t
import eyg/runtime/interpreter as r
import harness/ffi/cast

pub fn append() {
  let type_ = t.Fun(t.Binary, t.Open(0), t.Fun(t.Binary, t.Open(1), t.Binary))
  #(type_, r.Arity2(do_append))
}

pub fn do_append(left, right, rev, env, k) {
  use left <- cast.require(cast.string(left), rev, env, k)
  use right <- cast.require(cast.string(right), rev, env, k)
  r.prim(r.Value(r.Binary(string.append(left, right))), rev, env, k)
}

pub fn split() {
  let type_ =
    t.Fun(
      t.Binary,
      t.Open(0),
      t.Fun(t.Binary, t.Open(1), t.LinkedList(t.Binary)),
    )
  #(type_, r.Arity2(do_split))
}

pub fn do_split(s, pattern, rev, env, k) {
  use s <- cast.require(cast.string(s), rev, env, k)
  use pattern <- cast.require(cast.string(pattern), rev, env, k)
  let [first, ..parts] = string.split(s, pattern)
  let parts = r.LinkedList(list.map(parts, r.Binary))

  r.prim(
    r.Value(r.Record([#("head", r.Binary(first)), #("tail", parts)])),
    rev,
    env,
    k,
  )
}

pub fn uppercase() {
  let type_ = t.Fun(t.Binary, t.Open(0), t.Binary)
  #(type_, r.Arity1(do_uppercase))
}

pub fn do_uppercase(value, rev, env, k) {
  use value <- cast.require(cast.string(value), rev, env, k)
  r.prim(r.Value(r.Binary(string.uppercase(value))), rev, env, k)
}

pub fn lowercase() {
  let type_ = t.Fun(t.Binary, t.Open(0), t.Binary)
  #(type_, r.Arity1(do_lowercase))
}

pub fn do_lowercase(value, rev, env, k) {
  use value <- cast.require(cast.string(value), rev, env, k)
  r.prim(r.Value(r.Binary(string.lowercase(value))), rev, env, k)
}

pub fn length() {
  let type_ = t.Fun(t.Binary, t.Open(0), t.Integer)
  #(type_, r.Arity1(do_length))
}

pub fn do_length(value, rev, env, k) {
  use value <- cast.require(cast.string(value), rev, env, k)
  r.prim(r.Value(r.Integer(string.length(value))), rev, env, k)
}

pub fn pop_grapheme() {
  let parts =
    t.Record(t.Extend("head", t.Binary, t.Extend("tail", t.Binary, t.Closed)))
  let type_ = t.Fun(t.Binary, t.Open(1), t.result(parts, t.unit))
  #(type_, r.Arity1(do_pop_grapheme))
}

fn do_pop_grapheme(term, rev, env, k) {
  use string <- cast.require(cast.string(term), rev, env, k)
  let return = case string.pop_grapheme(string) {
    Error(Nil) -> r.error(r.unit)
    Ok(#(head, tail)) ->
      r.ok(r.Record([#("head", r.Binary(head)), #("tail", r.Binary(tail))]))
  }
  r.prim(r.Value(return), rev, env, k)
}

pub fn replace() {
  let type_ =
    t.Fun(
      t.Binary,
      t.Open(0),
      t.Fun(t.Binary, t.Open(1), t.Fun(t.Binary, t.Open(1), t.Binary)),
    )
  #(type_, r.Arity3(do_replace))
}

pub fn do_replace(in, from, to, rev, env, k) {
  use in <- cast.require(cast.string(in), rev, env, k)
  use from <- cast.require(cast.string(from), rev, env, k)
  use to <- cast.require(cast.string(to), rev, env, k)

  r.prim(r.Value(r.Binary(string.replace(in, from, to))), rev, env, k)
}
