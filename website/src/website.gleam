import blogatto
import blogatto/config
import blogatto/config/feed
import blogatto/config/markdown
import blogatto/config/markdown/code
import blogatto/error
import blogatto/post.{type Post}
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

const site_url = "https://uhkay.com"

pub fn main() -> Nil {
  let cfg = config()

  case blogatto.build(cfg) {
    Ok(_) -> io.println("Site built successfully")
    Error(err) ->
      io.println_error("Build failed: " <> error.describe_error(err))
  }
}

fn home_view(posts: List(Post(Nil))) -> Element(Nil) {
  let sorted = list.sort(posts, fn(a, b) { timestamp.compare(b.date, a.date) })

  html.html([], [
    html.head([], [
      html.title([], "uhkay homepage"),
      html.meta([
        attribute.name("description"),
        attribute.content("uhkay's homepage."),
      ]),
      html.link([
        attribute.rel("stylesheet"),
        attribute.href("/css/output.css"),
      ]),
    ]),
    html.body([attribute.class("bg-ctp-base text-ctp-text dark:mocha")], [
      navbar(),
      html.div([attribute.class("flex justify-center")], [
        html.div([attribute.class("max-w-prose w-full px-4")], [
          html.h1([attribute.class("text-3xl py-8")], [
            element.text("Hi there!"),
          ]),
          html.h2([attribute.class("text-2xl font-bold mb-4")], [
            html.text("Blogs:"),
          ]),
          html.ul(
            [
              attribute.class(
                "list-disc list-inside [&>li>a]:hover:text-ctp-green",
              ),
            ],
            list.map(sorted, fn(p) {
              html.li([], [
                html.a([attribute.href("/blog/" <> p.slug)], [
                  element.text(p.title),
                ]),
              ])
            }),
          ),
        ]),
      ]),
    ]),
  ])
}

pub fn navbar() {
  html.nav([], [
    html.ul([attribute.class("flex gap-3 p-4 [&>li>a]:hover:text-ctp-green")], [
      html.li([], [html.a([attribute.href("/")], [html.text("home")])]),
      html.li([], [
        html.a([attribute.href("/projects")], [html.text("projects")]),
      ]),
      html.li([], [html.a([attribute.href("/about")], [html.text("about")])]),
    ]),
  ])
}

pub fn config() {
  let syntax_config =
    code.default()
    |> code.keyword(fn(text) {
      html.span([attribute.class("text-[#cba6f7]")], [html.text(text)])
    })
    |> code.string(fn(text) {
      html.span([attribute.class("text-[#a6e3a1]")], [html.text(text)])
    })
    |> code.number(fn(text) {
      html.span([attribute.class("text-[#fab387]")], [html.text(text)])
    })
    |> code.comment(fn(text) {
      html.span([attribute.class("text-[#6c7086]")], [html.text(text)])
    })
    |> code.function(fn(text) {
      html.span([attribute.class("text-[#89b4fa]")], [html.text(text)])
    })
    |> code.operator(fn(text) {
      html.span([attribute.class("text-[#89dceb]")], [html.text(text)])
    })
    |> code.punctuation(fn(text) {
      html.span([attribute.class("text-[#cdd6f4]")], [html.text(text)])
    })
    |> code.type_(fn(text) {
      html.span([attribute.class("text-[#f9e2af]")], [html.text(text)])
    })
    |> code.module(fn(text) {
      html.span([attribute.class("text-[#89dceb]")], [html.text(text)])
    })

  let md =
    markdown.default()
    |> markdown.markdown_path("./blog")
    |> markdown.syntax_highlighting(syntax_config)
    |> markdown.route_prefix("blog")
    |> markdown.template(post_template)
    |> markdown.h1(fn(id, children) {
      html.h1([attribute.class("text-2xl"), attribute.id(id)], children)
    })
    |> markdown.h2(fn(id, children) {
      html.h2([attribute.class("text-xl"), attribute.id(id)], children)
    })
    |> markdown.pre(fn(el) {
      html.div(
        [
          attribute.class(
            "bg-[#313244] p-3 rounded-lg border border-[#45475a] shadow-sm",
          ),
        ],
        [
          html.pre(
            [
              attribute.class(
                "text-[#cdd6f4] font-mono text-sm overflow-x-auto",
              ),
            ],
            el,
          ),
        ],
      )
    })
    |> markdown.a(fn(href, _title, el) {
      html.a(
        [
          attribute.class("underline hover:text-ctp-green"),
          attribute.href(href),
        ],
        el,
      )
    })
    |> markdown.ul(fn(el) {
      html.ul([attribute.class("list-disc list-inside")], el)
    })

  let rss =
    feed.new("uhkay's blog", site_url, "my personal blog")
    |> feed.language("en-us")
    |> feed.generator("Blogatto")

  config.new(site_url)
  |> config.output_dir("./dist")
  |> config.static_dir("./static")
  |> config.markdown(md)
  |> config.route("/", home_view)
  |> config.feed(rss)
}

fn post_template(post: Post(Nil), _all_posts: List(Post(Nil))) {
  let lang = option.unwrap(post.language, "en")

  html.html([attribute.lang(lang)], [
    html.head([], [
      html.meta([attribute.charset("UTF-8")]),
      html.title([], post.title),
      html.meta([
        attribute.name("description"),
        attribute.content(post.description),
      ]),
      html.link([
        attribute.rel("stylesheet"),
        attribute.href("/css/output.css"),
      ]),
    ]),
    html.body([attribute.class("bg-ctp-base text-ctp-text dark:mocha")], [
      navbar(),
      html.article([attribute.class("flex justify-center")], [
        html.div([attribute.class("max-w-3xl w-full px-4 my-8 space-y-6")], [
          html.h1([attribute.class("text-2xl")], [element.text(post.title)]),
          html.p([], [element.text(timestamp_to_string(post.date))]),
          element.fragment(post.contents),
        ]),
      ]),
    ]),
  ])
}

fn timestamp_to_string(ts: timestamp.Timestamp) {
  let #(date, _time) = timestamp.to_calendar(ts, calendar.utc_offset)
  calendar.month_to_string(date.month) |> string.slice(0, 3)
  <> " "
  <> int.to_string(date.day)
  <> ", "
  <> int.to_string(date.year)
}
