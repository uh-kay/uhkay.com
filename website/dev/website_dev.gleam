import blogatto/dev
import blogatto/error
import gleam/io
import website

pub fn main() {
  let cfg = website.config()

  case
    cfg
    |> dev.new()
    |> dev.build_command("gleam run -m website")
    |> dev.port(3000)
    |> dev.start()
  {
    Ok(Nil) -> io.println("Dev server stopped.")
    Error(err) -> io.println("Dev server error: " <> error.describe_error(err))
  }
}
