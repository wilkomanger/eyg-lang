import gleam/dynamic.{Dynamic}
import gleam/option.{Option}
import gleam/javascript/array.{Array}

pub external type Document

pub external type Element

pub external type Event

// -------- Search --------
external fn do_query_selector(String) -> Dynamic =
  "" "document.querySelector"

pub fn query_selector(selector) -> Result(Option(Element), _) {
  dynamic.optional(fn(e) { Ok(dynamic.unsafe_coerce(e)) })(do_query_selector(
    selector,
  ))
}

pub external fn document() -> Element =
  "../../plinth_ffi.js" "doc"

pub external fn query_selector_all(String) -> Array(Element) =
  "../../plinth_ffi.js" "querySelectorAll"

pub external fn closest(Element, String) -> Result(Element, Nil) =
  "../../plinth_ffi.js" "closest"

// -------- Elements --------

pub external fn create_element(String) -> Element =
  "" "document.createElement"

pub external fn set_attribute(Element, String, String) -> Nil =
  "../../plinth_ffi.js" "setAttribute"

pub external fn append(Element, Element) -> Nil =
  "../../plinth_ffi.js" "append"

// append works on children, not referenced in block components
pub external fn insert_element_after(Element, Element) -> Nil =
  "../../plinth_ffi.js" "insertElementAfter"

pub external fn remove(Element) -> Nil =
  "../../plinth_ffi.js" "remove"

// -------- Elements Attributes --------

pub external fn dataset_get(Element, String) -> Result(String, Nil) =
  "../../plinth_ffi.js" "datasetGet"

// -------- Event --------

pub external fn add_event_listener(
  Element,
  String,
  fn(Event) -> Nil,
) -> fn() -> Nil =
  "../../plinth_ffi.js" "addEventListener"

pub external fn target(Event) -> Element =
  "../../plinth_ffi.js" "target"

pub external fn prevent_default(Event) -> Element =
  "../../plinth_ffi.js" "preventDefault"

// -------- Other --------

pub external fn insert_after(Element, String) -> Nil =
  "../../plinth_ffi.js" "insertAfter"

external fn do_get(any, String) -> Dynamic =
  "" "Reflect.get"

pub fn inner_text(el: Element) -> String {
  let assert Ok(text) = dynamic.string(do_get(el, "innerText"))
  text
}

external fn do_set(any, String, Dynamic) -> Nil =
  "" "Reflect.set"

pub fn set_text(el: Element, value: String) {
  do_set(el, "innerText", dynamic.from(value))
}

pub fn set_html(el: Element, value: String) {
  do_set(el, "innerHTML", dynamic.from(value))
}

// TODO fix proper action or add event listener
pub external fn on_click(fn(String) -> Nil) -> Nil =
  "../../plinth_ffi.js" "onClick"

pub external fn on_keydown(fn(String) -> Nil) -> Nil =
  "../../plinth_ffi.js" "onKeyDown"
