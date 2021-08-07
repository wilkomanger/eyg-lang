import gleam/io
import language/codegen/javascript
import language/ast/builder.{
  binary, call, case_, clause, constructor, destructure, destructure_row, destructure_tuple,
  function, let_, rest, row, tuple_, var, varient,
}
import language/type_.{Data}
import language/ast
import language/scope
import language/ast/support

fn compile(untyped, scope) {
  let Ok(#(type_, tree, typer)) = ast.infer(untyped, scope)
  javascript.render(#(type_, tree), False)
}

pub fn variable_assignment_test() {
  let untyped =
    let_("foo", binary("My First Value"), let_("foo", var("foo"), var("foo")))
  let js = compile(untyped, scope.new())
  let [l1, l2, l3] = js
  let "let foo$1 = \"My First Value\";" = l1
  let "let foo$2 = foo$1;" = l2
  let "foo$2" = l3
}

pub fn nested_assignment_test() {
  let scope =
    scope.new()
    |> scope.with_equal()

  let untyped =
    let_(
      "match",
      let_(
        "tmp",
        binary("TMP!"),
        call(var("equal"), [var("tmp"), binary("test")]),
      ),
      var("match"),
    )
  let js = compile(untyped, scope)
  let [l1, l2, l3, l4, l5] = js
  let "let match$1 = (() => {" = l1
  let "  let tmp$1 = \"TMP!\";" = l2
  let "  return equal$1(tmp$1, \"test\");" = l3
  let "})();" = l4
  let "match$1" = l5
}

pub fn let_destructure_test() {
  let scope = scope.new()

  let untyped =
    varient(
      "User",
      [],
      [constructor("User", [Data("Binary", [])])],
      destructure(
        "User",
        ["first_name"],
        call(var("User"), [binary("abc")]),
        var("first_name"),
      ),
    )
  let js = compile(untyped, scope)
  let [l1, l2, l3] = js
  let "let User$1 = ((...args) => Object.assign({ type: \"User\" }, args));" =
    l1
  let "let [first_name$1] = Object.values(User$1(\"abc\"));" = l2
  let "first_name$1" = l3
}

pub fn tuple_assignment_test() {
  let untyped =
    let_("pair", tuple_([binary("abc"), binary("xyz")]), var("pair"))
  let js = compile(untyped, scope.new())
  let [l1, l2] = js
  let "let pair$1 = [\"abc\", \"xyz\"];" = l1
  let "pair$1" = l2
}

pub fn nested_tuple_assignment_test() {
  let scope =
    scope.new()
    |> scope.with_equal()
  let untyped =
    let_(
      "pair",
      tuple_([
        let_(
          "tmp",
          binary("TMP!"),
          call(var("equal"), [var("tmp"), binary("test")]),
        ),
        binary("xyz"),
      ]),
      var("pair"),
    )
  let js = compile(untyped, scope)
  let [l1, l2, l3, l4, l5, l6, l7, l8] = js
  let "let pair$1 = [" = l1
  let "  (() => {" = l2
  let "    let tmp$1 = \"TMP!\";" = l3
  let "    return equal$1(tmp$1, \"test\");" = l4
  let "  })()," = l5
  let "  \"xyz\"," = l6
  let "];" = l7
  let "pair$1" = l8
}

pub fn tuple_destructure_test() {
  let untyped =
    function(["pair"], destructure_tuple(["a", "b"], var("pair"), var("a")))
  let js = compile(untyped, scope.new())
  let [l1, l2, l3, l4] = js
  let "((pair$1) => {" = l1
  let "  let [a$1, b$1] = pair$1;" = l2
  let "  return a$1;" = l3
  let "})" = l4
}

pub fn row_assignment_test() {
  let untyped =
    let_(
      "user",
      row([#("first_name", binary("Bob")), #("family_name", binary("Ross"))]),
      var("user"),
    )
  let js = compile(untyped, scope.new())
  let [l1, l2] = js
  let "let user$1 = {first_name: \"Bob\", family_name: \"Ross\"};" = l1
  let "user$1" = l2
}

pub fn row_destructure_test() {
  let untyped =
    function(
      ["user"],
      destructure_row(
        [#("first_name", "a"), #("family_name", "b")],
        var("user"),
        var("a"),
      ),
    )
  let js = compile(untyped, scope.new())
  let [l1, l2, l3, l4] = js
  let "((user$1) => {" = l1
  let "  let {first_name: a$1, family_name: b$1} = user$1;" = l2
  let "  return a$1;" = l3
  let "})" = l4
}

// Don't need to to a case expression for tuples
pub fn case_with_boolean_test() {
  let scope = scope.new()
  let untyped =
    support.with_boolean(function(
      ["bool"],
      case_(
        var("bool"),
        [clause("True", [], binary("hello")), rest("ping", binary("bye!"))],
      ),
    ))
  let js = compile(untyped, scope)
  let [l1, l2, l3, l4, l5, l6, l7, l8, l9, l10, l11, l12] = js
  let "let True$1 = ((...args) => Object.assign({ type: \"True\" }, args));" =
    l1
  let "let False$1 = ((...args) => Object.assign({ type: \"False\" }, args));" =
    l2
  let "((bool$1) => {" = l3
  let "  return ((subject) => {" = l4
  let "  if (subject.type == \"True\") {" = l5
  let "    let [] = Object.values(subject);" = l6
  let "    return \"hello\";" = l7
  let "  } else {" = l8
  let "    let ping = subject;" = l9
  let "    return \"bye!\";" = l10
  let "  }})(bool$1);" = l11
  let "})" = l12
}

pub fn simple_function_call_test() {
  let scope =
    scope.new()
    |> scope.with_equal()
  let untyped = call(var("equal"), [binary("foo"), binary("bar")])
  let js = compile(untyped, scope)
  let [l1] = js
  let "equal$1(\"foo\", \"bar\")" = l1
}

pub fn oneline_function_test() {
  let scope = scope.new()
  let untyped = let_("x", function(["x"], var("x")), var("x"))
  let js = compile(untyped, scope)
  let [l1, l2] = js
  let "let x$1 = ((x$1) => { return x$1; });" = l1
  let "x$1" = l2
}

pub fn call_oneline_function_test() {
  let scope = scope.new()
  let untyped = call(function(["x"], var("x")), [binary("hello")])
  let js = compile(untyped, scope)
  let [l1] = js
  let "((x$1) => { return x$1; })(\"hello\")" = l1
}

pub fn multiline_function_test() {
  let scope =
    scope.new()
    |> scope.with_equal()

  let untyped =
    let_(
      "test",
      function(
        ["a", "b"],
        let_(
          "a",
          call(var("equal"), [var("a"), binary("blah")]),
          call(var("equal"), [var("b"), binary("other")]),
        ),
      ),
      var("test"),
    )
  let js = compile(untyped, scope)
  let [l1, l2, l3, l4, l5] = js
  let "let test$1 = ((a$1, b$1) => {" = l1
  let "  let a$2 = equal$1(a$1, \"blah\");" = l2
  let "  return equal$1(b$1, \"other\");" = l3
  let "});" = l4
}

// TODO do construction
fn aside() {
  let x = Ok
  try a = x(2)
  Error(Nil)
}
// TODO email to ask about other language front ends. Is there a long form place to ask discord program lang questions
// pass in constructor functions, made when making types. 
// program is going to render a call function that doesn't exist. 
// TODO make sure that there's no duplicating types
