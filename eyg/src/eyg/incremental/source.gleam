import gleam/list
import gleam/map
import gleam/javascript
import eygir/expression as e

pub type Expression {
  Var(String)
  Fn(String, Int)
  Let(String, Int, Int)
  Call(Int, Int)
  Integer(Int)
  String(String)
  Tail
  Cons
  Vacant(comment: String)
  Empty
  Extend(label: String)
  Select(label: String)
  Overwrite(label: String)
  Tag(label: String)
  Case(label: String)
  NoCases
  Perform(label: String)
  Handle(label: String)
  Builtin(identifier: String)
}

pub fn do_from_tree(tree, acc) {
  case tree {
    e.Variable(label) -> #(Var(label), acc)
    e.Lambda(label, body) -> {
      let #(node, acc) = do_from_tree(body, acc)
      let index = list.length(acc)
      let acc = [node, ..acc]
      #(Fn(label, index), acc)
    }
    e.Let(label, value, then) -> {
      let #(then, acc) = do_from_tree(then, acc)
      let then_index = list.length(acc)
      let acc = [then, ..acc]
      let #(value, acc) = do_from_tree(value, acc)
      let value_index = list.length(acc)
      let acc = [value, ..acc]
      #(Let(label, value_index, then_index), acc)
    }
    e.Apply(func, arg) -> {
      let #(arg, acc) = do_from_tree(arg, acc)
      let arg_index = list.length(acc)
      let acc = [arg, ..acc]
      let #(func, acc) = do_from_tree(func, acc)
      let func_index = list.length(acc)
      let acc = [func, ..acc]
      #(Call(func_index, arg_index), acc)
    }
    e.Binary(value) -> #(String(value), acc)
    e.Integer(value) -> #(Integer(value), acc)
    e.Tail -> #(Tail, acc)
    e.Cons -> #(Cons, acc)
    e.Vacant(comment) -> #(Vacant(comment), acc)
    e.Empty -> #(Empty, acc)
    e.Extend(label) -> #(Extend(label), acc)
    e.Select(label) -> #(Select(label), acc)
    e.Overwrite(label) -> #(Overwrite(label), acc)
    e.Tag(label) -> #(Tag(label), acc)
    e.Case(label) -> #(Case(label), acc)
    e.NoCases -> #(NoCases, acc)
    e.Perform(label) -> #(Perform(label), acc)
    e.Handle(label) -> #(Handle(label), acc)
    e.Builtin(identifier) -> #(Builtin(identifier), acc)
  }
}

pub fn from_tree(tree) {
  let #(exp, acc) = do_from_tree(tree, [])
  let index = list.length(acc)
  let source = list.reverse([exp, ..acc])
  #(index, source)
}
fn next(ref) {
  javascript.update_reference(ref, fn(x) { x + 1 })
}

fn push(x, ref) { 
  let #(node, source) = x
  let index = next(ref)
  let source = map.insert(source, index, node)
  #(index, source)
 }

pub fn do_from_tree_map(tree, acc, ref) -> #(Int, map.Map(Int, Expression)) {
  case tree {
    e.Variable(label) -> #(Var(label), acc)
    e.Lambda(label, body) -> {
      let #(index, acc) = do_from_tree_map(body, acc, ref)
      #(Fn(label, index), acc)
    }
    e.Let(label, value, then) -> {
      let #(then, acc) = do_from_tree_map(then, acc, ref)
      let #(value, acc) = do_from_tree_map(value, acc, ref)
      #(Let(label, value, then), acc)
    }
    e.Apply(func, arg) -> {
      let #(arg, acc) = do_from_tree_map(arg, acc, ref)
      let #(func, acc) = do_from_tree_map(func, acc, ref)
      #(Call(func, arg), acc)
    }
    e.Binary(value) -> #(String(value), acc)
    e.Integer(value) -> #(Integer(value), acc)
    e.Tail -> #(Tail, acc)
    e.Cons -> #(Cons, acc)
    e.Vacant(comment) -> #(Vacant(comment), acc)
    e.Empty -> #(Empty, acc)
    e.Extend(label) -> #(Extend(label), acc)
    e.Select(label) -> #(Select(label), acc)
    e.Overwrite(label) -> #(Overwrite(label), acc)
    e.Tag(label) -> #(Tag(label), acc)
    e.Case(label) -> #(Case(label), acc)
    e.NoCases -> #(NoCases, acc)
    e.Perform(label) -> #(Perform(label), acc)
    e.Handle(label) -> #(Handle(label), acc)
    e.Builtin(identifier) -> #(Builtin(identifier), acc)
  }
  |> push(ref)
}

pub fn from_tree_map(tree) {
  let #(index, source) = do_from_tree_map(tree, map.new(), javascript.make_reference(0))
  #(index, source)
}
