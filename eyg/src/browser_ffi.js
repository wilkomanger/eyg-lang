import * as Gleam from "./gleam.mjs";

export async function fetchSource() {
  let response = await fetch("/saved.json");
  return await response.text();
}

export async function fetchText(url) {
  let response = await fetch(url);
  return await response.text();
}

export async function fetchJSON(url) {
  try {
    let response = await fetch(url);
    let data = await response.json();
    return new Gleam.Ok(data);
  } catch (error) {
    new Gleam.Error(error);
  }
}

export async function postJSON(url, data) {
  try {
    let response = await fetch(url, {
      method: "POST",
      body: JSON.stringify(data),
    });
    console.log(response.status);
    return new Gleam.Ok([]);
  } catch (error) {
    new Gleam.Error(error);
  }
}

export function writeIntoDiv(content) {
  let el = document.getElementById("the-id-for-dropping-html");
  if (el) {
    el.innerHTML = content;
  } else {
    console.warn("nothing found with long id");
  }
  return [];
}

export function tryCatch(f) {
  try {
    return new Gleam.Ok(f());
  } catch (error) {
    return new Gleam.Error(error);
  }
}
