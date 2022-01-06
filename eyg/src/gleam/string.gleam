import gleam/list

external type Array(a)

if javascript {
  pub external fn concat(String, String) -> String =
    "" "String.prototype.concat.call"

  external fn js_split(String, String) -> Array(String) =
    "" "String.prototype.split.call"

  external fn array_to_list(Array(x)) -> List(x) =
    "../gleam.js" "toList"

  pub external fn starts_with(String, String) -> Bool =
    "" "String.prototype.startsWith.call"

  pub external fn replace(String, String, String) -> String =
    "" "String.prototype.replaceAll.call"
}

pub fn split(string, pattern) {
  js_split(string, pattern)
  |> array_to_list()
}

pub fn join(parts) {
  list.fold(parts, "", fn(next, buffer) { concat(buffer, next) })
}
