import gleam/io
import gleam/list
import gleam/option.{None, Option, Some}

// Use opaque type to keep in type information
pub type Expression(t) {
  // Pattern is name in Let
  Let(name: String, value: #(t, Expression(t)), in: #(t, Expression(t)))
  Var(name: String)
  Binary
  Case
  Tuple
  // arguments are names only
  Function(arguments: List(#(t, String)), body: #(t, Expression(t)))
  Call(function: #(t, Expression(t)), arguments: List(#(t, Expression(t))))
}

pub fn let_(name, value, in) {
  #(Nil, Let(name, value, in))
}

pub fn var(name) {
  #(Nil, Var(name))
}

pub fn binary() {
  #(Nil, Binary)
}

pub fn function(for, in) {
  #(Nil, Function(for, in))
}

pub fn call(function, with) {
  #(Nil, Call(function, with))
}

// Typed
pub type Type {
  Constructor(String, List(Type))
  Variable(Int)
}

// A linear type on substitutions would ensure passed around
// TODO merge substitutions, need to keep passing next var in typer
// type checker state
type Typer {
  Typer(// tracking names to types
    // environment: List(#(String, Type)),
    // typer passed as globally acumulating set, env is scoped
    substitutions: List(#(Int, Type)), next_type_var: Int)
}

fn typer() {
  Typer([], 1)
}

fn generate_type_var(typer) {
  let Typer(next_type_var: var, ..) = typer
  #(Variable(var), Typer(..typer, next_type_var: var + 1))
}

fn push_variable(environment, name, type_) {
  [#(name, type_), ..environment]
}

fn fetch_variable(environment, name) {
  case list.key_find(environment, name) {
    Ok(value) -> Ok(value)
    Error(Nil) -> Error("Variable not in environment")
  }
}

fn push_arguments(untyped, environment, typer) {
  // TODO check double names
  let #(typed, typer) = do_argument_typing(untyped, [], typer)
  let environment = do_push_arguments(typed, environment)
  #(typed, environment, typer)
}

fn do_push_arguments(typed, environment) {
  case typed {
    [] -> environment
    [#(type_, name), ..rest] ->
      do_push_arguments(rest, [#(name, type_), ..environment])
  }
}

fn do_argument_typing(arguments, typed, typer) {
  case arguments {
    [] -> #(list.reverse(typed), typer)
    [#(Nil, name), ..rest] -> {
      let #(type_, typer) = generate_type_var(typer)
      let typed = [#(type_, name), ..typed]
      do_argument_typing(rest, typed, typer)
    }
  }
}

fn do_typed_arguments_remove_name(
  remaining: List(#(Type, String)),
  accumulator: List(Type),
) -> List(Type) {
  case remaining {
    [] -> list.reverse(accumulator)
    [x, ..rest] -> {
      let #(typed, _name) = x
      do_typed_arguments_remove_name(rest, [typed, ..accumulator])
    }
  }
}

pub fn infer(untyped) {
  try #(type_, tree, typer) = do_infer(untyped, [], typer())
  let Typer(substitutions: substitutions, ..) = typer
  Ok(#(type_, tree, substitutions))
}

fn do_infer(untyped, environment, typer) {
  let #(Nil, expression) = untyped
  case expression {
    Binary -> Ok(#(Constructor("Binary", []), Binary, typer))
    Let(name: name, value: value, in: next) -> {
      try #(value_type, value_tree, typer) = do_infer(value, environment, typer)
      let environment = push_variable(environment, name, value_type)
      try #(next_type, next_tree, typer) = do_infer(next, environment, typer)
      let tree = Let(name, #(value_type, value_tree), #(next_type, next_tree))
      Ok(#(next_type, tree, typer))
    }
    Var(name) -> {
      try var_type = fetch_variable(environment, name)
      Ok(#(var_type, Var(name), typer))
    }
    Function(with, in) -> {
      // There's no lets in arguments that escape the environment so keep reusing initial environment
      let #(typed_with, environment, typer) =
        push_arguments(with, environment, typer)
      try #(in_type, in_tree, typer) = do_infer(in, environment, typer)
      let typed_with: List(#(Type, String)) = typed_with
      let constructor_arguments =
        do_typed_arguments_remove_name(typed_with, [in_type])
      let type_ = Constructor("Function", constructor_arguments)
      let tree = Function(typed_with, #(in_type, in_tree))
      Ok(#(type_, tree, typer))
    }
    // N eed to understand generics but could every typed ast have a variable
    Call(function, with) -> {
      try #(f_type, f_tree, typer) = do_infer(function, environment, typer)
      let #(return_type, typer) = generate_type_var(typer)
      // TODO args
      try typer = unify(f_type, Constructor("Function", [return_type]), typer)
      io.debug(typer)
      // todo("ooo")
      let type_ = return_type
      let tree = Call(#(f_type, f_tree), [])
            Ok(#(type_, tree, typer))

    }
  }
}

fn unify(t1, t2, typer) {
  case t1, t2 {
    t1, t2 if t1 == t2 -> Ok(typer)
    Variable(i), any -> unify_variable(i, any, typer)
       any, Variable(i) -> unify_variable(i, any, typer)
    Constructor(n1, args1), Constructor(n2, args2) -> {
      case n1 == n2 {
        True -> unify_all(args1, args2, typer)

      }
    }
  }
}

fn unify_variable(i, any, typer) {
  let Typer(substitutions: substitutions, ..) = typer
  case list.key_find(substitutions, i) {
    Ok(replacement) -> unify(replacement, any, typer)
    Error(Nil) -> case any {
      Variable(j) -> todo("check in substitution")
      // TODO occurs check
      Constructor(_, _) -> {

        let substitutions = [#(i, any), ..substitutions]
        let typer = Typer(..typer, substitutions: substitutions)
        Ok(typer)
      }
    }
  }
}

fn unify_all(t1s, t2s, typer) {
  case t1s, t2s {
    [], [] -> Ok(typer)
    [t1, ..t1s], [t2, ..t2s] -> {
      try typer = unify(t1, t2, typer)
      unify_all(t1s, t2s, typer)
    }
  }
}