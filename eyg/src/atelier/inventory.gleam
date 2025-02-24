import gleam/result
import gleam/list
import gleam/map
import gleam/string
import eygir/expression as e
import eyg/analysis/typ as t
import eyg/analysis/scheme.{Scheme}

// Names could be explorer rover scout librarian cataloge
// inventory catalog roster haystack

pub fn variables_at(environments, path) {
  use environment <- result.then(map.get(environments, path))
  Ok(variables(environment))
}

fn variables(environment) {
  environment
  |> map.to_list
  |> list.map(fn(pair) {
    let #(key, Scheme(_, type_)) = pair
    case string.starts_with(key, "ffi_") {
      True -> []
      False -> [
        #(key, e.Variable(key)),
        ..get_fields_from_type(type_)
        |> list.map(list.fold(
          _,
          #(key, e.Variable(key)),
          fn(acc, key) {
            let #(path, term) = acc
            #(string.concat([path, ".", key]), e.Apply(e.Select(key), term))
          },
        ))
      ]
    }
  })
  |> list.flatten
}

// https://github.com/midas-framework/project_wisdom/pull/57/files#diff-5330c90916d68898af54df95e986802e6e8adac3b7e621b3c08e70a30bcb5b85L1664
fn get_fields_from_type(type_) -> List(List(String)) {
  case type_ {
    t.Record(row) -> get_fields_from_row(row)
    _ -> []
  }
}

fn get_fields_from_row(row) -> List(List(String)) {
  case row {
    t.Extend(k, value, rest) -> {
      let subs = get_fields_from_type(value)
      [[k], ..list.map(subs, fn(sub) { [k, ..sub] })]
      |> list.append(get_fields_from_row(rest))
    }
    _ -> []
  }
}
