import gleam/dynamic.{DecodeError, decode2, decode3, field, int, string}
import gleam/json
import eygir/expression as e

fn label() {
  field("label", string)
}

fn decode1(constructor, d1) {
  fn(raw) {
    try value = d1(raw)
    Ok(constructor(value))
  }
}

pub fn decoder(x) {
  try node = field("node", string)(x)
  case node {
    "variable" -> decode1(e.Variable, label())
    "function" -> decode2(e.Lambda, label(), field("body", decoder))
    "call" ->
      decode2(e.Apply, field("function", decoder), field("arg", decoder))
    "let" ->
      decode3(e.Let, label(), field("value", decoder), field("then", decoder))
    "integer" -> decode1(e.Integer, field("value", int))
    "binary" -> decode1(e.Binary, field("value", string))
    "vacant" -> fn(_) { Ok(e.Vacant) }
    "empty" -> fn(_) { Ok(e.Empty) }
    "extend" -> decode1(e.Extend, label())
    "select" -> decode1(e.Select, label())
    "tag" -> decode1(e.Tag, label())
    "case" -> decode1(e.Case, label())
    "nocases" -> fn(_) { Ok(e.NoCases) }
    "perform" -> decode1(e.Perform, label())
    incorrect -> fn(_) { Error([DecodeError("node", incorrect, ["0"])]) }
  }(
    x,
  )
}

pub fn from_json(raw) {
  json.decode(raw, decoder)
}
