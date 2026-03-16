---
title: 'Send Email Using Lustre'
date: 2026-03-16 16:00:00
slug: send-email-using-lustre
description: Send email using Gleam, Lustre, and Mailtrap
---

Disclaimer: I'm not affiliated or sponsored by Mailtrap.

Recently I've been learning Gleam and I find the language fun and productive. But when 
I'm looking up how to send email using a provider's API, there's no tutorial on that so
I decided to write one. Also, maybe we can use Lustre to send HTML email body? Let's 
find out if you can do that!

The whole code is hosted on GitHub: 

## Prerequisite

- [Mailtrap](https://mailtrap.io/) Account (you can create one for free)
- [Gleam](https://gleam.run)

## 0. Create a new project and install dependencies

```bash
gleam new app
gleam add lustre@5
gleam add gleam_httpc@5
gleam add envoy@1
gleam add gleam_http@4
gleam add gleam_json@3
```

`Lustre` is for creating HTML, `gleam_httpc` for sending request, `envoy` for reading 
environment variables, `gleam_http` for creating new request, and `gleam_json` for creating
JSON payload.

## 1. Add environment variables
```
MAILTRAP_API_KEY=
MAILTRAP_API_URL=
```
From Mailtrap, get your API key and URL. Put it inside `.env` and load it. You use 
[direnv](https://github.com/direnv/direnv) or load it from 
[justfile](https://github.com/casey/just). Don't forget to add `.env` to your 
`.gitignore`.

## 2. Write some Gleam

First we create custom error type `MailError` so we can combine the error type into one,
which make the error type descriptive and avoid any type mismatch. Then we write the
`send_email()` to send the email to Mailtrap API.

```gleam
import envoy
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import lustre/element
import lustre/element/html

// Create a custom error type
type MailError {
  MissingApiUrl
  MissingApiKey
  TransportError(httpc.HttpError)
  UnexpectedResponse(status: Int, body: String)
}

type Recipient {
  Recipient(email: String)
}

// Encode the Recipient type into JSON. Note: the Gleam LS code action can do this
// automatically for you.
fn recipient_to_json(recipient: Recipient) -> json.Json {
  let Recipient(email:) = recipient
  json.object([
    #("email", json.string(email)),
  ])
}

pub fn main() -> Nil {
  todo
}

// Send an email using Mailtrap API. It takes a bunch of arguments and on success 
// returns Nil meanwhile on failure returns MailError.
fn send_email(
  recipients recipients: List(Recipient),
  sender sender: String,
  sender_name sender_name: String,
  email_subject subject: String,
  html_body html_body: String,
  text_body text_body: String,
) -> Result(Nil, MailError) {
  // Get Mailtrap API URL from env vars.
  use url <- result.try(
    envoy.get("MAILTRAP_API_URL") |> result.replace_error(MissingApiUrl),
  )

  // Get Mailtrap API key from env vars.
  use api_key <- result.try(
    envoy.get("MAILTRAP_API_KEY") |> result.replace_error(MissingApiKey),
  )

  // Create a new request using the URL.
  let assert Ok(base_request) = request.to(url)

  // Create a list of tuple containing JSON string key and JSON string value.
  let email_header = [
    #(
      "from",
      json.object([
        #("email", json.string(sender)),
        #("name", json.string(sender_name)),
      ]),
    ),
    #("to", json.array(recipients, recipient_to_json)),
    #("subject", json.string(subject)),
  ]
  let email_body = [
    #("html", json.string(html_body)),
    #("text", json.string(text_body)),
  ]
  
  // Combine both list into one, turn it into json.Json and turn it into string.
  let payload =
    list.append(email_header, email_body) |> json.object |> json.to_string

  // From the base request, add post method, set auth header using the API key, set
  // content type to application/json, and set the JSON body.
  let req =
    base_request
    |> request.set_method(http.Post)
    |> request.set_header("Authorization", "Bearer " <> api_key)
    |> request.set_header("Content-Type", "application/json")
    |> request.set_body(payload)

  // Send the request, we map the error into MailError.
  use res <- result.try(httpc.send(req) |> result.map_error(TransportError))

  // Check if status is 200-299, if it is not, return UnexpectedResponse with the 
  // response's status and body.
  case res.status >= 200 && res.status < 300 {
    True -> Ok(Nil)
    False -> Error(UnexpectedResponse(res.status, res.body))
  }
}
```

## 3. Handle the error
```gleam
// ...

// handle_error takes in MailError, pattern match the error and print the error to
// stderr.
fn handle_error(err: MailError) {
  case err {
    MissingApiUrl -> io.println_error("Missing API url!")
    MissingApiKey -> io.println_error("Missing API key!")
    TransportError(err) ->
      // in production you'd want to not using string.inspect()
      io.println_error("Fail to send request. Error: " <> string.inspect(err))
    UnexpectedResponse(status:, body:) ->
      io.println_error(
        "Mailtrap error: status: " <> int.to_string(status) <> " body: " <> body,
      )
  }
}
```
Handling error is important so you can always make it better than this, maybe add 
logging, be more descriptive, etc. But for this example that's what I do to keep things
simple.

## 4. Use send_email
```gleam
pub fn main() -> Nil {
  let result = {
    let recipients = [Recipient(email: "contact@uhkay.com")]
    let sender = "lucy@example.com"
    let sender_name = "Lucy"
    let email_subject = "Gleam Club Invitation"
    let html_body = html.p([], [
      html.text("You met me at a very gleamy time of my life.",
    )]) |> element.to_string
    let text_body = "You met me at a very gleamy time of my life."

    send_email(
      recipients:,
      sender:,
      sender_name:,
      email_subject:,
      html_body:,
      text_body:,
    )
  }

  case result {
    Ok(_) -> io.println("Email sent!")
    Error(err) -> handle_error(err)
  }
}
```

## 5. Email Template (optional)

If you want to make an email template, you can easily make one:
```gleam
// It's just a normal function!
fn email_template(message) {
  html.p([], [html.text(message)])
  |> element.to_string
}

pub fn main() -> Nil {
  let result = {
    let recipients = [Recipient(email: "contact@uhkay.com")]
    let sender = "hello@example.com"
    let sender_name = "Mailtrap Test"
    let email_subject = "Gleam Club Invitation"
    // You use it like a normal function too.
    let html_body =
      email_template("You met me at a very gleamy time of my life.")
    let text_body = "You met me at a very gleamy time of my life."

    send_email(
      recipients:,
      sender:,
      sender_name:,
      email_subject:,
      html_body:,
      text_body:,
    )
  }

  case result {
    Ok(_) -> io.println("Email sent!")
    Error(err) -> handle_error(err)
  }
}
```
Here's where Lustre shine, you can just write the entire thing in Gleam! In other 
languages you'd need to learn custom templating syntax.

And that's it folks! If you find this useful, feel free to share it =)
