import gleam/dynamic.{Dynamic}
import gleam/io
import gleam/list
import gleam/map
import gleam/string
import gleam/javascript/array.{Array}

pub type Triple {
  Triple(entity: Int, attribute: String, value: Dynamic)
}

pub type Match(a) {
  Variable(String)
  Constant(a)
  Free(fn(a) -> Result(Nil, Nil))
}

pub type Pattern {
  Pattern(entity: Match(Int), attribute: Match(String), value: Match(Dynamic))
}

type Context =
  map.Map(String, Dynamic)

fn match_part(match: Match(a), part: a, context: Context) {
  case match {
    Constant(value) ->
      case value == part {
        True -> Ok(context)
        False -> Error(Nil)
      }
    Variable(x) -> {
      let part = dynamic.from(part)
      case map.get(context, x) {
        Error(Nil) -> Ok(map.insert(context, x, part))
        Ok(value) ->
          // can't call recursive with concrete types becoming dynamic
          case value == part {
            True -> Ok(context)
            False -> Error(Nil)
          }
      }
    }
    Free(f) ->
      case f(part) {
        Ok(Nil) -> Ok(context)
        Error(Nil) -> Error(Nil)
      }
  }
}

fn match_pattern(pattern: Pattern, triple: Triple, context) {
  try context = match_part(pattern.entity, triple.entity, context)
  try context = match_part(pattern.attribute, triple.attribute, context)
  try context = match_part(pattern.value, triple.value, context)
  Ok(context)
}

fn query_single(pattern, triples, context) {
  list.filter_map(triples, match_pattern(pattern, _, context))
}

fn query_where(patterns, triples) {
  list.fold(
    patterns,
    [map.new()],
    fn(contexts, pattern) {
      list.map(contexts, query_single(pattern, triples, _))
      |> list.flatten
    },
  )
}

// Not needed if I build up finds with a function
fn assert_map(l, f) {
  list.map(
    l,
    fn(el) {
      assert Ok(return) = f(el)
      return
    },
  )
}

fn actualize(context, find) {
  assert_map(find, map.get(context, _))
}

pub fn query(find find, where where, db triples) {
  let contexts = query_where(where, triples)
  list.map(contexts, actualize(_, find))
}

pub external fn movies() -> Array(#(Int, String, Dynamic)) =
  "./movies.js" "movies"

// const v = Variable
fn v(x) {
  Variable(x)
}

// const c = Constant
fn c(x) {
  Constant(x)
}

fn d(x) {
  Constant(dynamic.from(x))
}

// better API could have everything in triple be dynamic so d and c where not needed
// if a function could be called ? that would do variable great
// Is a list of Pattern(..) nicer than list of #(..) (Tuples)

pub fn magpie_test() {
  let db = array.to_list(movies())
  assert [#(e, a, _), ..] = db
  assert 100 = e
  assert "person/name" = a
  let db = list.map(db, fn(x) { Triple(x.0, x.1, x.2) })

  // io.debug("===============")
  query(
    find: ["?year"],
    where: [
      Pattern(v("?id"), c("movie/title"), d("Alien")),
      Pattern(v("?id"), c("movie/year"), v("?year")),
    ],
    db: db,
  )
  // |> io.debug
  // io.debug("===============")
  query(
    find: ["?attr", "?value"],
    where: [Pattern(c(200), v("?attr"), v("?value"))],
    db: db,
  )

  // |> io.debug
  // io.debug("===============")
  query(
    find: ["directorName", "movieTitle"],
    where: [
      Pattern(v("arnoldId"), c("person/name"), d("Arnold Schwarzenegger")),
      Pattern(v("movieId"), c("movie/cast"), v("arnoldId")),
      Pattern(v("movieId"), c("movie/title"), v("movieTitle")),
      Pattern(v("movieId"), c("movie/director"), v("directorId")),
      Pattern(v("directorId"), c("person/name"), v("directorName")),
    ],
    db: db,
  )
  // |> io.debug
  // io.debug("===============")
  query(
    find: ["name"],
    where: [
      Pattern(v("id"), c("person/name"), v("name")),
      Pattern(
        v("id"),
        c("person/name"),
        Free(fn(raw) {
          case dynamic.string(raw) {
            Ok(str) ->
              case string.starts_with(str, "J") {
                True -> Ok(Nil)
                False -> Error(Nil)
              }
            Error(_) -> Error(Nil)
          }
        }),
      ),
    ],
    db: db,
  )
  // |> io.debug
}
