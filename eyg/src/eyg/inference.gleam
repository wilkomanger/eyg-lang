import gleam/io
import gleam/int
import gleam/option.{None, Some}
import gleam/string
import gleam/list
import gleam/pair
import eyg/ast/expression as e
import eyg/ast/pattern as p
import eyg/typer/monotype as t
import eyg/typer

pub fn do_unify(
  pair: #(t.Monotype(n), t.Monotype(n)),
  state: State(n),
) -> Result(State(n), typer.Reason(n)) {
  let #(t1, t2) = pair
  case t1, t2 {
    t.Unbound(i), t.Unbound(j) if i == j -> Ok(state)
    t.Unbound(i), _ ->
      case list.key_find(state.substitutions, i) {
        Ok(t1) -> do_unify(#(t1, t2), state)
        Error(Nil) -> Ok(add_substitution(i, t2, state))
      }
    _, t.Unbound(j) ->
      case list.key_find(state.substitutions, j) {
        Ok(t2) -> do_unify(#(t1, t2), state)
        Error(Nil) -> Ok(add_substitution(j, t1, state))
      }
    t.Native(n1), t.Native(n2) if n1 == n2 -> Ok(state)
    t.Binary, t.Binary -> Ok(state)
    t.Tuple(e1), t.Tuple(e2) ->
      case list.zip(e1, e2) {
        Ok(pairs) -> list.try_fold(pairs, state, do_unify)
        Error(#(c1, c2)) -> Error(typer.IncorrectArity(c1, c2))
      }
    t.Row(row1, extra1), t.Row(row2, extra2) -> {
      let #(unmatched1, unmatched2, shared) = typer.group_shared(row1, row2)
      let #(i, state) = fresh(state)
      try state = case unmatched2, extra1 {
        [], _ -> Ok(state)
        only, Some(i) -> Ok(add_substitution(i, t.Row(only, Some(i)), state))
        only, None -> Error(typer.UnexpectedFields(only))
      }
      try state = case unmatched1, extra2 {
        [], _ -> Ok(state)
        only, Some(i) -> Ok(add_substitution(i, t.Row(only, Some(i)), state))
        only, None -> Error(typer.MissingFields(only))
      }
      list.try_fold(shared, state, do_unify)
    }
    t.Function(from1, to1), t.Function(from2, to2) -> {
      try state = do_unify(#(from1, from2), state)
      do_unify(#(to1, to2), state)
    }
    _, _ -> Error(typer.UnmatchedTypes(t1, t2))
  }
}

fn add_substitution(i, type_, state: State(n)) -> State(n) {
  // These checks arrive too late end up with reursive type only existing in first recursion
  // We assume i doesn't occur in substitutions
  // let check =
  //   list.contains(free_in_type(do_resolve(type_, substitutions, [])), i)
  // let type_ = case check {
  //   True -> {
  //     io.debug("============")
  //     io.debug(i)
  //     io.debug(type_)
  //     t.Recursive(i, type_)
  //   }
  //   False -> type_
  // }
  let substitutions = [#(i, type_), ..state.substitutions]
  State(..state, substitutions: substitutions)
}

fn unify(t1, t2, state: State(n)) {
  // let State(substitutions: s, ..) = state
  // try s = do_unify(#(t1, t2), s)
  // //   TODO add errors here
  // Ok(State(..state, substitutions: s))
  do_unify(#(t1, t2), state)
}

// relies on type having been resolved
fn do_free_in_type(type_, set) {
  case type_ {
    t.Unbound(i) -> push_new(i, set)
    t.Native(_) | t.Binary -> set
    t.Tuple(elements) -> list.fold(elements, set, do_free_in_type)
    t.Row(fields, rest) -> {
      let set =
        list.fold(
          fields,
          set,
          fn(field, set) {
            let #(_name, type_) = field
            do_free_in_type(type_, set)
          },
        )
      case rest {
        None -> set
        // Already resolved
        Some(i) -> push_new(i, set)
      }
    }
    t.Recursive(i, type_) -> {
      let inner = do_free_in_type(type_, set)
      difference(inner, [i])
    }

    t.Function(from, to) -> {
      let set = do_free_in_type(from, set)
      do_free_in_type(to, set)
    }
  }
}

pub fn free_in_type(t) {
  do_free_in_type(t, [])
}

pub fn do_free_in_polytype(poly, substitutions) {
  let #(quantifiers, mono) = poly
  let mono = resolve(mono, substitutions)
  difference(free_in_type(mono), quantifiers)
}

pub fn do_free_in_env(env, substitutions, set) {
  case env {
    [] -> set
    [#(_, polytype), ..env] -> {
      let set = union(do_free_in_polytype(polytype, substitutions), set)
      do_free_in_env(env, substitutions, set)
    }
  }
}

pub fn free_in_env(env, substitutions) {
  do_free_in_env(env, substitutions, [])
}

// TODO smart filter or stateful env
// |> list.filter(fn(i) { is_not_free_in_env(i, substitutions, env) })
//   Hmm have Native(Letter) in the type and list of strings in the parameters
// can't be new numbers
// Dont need to be named can just use initial i's discovered
pub fn generalise(mono, substitutions, env) {
  let mono = resolve(mono, substitutions)
  let type_params =
    difference(free_in_type(mono), free_in_env(env, substitutions))
  #(type_params, mono)
}

// Need to handle having recursive type on it's own. i.e. i needs to be in Recursive(i, inner)
pub fn instantiate(poly, state) {
  let #(forall, mono) = poly
  let #(substitutions, state) =
    list.map_state(
      forall,
      state,
      fn(i, state) {
        // TODO with zip
        let #(tj, state) = fresh(state)
        #(#(i, tj), state)
      },
    )
  let t = do_resolve(mono, substitutions, [])
  #(t, state)
}

pub fn print(t, state) {
  let type_ = resolve(t, state)
  let #(rendered, _) = to_string(type_, [])
  rendered
}

pub fn to_string(t, used) {
  // Having structural types would allow replacing integer variables with letter variables easily in a substitution
  // a function to list variable types would allow a simple substitution
  // A lot easier to debug if not using used as part of this
  case t {
    t.Unbound(i) -> {
      let used = push_new(i, used)
      assert Ok(index) = index(used, i)
      #(int.to_string(index), used)
    }
    t.Recursive(i, t) -> {
      let used = push_new(i, used)
      let #(inner, used) = to_string(t, used)
      assert Ok(index) = index(used, i)
      let rendered = string.join(["μ", int.to_string(index), ".", inner])
      #(rendered, used)
    }
    t.Tuple(elements) -> {
      let #(rendered, used) = list.map_state(elements, used, to_string)
      let rendered =
        string.join(["(", string.join(list.intersperse(rendered, ", ")), ")"])
      #(rendered, used)
    }
    t.Binary -> #("Binary", used)
    t.Function(from, to) -> {
      let #(from, used) = to_string(from, used)
      let #(to, used) = to_string(to, used)
      let rendered = string.join([from, " -> ", to])
      #(rendered, used)
    }
  }
}

pub fn do_resolve(type_, substitutions: List(#(Int, t.Monotype(n))), recuring) {
  case type_ {
    t.Unbound(i) ->
      case list.find(recuring, i) {
        Ok(_) -> type_
        Error(Nil) ->
          case list.key_find(substitutions, i) {
            Ok(t.Unbound(j)) if i == j -> type_
            Error(Nil) -> type_
            Ok(sub) -> {
              let inner = do_resolve(sub, substitutions, [i, ..recuring])
              let recursive = list.contains(free_in_type(inner), i)
              case recursive {
                False -> inner
                True -> t.Recursive(i, inner)
              }
            }
          }
      }
    // This needs to exist as might already have been called by generalize
    t.Recursive(i, sub) -> {
      let inner = do_resolve(sub, substitutions, [i, ..recuring])
      t.Recursive(i, inner)
    }
    t.Binary -> t.Binary
    t.Tuple(elements) -> {
      let elements = list.map(elements, do_resolve(_, substitutions, recuring))
      t.Tuple(elements)
    }
    t.Row(fields, rest) -> {
      let resolved_fields =
        list.map(
          fields,
          fn(field) {
            let #(name, type_) = field
            #(name, do_resolve(type_, substitutions, recuring))
          },
        )
      case rest {
        None -> t.Row(resolved_fields, None)
        Some(i) -> {
          type_
          case do_resolve(t.Unbound(i), substitutions, recuring) {
            t.Unbound(j) -> t.Row(resolved_fields, Some(j))
            t.Row(inner, rest) ->
              t.Row(list.append(resolved_fields, inner), rest)
          }
        }
      }
    }
    t.Function(from, to) -> {
      let from = do_resolve(from, substitutions, recuring)
      let to = do_resolve(to, substitutions, recuring)
      t.Function(from, to)
    }
  }
}

pub fn resolve(t, state) {
  let State(substitutions: substitutions, ..) = state
  do_resolve(t, substitutions, [])
}

pub type State(n) {
  State(//   definetly not this
    // native_to_string: fn(n) -> String,
    next_unbound: Int, substitutions: List(#(Int, t.Monotype(n))))
}

fn fresh(state) {
  let State(next_unbound: i, ..) = state
  #(t.Unbound(i), State(..state, next_unbound: i + 1))
}

pub fn infer(untyped, expected) {
  let state = State(0, [])
  let scope = []
  do_infer(untyped, expected, state, scope)
}

// return just substitutions
fn do_infer(untyped, expected, state, scope) {
  let #(_, expression) = untyped
  case expression {
    e.Binary(value) ->
      case unify(expected, t.Binary, state) {
        Ok(state) -> #(#(Ok(expected), e.Binary(value)), state)
        Error(reason) -> #(#(Error(reason), e.Binary(value)), state)
      }
    e.Tuple(elements) -> {
      let #(with_type, state) =
        list.map_state(
          elements,
          state,
          fn(e, state) {
            let #(u, state) = fresh(state)
            #(#(e, u), state)
          },
        )
      let #(t, state) = case unify(
        expected,
        t.Tuple(list.map(with_type, pair.second)),
        state,
      ) {
        Ok(state) -> #(Ok(expected), state)
        Error(reason) -> #(Error(reason), state)
      }
      let #(elements, state) =
        list.map_state(
          with_type,
          state,
          fn(with_type, state) {
            let #(element, expected) = with_type
            do_infer(element, expected, state, scope)
          },
        )
      #(#(t, e.Tuple(elements)), state)
    }
    e.Row(fields) -> {
      // This approach fails because the fresh type is not available later
      // let #(fields, state) = list.map_state(fields, state, fn(field, state) {
      //   let #(name, untyped) = field
      //   let #(type_, state) = fresh(state)
      //   let #(typed, state) = do_infer(untyped, type_, state, scope)
      //   #(#(name, typed), state)
      // })
      // let field_types = list.map(fields, fn(field) {
      //   let #(name, typed) = field
      //   let #(Ok(type_), _tree) = typed
      //   #(name, type_)
      // })
      // let given = t.Row(field_types, None)
      // #(#(Ok(t.Tuple([])), e.Binary("")), state)
      let #(pairs, state) =
        list.map_state(
          fields,
          state,
          fn(field, state) {
            let #(name, untyped) = field
            let #(expected, state) = fresh(state)
            let row_type = #(name, expected)
            let #(typed, state) = do_infer(untyped, expected, state, scope)
            let typed_row = #(name, typed)
            #(#(row_type, typed_row), state)
          },
        )
      let #(row_types, typed_rows) = list.unzip(pairs)
      let given = t.Row(row_types, None)
      let #(t, state) = case unify(expected, given, state) {
        Ok(state) -> #(Ok(expected), state)
        Error(reason) -> #(Error(reason), state)
      }
      #(#(t, e.Row(typed_rows)), state)
    }
    e.Function(p.Variable(label), body) -> {
      let #(arg, state) = fresh(state)
      let #(return, state) = fresh(state)
      let #(body, state) =
        do_infer(body, return, state, [#(label, #([], arg)), ..scope])
      let #(t, state) = case unify(expected, t.Function(arg, return), state) {
        Ok(state) -> #(Ok(expected), state)
        Error(reason) -> #(Error(reason), state)
      }
      #(#(t, e.Function(p.Variable(label), body)), state)
    }
    e.Call(func, with) -> {
      let #(arg, state) = fresh(state)
      let #(func, state) =
        do_infer(func, t.Function(arg, expected), state, scope)
      let #(with, state) = do_infer(with, arg, state, scope)
      #(#(Ok(expected), e.Call(func, with)), state)
    }

    e.Let(p.Variable(label), value, then) -> {
      let #(u, state) = fresh(state)
      //   TODO haandle self case or variable renaming
      let value_scope = [#(label, #([], u)), ..scope]
      let #(value, state) = do_infer(value, u, state, value_scope)
      let polytype = generalise(u, state, scope)
      let #(then, state) =
        do_infer(then, expected, state, [#(label, polytype), ..scope])
      #(#(Ok(expected), e.Let(p.Variable(label), value, then)), state)
    }
    e.Variable(label) ->
      case list.key_find(scope, label) {
        Ok(polytype) -> {
          let #(monotype, state) = instantiate(polytype, state)
          case unify(expected, monotype, state) {
            Ok(state) -> #(#(Ok(expected), e.Variable(label)), state)
            Error(reason) -> #(#(Error(reason), e.Variable(label)), state)
          }
        }
        Error(Nil) -> #(
          #(Error(typer.UnknownVariable(label)), e.Variable(label)),
          state,
        )
      }
  }
}

// Set
fn push_new(item: a, set: List(a)) -> List(a) {
  case list.find(set, item) {
    Ok(_) -> set
    Error(Nil) -> [item, ..set]
  }
}

fn difference(items: List(a), excluded: List(a)) -> List(a) {
  do_difference(items, excluded, [])
}

fn do_difference(items, excluded, accumulator) {
  case items {
    [] -> list.reverse(accumulator)
    [next, ..items] ->
      case list.find(excluded, next) {
        Ok(_) -> do_difference(items, excluded, accumulator)
        Error(_) -> push_new(next, accumulator)
      }
  }
}

fn union(new: List(a), existing: List(a)) -> List(a) {
  case new {
    [] -> existing
    [next, ..new] -> {
      let existing = push_new(next, existing)
      union(new, existing)
    }
  }
}

fn do_index(list, term, count) {
  case list {
    [] -> Error(Nil)
    [item, .._] if item == term -> Ok(count)
    [_, ..list] -> do_index(list, term, count + 1)
  }
}

// set index start from back
fn index(list, term) {
  do_index(list.reverse(list), term, 0)
}
