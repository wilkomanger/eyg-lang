import gleam/result
import lustre
import lustre/effect as cmd
import atelier/app
import atelier/view/root
import eygir/decode

// render -> app
// main -> render
// is main in app circle
// vew depends on state
// load source can I use same static path i.e. /src/source.json
pub fn main(source) {
  let assert Ok(source) = decode.from_json(source)
  use dispatch <- result.then(
    lustre.application(
      fn() { #(app.init(source), cmd.none()) },
      app.update,
      root.render,
    )
    |> lustre.start("#app"),
  )

  listen_keypress(fn(key) { dispatch(app.Keypress(key)) })
  Ok(Nil)
}

// js(all ffi's) files need to be top level
// careful is a js not mjs file
@external(javascript, "../browser_ffi.js", "listenKeypress")
fn listen_keypress(a: fn(string) -> Nil) -> Nil
