import gleam/list

pub type Expression {
  Variable(label: String)
  Lambda(label: String, body: Expression)
  Apply(func: Expression, argument: Expression)
  Let(label: String, definition: Expression, body: Expression)

  // Primitive
  Integer(value: Int)
  Binary(value: String)

  Tail
  // type system won't allow improper list
  // Is there a need for first class list, not as both are addressible as expressions
  // There is an idea that I can have restrictive record etc but stil keep
  // super simple fn application
  Cons

  Vacant(comment: String)

  // Row
  Empty
  Extend(label: String)
  Select(label: String)
  Overwrite(label: String)
  Tag(label: String)
  Case(label: String)
  NoCases

  // Effect
  // do/act/effect(effect is a verb and noun)
  Perform(label: String)
  Handle(label: String)
  // Experiment in stateful Effects
  Shallow(label: String)

  Builtin(identifier: String)
}

pub const unit = Empty

pub const true = Apply(Tag("True"), unit)

pub const false = Apply(Tag("False"), unit)

pub fn list(items) {
  do_list(list.reverse(items), Tail)
}

pub fn do_list(reversed, acc) {
  case reversed {
    [item, ..rest] -> do_list(rest, Apply(Apply(Cons, item), acc))
    [] -> acc
  }
}

pub fn tagged(tag, value) {
  Apply(Tag(tag), value)
}
