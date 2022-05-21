import gleam/dynamic
import gleam/io
import gleam/list
import gleam/option.{None, Option, Some}
import gleam/javascript/array.{Array}
import eyg/typer/monotype as t
import eyg/ast/editor

pub type Panel {
  OnEditor
  // TODO 0 is tets suite but maybe better with enum, unlees we number mounts
  OnMounts
}

pub type Workspace(n) {
  Workspace(focus: Panel, editor: Option(editor.Editor(n)), active_mount: Int)
}

// Numbered workspaces make global things like firmata connection trick can just be named
// Bench rename panel benches?
pub type Mount {
  Static(value: String)
  String2String
  TestSuite(result: String)
  UI
}

pub fn focus_on_mount(before: Workspace(_), index) {
  let constraint = case index {
    0 ->
      t.Record(
        [
          #(
            "test",
            t.Function(
              t.Tuple([]),
              t.Union(
                variants: [#("True", t.Tuple([])), #("False", t.Tuple([]))],
                extra: None,
              ),
            ),
          ),
        ],
        Some(-1),
      )
    _ -> t.Unbound(-1)
  }
  let editor = case before.editor {
    None -> None
    Some(editor) -> {
      let editor = editor.set_constraint(editor, constraint)
      Some(editor)
    }
  }
  io.debug(constraint)
  Workspace(..before, focus: OnMounts, active_mount: index, editor: editor)
}

// CLI
// ScanCycle
// TODO add inspect to std lib
external fn inspect_gleam(a) -> String =
  "../../gleam" "inspect"

external fn inspect(a) -> String =
  "" "JSON.stringify"

pub fn mounts(state: Workspace(n)) {
  case state.editor {
    None -> []

    Some(editor) ->
      case editor.eval(editor) {
        Ok(code) ->
          [
            case dynamic.field("test", dynamic.string)(code) {
              Ok(test) -> [TestSuite(test)]
              Error(_) -> []
            },
            case dynamic.field("spreadsheet", Ok)(code) {
              Ok(test) -> [UI]
              Error(_) -> []
            },
            [Static(inspect(code))],
          ]
          |> list.flatten
        _ -> [TestSuite("True")]
      }
  }
  |> array.from_list()
}
