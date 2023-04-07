import gleam/result
// this can define state and UI maybe UI should be separate
import gleam/io
import gleam/int
import gleam/list
import gleam/map
import gleam/option.{None, Option, Some}
import gleam/set
import gleam/string
import gleam/fetch
import gleam/http
import gleam/http/request
import gleam/javascript
import lustre/cmd
import atelier/transform.{Act}
import eygir/expression as e
import eygir/encode
import eyg/analysis/inference
import eyg/runtime/standard
import eyg/incremental/source as incremental
import eyg/incremental/inference as new_i
import eyg/incremental/cursor
import eyg/incremental/store
import eyg/analysis/substitutions as sub
import eyg/analysis/env

pub type WorkSpace {
  WorkSpace(
    selection: List(Int),
    source: e.Expression,
    inferred: Option(inference.Infered),
    mode: Mode,
    yanked: Option(e.Expression),
    error: Option(String),
    history: #(
      List(#(e.Expression, List(Int))),
      List(#(e.Expression, List(Int))),
    ),
    incremental: new_i.Cache,
  )
}

pub type Mode {
  Navigate(actions: transform.Act)
  WriteLabel(value: String, commit: fn(String) -> e.Expression)
  WriteText(value: String, commit: fn(String) -> e.Expression)
  WriteNumber(value: Int, commit: fn(Int) -> e.Expression)
  WriteTerm(value: String, commit: fn(e.Expression) -> e.Expression)
}

pub type Action {
  Keypress(key: String)
  Change(value: String)
  Commit
  SelectNode(path: List(Int))
  ClickOption(chosen: e.Expression)
}

external fn pnow() -> Int =
  "" "performance.now"

pub fn init(source) {
  let assert Ok(act) = transform.prepare(source, [])
  let mode = Navigate(act)

  let path = [1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0]
  let start = pnow()
  let #(root, s) = store.load(store.empty(), source)
  io.debug(#(
    "loading store took ms:",
    pnow() - start,
    root,
    map.size(s.source),
    map.size(s.free),
  ))

  let start = pnow()
  let assert Ok(#(vars, s, x)) = store.free(s, root, [])
  // OK map works
  io.debug(#("othr", list.length(x)))
  // TODO i think should be same size
  io.debug(#(
    "memoizing free took ms:",
    pnow() - start,
    map.size(s.source),
    map.size(s.free),
    vars
    |> set.to_list,
  ))
  io.debug(map.get(s.source, root))
  io.debug(map.get(s.source, root - 1))
  io.debug(map.get(s.source, root - 2))
  io.debug(map.get(s.source, root - 3))
  io.debug(map.get(s.source, root - 4))
  io.debug(map.get(s.source, 0))
  io.debug(map.get(s.source, 1))

  io.debug(map.get(s.free, root))
  io.debug(map.get(s.free, root - 1))
  io.debug(map.get(s.free, root - 2))
  io.debug(map.get(s.free, root - 3))
  io.debug(map.get(s.free, root - 4))
  io.debug(map.get(s.free, 0))
  io.debug(map.get(s.free, 1))

  // io.debug(#("free--", map.get(s.free, 5757)))
  io.debug(list.length(map.to_list(s.source)))

  io.debug(list.length(map.to_list(s.free)))
  // todo("wat")

  let start = pnow()
  let assert Ok(#(t, s)) = store.type_(s, root)
  // TODO i think should be same size
  io.debug(#(
    "typing took ms:",
    pnow() - start,
    map.size(s.source),
    map.size(s.free),
    map.size(s.types),
    t,
  ))

  let start = pnow()
  let assert Ok(c) = store.cursor(s, root, path)
  io.debug(#("building store.cursor took ms:", pnow() - start))
  // io.debug(c)
  let start = pnow()
  let assert Ok(#(root_, s)) = store.replace(s, c, incremental.String("hello"))
  io.debug(#(
    "updating store.replace took ms:",
    pnow() - start,
    map.size(s.source),
    map.size(s.free),
    map.size(s.types),
  ))
  let start = pnow()
  let assert Ok(#(t, s)) = store.type_(s, root_)
  // TODO i think should be same size
  io.debug(#(
    "typing took ms:",
    pnow() - start,
    map.size(s.source),
    map.size(s.free),
    map.size(s.types),
    t,
  ))

  // not helpful
  // list.map(map.to_list(s.types), io.debug)
  io.debug("------------------------")

  let start = pnow()
  let #(root, refs) = incremental.from_tree(source)
  io.debug(#("building incremental took ms:", pnow() - start, list.length(refs)))
  let start = pnow()
  let #(root, refs_map) = incremental.from_tree_map(source)
  io.debug(#(
    "building incremental map took ms:",
    pnow() - start,
    map.size(refs_map),
  ))

  let start = pnow()
  let f = new_i.free(refs, [])
  io.debug(#("finding free took ms:", pnow() - start))
  let start = pnow()
  let fm = new_i.free_map(refs, map.new())
  io.debug(#("finding free took ms:", pnow() - start))

  let count = javascript.make_reference(0)
  let start = pnow()
  let #(t, s, cache) =
    new_i.cached(root, refs, f, map.new(), env.empty(), sub.none(), count)
  io.debug(#("initial type check took ms:", pnow() - start))

  let start = pnow()
  let c = cursor.at(path, root, refs)
  io.debug(#("building cursor took ms:", pnow() - start))
  io.debug(c)

  let start = pnow()
  let refs_map =
    list.index_map(refs, fn(i, r) { #(i, r) })
    |> map.from_list()
  io.debug(#("list to map took ms:", pnow() - start))

  let start = pnow()
  let #(x, refs) = cursor.replace(e.Binary("hello"), c, refs)
  io.debug(#("replacing at cursor took ms:", pnow() - start))
  io.debug(x)

  //   let start = pnow()
  // let #(x, refs) = cursor.replace_map(e.Binary("hello"), c, refs_map)
  // io.debug(#("replacing at cursor took ms:", pnow() - start))
  // io.debug(x)

  let start = pnow()
  let f2 = new_i.free(refs, f)
  io.debug(#("f2 took ms:", pnow() - start))
  let #(t, s, cache) = new_i.cached(root, refs, f, cache, env.empty(), s, count)
  io.debug(#("partial type check took ms:", pnow() - start))
  let start = pnow()
  let fm2 = new_i.free_map(refs, fm)
  io.debug(#("finding fm2 took ms:", pnow() - start))

  let start = pnow()
  let inferred = Some(standard.infer(source))
  io.debug(#("standard infer took ms:", pnow() - start))

  // Have inference work once for showing elements but need to also background this
  WorkSpace([], source, inferred, mode, None, None, #([], []), #(s, cache))
}

pub fn update(state: WorkSpace, action) {
  case action {
    Keypress(key) -> keypress(key, state)
    Change(value) -> {
      let mode = case state.mode {
        WriteLabel(_, commit) -> WriteLabel(value, commit)
        WriteNumber(_, commit) ->
          case value {
            "" -> WriteNumber(0, commit)
            _ -> {
              let assert Ok(number) = int.parse(value)
              WriteNumber(number, commit)
            }
          }
        WriteText(_, commit) -> WriteText(value, commit)
        WriteTerm(_, commit) -> WriteTerm(value, commit)
        m -> m
      }
      let state = WorkSpace(..state, mode: mode)
      #(state, cmd.none())
    }
    Commit -> {
      let assert WriteText(current, commit) = state.mode
      let source = commit(current)
      let assert Ok(workspace) = update_source(state, source)
      #(workspace, cmd.none())
    }
    ClickOption(new) -> {
      let assert WriteTerm(_, commit) = state.mode
      let source = commit(new)
      let assert Ok(workspace) = update_source(state, source)
      #(workspace, cmd.none())
    }
    SelectNode(path) -> select_node(state, path)
  }
}

pub fn select_node(state, path) {
  let WorkSpace(source: source, ..) = state
  let assert Ok(act) = transform.prepare(source, path)
  let mode = Navigate(act)
  let state = WorkSpace(..state, source: source, selection: path, mode: mode)

  #(state, cmd.none())
}

// select node is desired action specific but keypress is user action specific.
// is this a problem?
// call click_node and then switch by state
// clicking a variable could use it in place
pub fn keypress(key, state: WorkSpace) {
  let r = case state.mode, key {
    // save in this state only because q is a normal letter needed when entering text
    Navigate(_act), "q" -> save(state)
    Navigate(act), "w" -> call_with(act, state)
    Navigate(act), "e" -> Ok(assign_to(act, state))
    Navigate(act), "r" -> record(act, state)
    Navigate(act), "t" -> Ok(tag(act, state))
    Navigate(act), "y" -> Ok(copy(act, state))
    // copy paste quite rare so we use upper case. might be best as command
    Navigate(act), "Y" -> paste(act, state)
    Navigate(act), "u" -> unwrap(act, state)
    Navigate(act), "i" -> insert(act, state)
    Navigate(act), "o" -> overwrite(act, state)
    Navigate(act), "p" -> Ok(perform(act, state))
    Navigate(_act), "a" -> increase(state)
    Navigate(act), "s" -> decrease(act, state)
    Navigate(act), "d" -> delete(act, state)
    Navigate(act), "f" -> Ok(abstract(act, state))
    Navigate(act), "g" -> select(act, state)
    Navigate(act), "h" -> handle(act, state)
    // Navigate(act), "j" -> ("down probably not")
    // Navigate(act), "k" -> ("up probably not")
    // Navigate(act), "l" -> ("right probably not")
    Navigate(_act), "z" -> undo(state)
    Navigate(_act), "Z" -> redo(state)
    Navigate(act), "x" -> list(act, state)
    Navigate(act), "c" -> call(act, state)
    Navigate(act), "v" -> Ok(variable(act, state))
    Navigate(act), "b" -> Ok(binary(act, state))
    Navigate(act), "n" -> Ok(number(act, state))
    Navigate(act), "m" -> match(act, state)
    Navigate(act), "M" -> nocases(act, state)
    // Navigate(act), " " -> ("space follow suggestion next error")
    Navigate(_), _ -> Error("no action for keypress")
    // Other mode
    WriteLabel(text, commit), k if k == "Enter" -> {
      let source = commit(text)
      update_source(state, source)
    }
    WriteLabel(_, _), _k -> Ok(state)
    WriteNumber(text, commit), k if k == "Enter" -> {
      let source = commit(text)
      update_source(state, source)
    }
    WriteNumber(_, _), _k -> Ok(state)
    WriteText(_, _), _k -> Ok(state)
    WriteTerm(new, commit), k if k == "Enter" -> {
      let assert [var, ..selects] = string.split(new, ".")
      let expression =
        list.fold(
          selects,
          e.Variable(var),
          fn(acc, select) { e.Apply(e.Select(select), acc) },
        )
      let source = commit(expression)
      update_source(state, source)
    }
    WriteTerm(_, _), _k -> Ok(state)
  }

  case r {
    // Always clear message on new keypress
    Ok(state) -> #(WorkSpace(..state, error: None), cmd.none())
    Error(message) -> #(WorkSpace(..state, error: Some(message)), cmd.none())
  }
}

// could move to a atelier/client.{save}
fn save(state: WorkSpace) {
  let request =
    request.new()
    |> request.set_method(http.Post)
    // Note needs scheme and host setting wont use fetch defaults of being able to have just a path
    |> request.set_scheme(http.Http)
    |> request.set_host("localhost:5000")
    |> request.set_path("/save")
    |> request.prepend_header("content-type", "application/json")
    |> request.set_body(encode.to_json(state.source))

  fetch.send(request)
  |> io.debug
  Ok(state)
}

fn call_with(act: Act, state) {
  let source = act.update(e.Apply(e.Vacant(""), act.target))
  update_source(state, source)
}

// e is essentially line above on a let statement.
// nested lets can only be created from the value on the right.
// moving something to a module might just have to be copy paste
fn assign_to(act: Act, state) {
  let commit = case act.target {
    e.Let(_, _, _) -> fn(text) {
      act.update(e.Let(text, e.Vacant(""), act.target))
    }
    // normally I want to add something above
    exp -> fn(text) { act.update(e.Let(text, e.Vacant(""), exp)) }
  }
  WorkSpace(..state, mode: WriteLabel("", commit))
}

fn record(act: Act, state) {
  case act.target {
    e.Vacant(_comment) ->
      act.update(e.Empty)
      |> update_source(state, _)
    e.Empty as exp | e.Apply(e.Apply(e.Extend(_), _), _) as exp -> {
      let commit = fn(text) {
        act.update(e.Apply(e.Apply(e.Extend(text), e.Vacant("")), exp))
      }
      Ok(WorkSpace(..state, mode: WriteLabel("", commit)))
    }
    exp -> {
      let commit = fn(text) {
        act.update(e.Apply(e.Apply(e.Extend(text), exp), e.Empty))
      }
      Ok(WorkSpace(..state, mode: WriteLabel("", commit)))
    }
  }
}

fn tag(act: Act, state) {
  let commit = case act.target {
    e.Vacant(_comment) -> fn(text) { act.update(e.Tag(text)) }
    exp -> fn(text) { act.update(e.Apply(e.Tag(text), exp)) }
  }
  WorkSpace(..state, mode: WriteLabel("", commit))
}

fn copy(act: Act, state) {
  WorkSpace(..state, yanked: Some(act.target))
}

fn paste(act: Act, state: WorkSpace) {
  case state.yanked {
    Some(snippet) -> {
      let source = act.update(snippet)
      update_source(state, source)
    }
    None -> Error("nothing on clipboard")
  }
}

fn unwrap(act: Act, state) {
  case act.parent {
    None -> Error("top level")
    Some(#(_i, _list, _, parent_update)) -> {
      let source = parent_update(act.target)
      update_source(state, source)
    }
  }
}

fn insert(act: Act, state) {
  let write = fn(text, build) {
    WriteLabel(text, fn(new) { act.update(build(new)) })
  }
  use mode <- result.then(case act.target {
    e.Variable(value) -> Ok(write(value, e.Variable(_)))
    e.Lambda(param, body) -> Ok(write(param, e.Lambda(_, body)))
    e.Apply(_, _) -> Error("no insert option for apply")
    e.Let(var, body, then) -> Ok(write(var, e.Let(_, body, then)))

    e.Binary(value) ->
      Ok(WriteText(value, fn(new) { act.update(e.Binary(new)) }))
    e.Integer(value) ->
      Ok(WriteNumber(value, fn(new) { act.update(e.Integer(new)) }))
    e.Tail | e.Cons -> Error("there is no insert for lists")
    e.Vacant(comment) -> Ok(write(comment, e.Vacant))
    e.Empty -> Error("empty record no insert")
    e.Extend(label) -> Ok(write(label, e.Extend))
    e.Select(label) -> Ok(write(label, e.Select))
    e.Overwrite(label) -> Ok(write(label, e.Overwrite))
    e.Tag(label) -> Ok(write(label, e.Tag))
    e.Case(label) -> Ok(write(label, e.Case))
    e.NoCases -> Error("no cases")
    e.Perform(label) -> Ok(write(label, e.Perform))
    e.Handle(label) -> Ok(write(label, e.Handle))
    e.Builtin(_) -> Error("no insert option for builtin, use stdlib references")
  })

  Ok(WorkSpace(..state, mode: mode))
}

fn overwrite(act: Act, state) {
  case act.target {
    e.Apply(e.Apply(e.Overwrite(_), _), _) as exp -> {
      let commit = fn(text) {
        act.update(e.Apply(e.Apply(e.Overwrite(text), e.Vacant("")), exp))
      }
      Ok(WorkSpace(..state, mode: WriteLabel("", commit)))
    }
    exp -> {
      let commit = fn(text) {
        // This is the same as above
        act.update(e.Apply(e.Apply(e.Overwrite(text), e.Vacant("")), exp))
      }
      Ok(WorkSpace(..state, mode: WriteLabel("", commit)))
    }
  }
}

fn increase(state: WorkSpace) {
  use selection <- result.then(case list.reverse(state.selection) {
    [_, ..rest] -> Ok(list.reverse(rest))
    [] -> Error("no increase")
  })
  let assert Ok(act) = transform.prepare(state.source, selection)
  Ok(WorkSpace(..state, selection: selection, mode: Navigate(act)))
}

fn decrease(_act, state: WorkSpace) {
  let selection = list.append(state.selection, [0])
  use act <- result.then(transform.prepare(state.source, selection))
  Ok(WorkSpace(..state, selection: selection, mode: Navigate(act)))
}

fn delete(act: Act, state) {
  // an assignment vacant or not is always deleted.
  // when deleting with a vacant as a target there is no change
  // we can instead bump up the path
  let start = pnow()
  let source = case act.target {
    e.Let(_label, _, then) -> act.update(then)
    _ -> act.update(e.Vacant(""))
  }
  let ret = update_source(state, source)
  io.debug(#("normal update took ms:", pnow() - start))

  ret
}

fn abstract(act: Act, state) {
  let commit = case act.target {
    e.Let(label, value, then) -> fn(text) {
      act.update(e.Let(label, e.Lambda(text, value), then))
    }
    exp -> fn(text) { act.update(e.Lambda(text, exp)) }
  }
  WorkSpace(..state, mode: WriteLabel("", commit))
}

fn select(act: Act, state) {
  case act.target {
    e.Let(_label, _value, _then) -> Error("can't get on let")
    exp -> {
      let commit = fn(text) { act.update(e.Apply(e.Select(text), exp)) }
      Ok(WorkSpace(..state, mode: WriteLabel("", commit)))
    }
  }
}

fn handle(act: Act, state) {
  case act.target {
    e.Let(_label, _value, _then) -> Error("can't handle on let")
    exp -> {
      let commit = fn(text) {
        act.update(e.Apply(e.Apply(e.Handle(text), e.Vacant("")), exp))
      }
      Ok(WorkSpace(..state, mode: WriteLabel("", commit)))
    }
  }
}

fn perform(act: Act, state) {
  let commit = case act.target {
    e.Let(label, _value, then) -> fn(text) {
      act.update(e.Let(label, e.Perform(text), then))
    }
    _exp -> fn(text) { act.update(e.Perform(text)) }
  }
  WorkSpace(..state, mode: WriteLabel("", commit))
}

fn undo(state: WorkSpace) {
  case state.history {
    #([], _) -> Error("No history")
    #([#(source, selection), ..rest], forward) -> {
      let history = #(rest, [#(state.source, state.selection), ..forward])
      use act <- result.then(transform.prepare(source, selection))
      // Has to already be in navigate mode to undo
      let mode = Navigate(act)
      Ok(
        WorkSpace(
          ..state,
          source: source,
          selection: selection,
          mode: mode,
          history: history,
        ),
      )
    }
  }
}

fn redo(state: WorkSpace) {
  case state.history {
    #(_, []) -> Error("No redo")
    #(backward, [#(source, selection), ..rest]) -> {
      let history = #([#(state.source, state.selection), ..backward], rest)
      use act <- result.then(transform.prepare(source, selection))
      // Has to already be in navigate mode to undo
      let mode = Navigate(act)
      Ok(
        WorkSpace(
          ..state,
          source: source,
          selection: selection,
          mode: mode,
          history: history,
        ),
      )
    }
  }
}

fn list(act: Act, state) {
  let new = case act.target {
    e.Vacant(_comment) -> e.Tail
    e.Tail | e.Apply(e.Apply(e.Cons, _), _) ->
      e.Apply(e.Apply(e.Cons, e.Vacant("")), act.target)
    _ -> e.Apply(e.Apply(e.Cons, act.target), e.Tail)
  }
  let source = act.update(new)
  update_source(state, source)
}

fn call(act: Act, state) {
  let source = act.update(e.Apply(act.target, e.Vacant("")))
  update_source(state, source)
}

fn variable(act: Act, state) {
  let commit = case act.target {
    e.Let(label, _value, then) -> fn(term) {
      act.update(e.Let(label, term, then))
    }
    _exp -> fn(term) { act.update(term) }
  }
  WorkSpace(..state, mode: WriteTerm("", commit))
}

fn binary(act: Act, state) {
  let commit = case act.target {
    e.Let(label, _value, then) -> fn(text) {
      act.update(e.Let(label, e.Binary(text), then))
    }
    _exp -> fn(text) { act.update(e.Binary(text)) }
  }
  WorkSpace(..state, mode: WriteText("", commit))
}

fn number(act: Act, state) {
  let #(v, commit) = case act.target {
    e.Let(label, _value, then) -> #(
      0,
      fn(value) { act.update(e.Let(label, e.Integer(value), then)) },
    )
    e.Integer(value) -> #(value, fn(value) { act.update(e.Integer(value)) })
    _exp -> #(0, fn(value) { act.update(e.Integer(value)) })
  }
  WorkSpace(..state, mode: WriteNumber(v, commit))
}

fn match(act: Act, state) {
  let commit = case act.target {
    // e.Let(label, value, then) -> fn(text) {
    //   act.update(e.Let(label, e.Binary(text), then))
    // }
    // Match on original value should maybe be the arg? but I like promoting first class everything
    exp -> fn(text) {
      act.update(e.Apply(e.Apply(e.Case(text), e.Vacant("")), exp))
    }
  }
  Ok(WorkSpace(..state, mode: WriteLabel("", commit)))
}

fn nocases(act: Act, state) {
  update_source(state, act.update(e.NoCases))
}

// app state actions maybe separate from ui but maybe ui files organised by mode
// update source also ends the entry state
fn update_source(state: WorkSpace, source) {
  use act <- result.then(transform.prepare(source, state.selection))
  let mode = Navigate(act)
  let #(history, inferred) = case source == state.source {
    True -> #(state.history, state.inferred)
    False -> {
      let #(backwards, _forwards) = state.history
      let history = #([#(state.source, state.selection), ..backwards], [])
      #(history, None)
    }
  }
  Ok(
    WorkSpace(
      ..state,
      source: source,
      mode: mode,
      history: history,
      inferred: inferred,
    ),
  )
}
