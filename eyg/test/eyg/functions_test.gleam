import gleam/io
import eyg/ast
import eyg/ast/pattern
import eyg/typer.{get_type, infer, init}
import eyg/typer/monotype.{resolve}
import eyg/typer/polytype.{State}

pub fn typed_function_test() {
  let typer = init([])
  let untyped =
    ast.function(
      "x",
      ast.let_(pattern.Tuple([]), ast.variable("x"), ast.binary("")),
    )
  let Ok(#(type_, typer)) = infer(untyped, typer)
  let State(substitutions: substitutions, ..) = typer

  let Ok(type_) = get_type(type_)

  let monotype.Function(monotype.Tuple([]), monotype.Binary) =
    resolve(type_, substitutions)
}

pub fn generic_function_test() {
  let typer = init([])
  let untyped = ast.function("x", ast.variable("x"))
  let Ok(#(type_, typer)) = infer(untyped, typer)
  let State(substitutions: substitutions, ..) = typer

  let Ok(type_) = get_type(type_)

  let monotype.Function(monotype.Unbound(a), monotype.Unbound(b)) =
    resolve(type_, substitutions)
  let True = a == b
}

pub fn call_function_test() {
  let typer = init([])
  let untyped =
    ast.call(
      ast.function(
        "x",
        ast.let_(pattern.Tuple([]), ast.variable("x"), ast.binary("")),
      ),
      ast.tuple_([]),
    )
  let Ok(#(type_, typer)) = infer(untyped, typer)
  let State(substitutions: substitutions, ..) = typer

  let Ok(type_) = get_type(type_)

  let monotype.Binary = resolve(type_, substitutions)
}

pub fn call_generic_test() {
  let typer = init([])
  let untyped = ast.call(ast.function("x", ast.variable("x")), ast.tuple_([]))
  let Ok(#(type_, typer)) = infer(untyped, typer)
  let State(substitutions: substitutions, ..) = typer

  let Ok(type_) = get_type(type_)

  let monotype.Tuple([]) = resolve(type_, substitutions)
}

pub fn call_with_incorrect_argument_test() {
  let typer = init([])
  let untyped =
    ast.call(
      ast.function(
        "x",
        ast.let_(pattern.Tuple([]), ast.variable("x"), ast.binary("")),
      ),
      ast.tuple_([ast.binary("extra argument")]),
    )
  let Error(#(typer.IncorrectArity(0, 1), _state)) = infer(untyped, typer)
}

pub fn reuse_generic_function_test() {
  let typer = init([])
  let untyped =
    ast.let_(
      pattern.Variable("id"),
      ast.function("x", ast.variable("x")),
      ast.tuple_([
        ast.call(ast.variable("id"), ast.tuple_([])),
        ast.call(ast.variable("id"), ast.binary("")),
      ]),
    )
  let Ok(#(type_, typer)) = infer(untyped, typer)
  let State(substitutions: substitutions, ..) = typer

  let Ok(type_) = get_type(type_)

  let monotype.Tuple([monotype.Tuple([]), monotype.Binary]) =
    resolve(type_, substitutions)
}
