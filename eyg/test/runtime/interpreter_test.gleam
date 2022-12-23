import gleam/string
import gleeunit/should
import eygir/expression as e
import eyg/runtime/interpreter as r

fn id(x) {
  x
}

pub fn variable_test() {
  let source = e.Variable("x")
  r.eval(source, [#("x", r.Binary("assigned"))], id)
  |> should.equal(r.Binary("assigned"))
}

pub fn function_test() {
  let body = e.Variable("x")
  let source = e.Lambda("x", body)
  let env = [#("foo", r.Binary("assigned"))]
  r.eval(source, env, id)
  |> should.equal(r.Function("x", body, env))
}

// todo test eval_call

pub fn function_application_test() {
  let source = e.Apply(e.Lambda("x", e.Binary("body")), e.Integer(0))
  r.eval(source, [], id)
  |> should.equal(r.Binary("body"))
  let source =
    e.Let(
      "id",
      e.Lambda("x", e.Variable("x")),
      e.Apply(e.Variable("id"), e.Integer(0)),
    )
  r.eval(source, [], id)
  |> should.equal(r.Integer(0))
}

pub fn builtin_application_test() {
  let source = e.Apply(e.Variable("reverse"), e.Binary("hello"))
  let f = fn(x) {
    assert r.Binary(value) = x
    r.Binary(string.reverse(value))
  }
  r.eval(source, [#("reverse", r.Builtin(f))], id)
  |> should.equal(r.Binary("olleh"))
}

// primitive
pub fn create_a_binary_test() {
  let source = e.Binary("hello")
  r.eval(source, [], id)
  |> should.equal(r.Binary("hello"))
}

pub fn create_an_integer_test() {
  let source = e.Integer(5)
  r.eval(source, [], id)
  |> should.equal(r.Integer(5))
}

pub fn record_creation_test() {
  let source = e.Empty
  r.eval(source, [], id)
  |> should.equal(r.Record([]))

  let source =
    e.Apply(
      e.Apply(e.Extend("foo"), e.Binary("FOO")),
      e.Apply(e.Apply(e.Extend("bar"), e.Integer(0)), e.Empty),
    )
  r.eval(e.Apply(e.Select("foo"), source), [], id)
  |> should.equal(r.Binary("FOO"))
  r.eval(e.Apply(e.Select("bar"), source), [], id)
  |> should.equal(r.Integer(0))
}
