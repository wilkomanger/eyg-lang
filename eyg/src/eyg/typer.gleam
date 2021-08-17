import gleam/io
import gleam/list
import gleam/option.{None, Some}
import eyg/ast.{
  Binary, Call, Case, Constructor, Function, Let, Name, Row, Tuple, Variable,
}
import eyg/ast/pattern
import eyg/typer/monotype
import eyg/typer/polytype.{State}

// Context/typer
pub type Reason {
  IncorrectArity(expected: Int, given: Int)
  UnknownVariable(label: String)
  UnmatchedTypes(expected: monotype.Monotype, given: monotype.Monotype)
  MissingFields(expected: List(#(String, monotype.Monotype)))
  UnknownType(name: String)
  UnknownVariant(variant: String, in: String)
  DuplicateType(name: String)
}

// UnhandledVarients(remaining: List(String))
// RedundantClause(match: String)
pub fn init(variables) {
  State(variables, 0, [], [])
}

fn add_substitution(variable, resolves, typer) {
  let State(substitutions: substitutions, ..) = typer
  let substitutions = [#(variable, resolves), ..substitutions]
  State(..typer, substitutions: substitutions)
}

fn unify_pair(pair, typer) {
  let #(expected, given) = pair
  unify(expected, given, typer)
}

// monotype function??
// This will need the checker/unification/constraints data structure as it uses subsitutions and updates the next var value
// next unbound inside mono can be integer and unbound(i) outside
fn unify(expected, given, typer) {
  let State(substitutions: substitutions, ..) = typer
  let expected = monotype.resolve(expected, substitutions)
  let given = monotype.resolve(given, substitutions)
  case expected, given {
    monotype.Binary, monotype.Binary -> Ok(typer)
    monotype.Tuple(expected), monotype.Tuple(given) ->
      case list.zip(expected, given) {
        Error(#(expected, given)) -> Error(IncorrectArity(expected, given))
        Ok(pairs) -> list.try_fold(pairs, typer, unify_pair)
      }
    monotype.Unbound(i), any -> Ok(add_substitution(i, any, typer))
    any, monotype.Unbound(i) -> Ok(add_substitution(i, any, typer))
    monotype.Row(expected, expected_extra), monotype.Row(given, given_extra) -> {
      let #(expected, given, shared) = group_shared(expected, given)
      let #(x, typer) = polytype.next_unbound(typer)
      try typer = case given, expected_extra {
        [], _ -> Ok(typer)
        only, Some(i) ->
          Ok(add_substitution(i, monotype.Row(only, Some(x)), typer))
        only, None -> Error(MissingFields(only))
      }
      try typer = case expected, given_extra {
        [], _ -> Ok(typer)
        only, Some(i) ->
          Ok(add_substitution(i, monotype.Row(only, Some(x)), typer))
        only, None -> Error(MissingFields(only))
      }
      list.try_fold(shared, typer, unify_pair)
    }
    monotype.Nominal(expected_name, expected_parameters), monotype.Nominal(
      given_name,
      given_parameters,
    ) -> {
      try _ = case expected_name == given_name {
        True -> Ok(Nil)
        False -> Error(UnmatchedTypes(expected, given))
      }
      case list.zip(expected_parameters, given_parameters) {
        Error(#(_expected, _given)) ->
          todo("I don't think we should ever fail here")
        Ok(pairs) -> list.try_fold(pairs, typer, unify_pair)
      }
    }
    monotype.Function(expected_from, expected_return), monotype.Function(
      given_from,
      given_return,
    ) -> {
      try typer = unify(expected_from, given_from, typer)
      unify(expected_return, given_return, typer)
    }
    expected, given -> Error(UnmatchedTypes(expected, given))
  }
}

fn group_shared(left, right) {
  do_group_shared(left, right, [], [])
}

fn do_group_shared(left, right, only_left, shared) {
  case left {
    [] -> #(list.reverse(only_left), right, list.reverse(shared))
    [#(k, left_value), ..left] ->
      case list.key_pop(right, k) {
        Ok(#(right_value, right)) -> {
          let shared = [#(left_value, right_value), ..shared]
          do_group_shared(left, right, only_left, shared)
        }
        Error(Nil) -> {
          let only_left = [#(k, left_value), ..only_left]
          do_group_shared(left, right, only_left, shared)
        }
      }
  }
}

// scope functions
fn get_variable(label, state) {
  let State(variables: variables, ..) = state
  case list.key_find(variables, label) {
    Ok(polytype) -> Ok(polytype.instantiate(polytype, state))
    Error(Nil) -> Error(UnknownVariable(label))
  }
}

fn set_variable(label, monotype, state) {
  let State(variables: variables, substitutions: substitutions, ..) = state
  let polytype =
    polytype.generalise(monotype.resolve(monotype, substitutions), state)
  let variables = [#(label, polytype), ..variables]
  State(..state, variables: variables)
}

// assignment/patterns
fn match_pattern(pattern, value, typer) {
  try #(given, typer) = infer(value, typer)
  case pattern {
    pattern.Variable(label) -> Ok(set_variable(label, given, typer))
    pattern.Tuple(elements) -> {
      let #(types, typer) =
        list.map_state(
          elements,
          typer,
          fn(label, typer) {
            let #(x, typer) = polytype.next_unbound(typer)
            let type_var = monotype.Unbound(x)
            let typer = set_variable(label, type_var, typer)
            #(type_var, typer)
          },
        )
      let expected = monotype.Tuple(types)
      unify(expected, given, typer)
    }
    pattern.Row(fields) -> {
      let #(typed_fields, typer) =
        list.map_state(
          fields,
          typer,
          fn(field, typer) {
            let #(name, label) = field
            let #(x, typer) = polytype.next_unbound(typer)
            let type_var = monotype.Unbound(x)
            let typer = set_variable(label, type_var, typer)
            #(#(name, type_var), typer)
          },
        )
      let #(x, typer) = polytype.next_unbound(typer)
      let expected = monotype.Row(typed_fields, Some(x))
      unify(expected, given, typer)
    }
  }
}

// inference fns
fn infer_field(field, typer) {
  let #(name, tree) = field
  try #(type_, typer) = infer(tree, typer)
  Ok(#(#(name, type_), typer))
}

pub fn infer(
  tree: ast.Node,
  typer: State,
) -> Result(#(monotype.Monotype, State), Reason) {
  case tree {
    Binary(_) -> Ok(#(monotype.Binary, typer))
    Tuple(elements) -> {
      // infer_with_scope(s)
      try #(types, typer) = list.try_map_state(elements, typer, infer)
      Ok(#(monotype.Tuple(types), typer))
    }
    Row(fields) -> {
      try #(types, typer) = list.try_map_state(fields, typer, infer_field)
      Ok(#(monotype.Row(types, None), typer))
    }
    Variable(label) -> {
      try #(type_, typer) = get_variable(label, typer)
      Ok(#(type_, typer))
    }
    Let(pattern, value, then) -> {
      try typer = match_pattern(pattern, value, typer)
      infer(then, typer)
    }
    Function(label, body) -> {
      let #(x, typer) = polytype.next_unbound(typer)
      let type_var = monotype.Unbound(x)
      // TODO remove this nesting when we(if?) separate typer and scope
      let State(variables: variables, ..) = typer
      let typer = set_variable(label, type_var, typer)
      try #(return, typer) = infer(body, typer)
      let typer = State(..typer, variables: variables)
      Ok(#(monotype.Function(type_var, return), typer))
    }
    Call(function, with) -> {
      try #(function_type, typer) = infer(function, typer)
      try #(with_type, typer) = infer(with, typer)
      let #(x, typer) = polytype.next_unbound(typer)
      let return_type = monotype.Unbound(x)
      try typer =
        unify(function_type, monotype.Function(with_type, return_type), typer)
      Ok(#(return_type, typer))
    }
    Name(new_type, then) -> {
      let #(named, _construction) = new_type
      let State(nominal: nominal, ..) = typer
      case list.key_find(nominal, named) {
        Error(Nil) -> {
          let typer = State(..typer, nominal: [new_type, ..nominal])
          infer(then, typer)
        }
        Ok(_) -> Error(DuplicateType(named))
      }
    }
    Constructor(named, variant) -> {
      let State(nominal: nominal, ..) = typer
      case list.key_find(nominal, named) {
        Ok(#(parameters, variants)) ->
          case list.key_find(variants, variant) {
            Ok(argument) -> {
              // The could be generated in the name phase
              let polytype =
                polytype.Polytype(
                  parameters,
                  monotype.Function(
                    argument,
                    monotype.Nominal(
                      named,
                      list.map(parameters, monotype.Unbound),
                    ),
                  ),
                )
              let #(monotype, typer) = polytype.instantiate(polytype, typer)
              Ok(#(monotype, typer))
            }
            Error(Nil) -> Error(UnknownVariant(variant, named))
          }
        Error(Nil) -> Error(UnknownType(named))
      }
    }
    Case(named, subject, clauses) -> {
      let State(nominal: nominal, ..) = typer
      case list.key_find(nominal, named) {
        // Think the old version errored by instantiating everytime
        Ok(#(parameters, variants)) -> {
          let #(replacements, typer) =
            list.map_state(
              parameters,
              typer,
              fn(parameter, typer) {
                let #(replacement, typer) = polytype.next_unbound(typer)
                let pair = #(parameter, replacement)
                #(pair, typer)
              },
            )
          let expected =
            pair_replace(
              replacements,
              monotype.Nominal(named, list.map(parameters, monotype.Unbound)),
            )
          try #(subject_type, typer) = infer(subject, typer)
          try typer = unify(expected, subject_type, typer)
          let #(x, typer) = polytype.next_unbound(typer)
          let return_type = monotype.Unbound(x)
          let State(variables: variables, ..) = typer
          // put variants in here
          try #(_, typer) =
            list.try_map_state(
              clauses,
              typer,
              fn(clause, typer) {
                let #(variant, variable, then) = clause
                assert Ok(argument) = list.key_find(variants, variant)
                let argument = pair_replace(replacements, argument)
                // reset scope variables
                let typer = State(..typer, variables: variables)
                let typer = set_variable(variable, argument, typer)
                try #(type_, typer) = infer(then, typer)
                try typer = unify(return_type, type_, typer)
                Ok(#(Nil, typer))
              },
            )
          Ok(#(return_type, typer))
        }
        Error(Nil) -> Error(UnknownType(named))
      }
    }
  }
}

fn pair_replace(replacements, monotype) {
  list.fold(
    replacements,
    monotype,
    fn(pair, monotype) {
      let #(x, y) = pair
      polytype.replace_variable(monotype, x, y)
    },
  )
}
