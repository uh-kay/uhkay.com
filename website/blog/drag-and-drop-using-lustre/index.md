---
title: "Drag and Drop Using Lustre"
date: 2026-09-14 17:00:00
slug: drag-and-drop-using-lustre
description: Implement drag and drop without any libraries beside Lustre
---

This week I'm trying to implement drag and drop in my project. The project uses
Lustre for the frontend side and I don't know how to code drag and drop in Lustre.
And so, after experimenting I manage to make it work. In this blog, we're going
to implement one of MDN's example on the drag and drop API: making a kanban
board ([source](https://developer.mozilla.org/en-US/docs/Web/API/HTML_Drag_and_Drop_API/Kanban_board))!

Btw all the code for this blog is available [here](https://github.com/uh-kay/lustre_dnd_example).

First let's make a new empty project. Run `gleam new lustre_dnd_example`.
Then run `gleam add lustre` and `gleam add lustre_dev_tools --dev`.

Inside lustre_dnd_example.gleam write this:

```gleam
import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleam/result
import lustre
import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/event

pub fn main() -> Nil {
  let app = lustre.simple(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

// MODEL ----------------------------------------------------------------------

type Model {
  Model(
    dragged_task: option.Option(DraggedTask),
    hovered_column: option.Option(DropTarget),
    task_columns: dict.Dict(ColumnType, List(Task)),
  )
}

type Task {
  Task(id: Int, title: String)
}

type DraggedTask {
  DraggedTask(task: Task, from: ColumnType, height: Int)
}

type DropTarget {
  DropTarget(to: ColumnType, index: Int)
}

type ColumnType {
  ToDo
  InProgress
  Done
}

type Message {
  UserDroppedTask(to: ColumnType)
  UserDraggedOverColumn(to: ColumnType)
  UserDraggedOverTask(to: ColumnType, index: Int)
  UserDraggedTask(task: Task, from: ColumnType, height: Int)
}

fn init(_) {
  Model(
    dragged_task: option.None,
    task_columns: dict.new()
      |> dict.insert(ToDo, [
        Task(1, "Reinvent universe"),
      ])
      |> dict.insert(InProgress, [Task(2, "Reinvent wheel")])
      |> dict.insert(Done, [
        Task(3, "Play Chesshire"),
        Task(4, "Make drag and drop using Lustre works"),
      ]),
    hovered_column: option.None,
  )
}

// UPDATE ---------------------------------------------------------------------

fn update(model: Model, message: Message) {
  case message {
    UserDroppedTask(to:) -> {
      let result = {
        use drop_target <- result.try(option.to_result(
          model.hovered_column,
          Nil,
        ))
        use dragged_task <- result.try(option.to_result(model.dragged_task, Nil))
        let from = dragged_task.from
        let dragged_task = dragged_task.task

        // Find the original index before the filtering which causes the task
        // index to shift.
        let original_index = case dict.get(model.task_columns, from) {
          Ok(tasks) -> {
            list.index_map(tasks, fn(task, i) { #(task, i) })
            |> list.find(fn(value) {
              let #(task, _) = value
              task.id == dragged_task.id
            })
            |> result.map(fn(value) {
              let #(_, i) = value
              i
            })
            |> result.unwrap(drop_target.index)
          }
          Error(_) -> drop_target.index
        }

        // Let ["A", "B", "C", "D"] as task column. When we try moving B to
        // between C and D, we move it to index 3. But after filtering, the task
        // index shift and C is at index 1 and D at 2. Moving to index 3 would
        // place it at the end, not between C and D. That's why when the drop
        // target's index is bigger than the original, we substract one.
        let insert_index = case from == to {
          True if drop_target.index > original_index -> drop_target.index - 1
          _ -> drop_target.index
        }

        let task_columns = case dict.get(model.task_columns, from) {
          Ok(tasks) -> {
            let tasks =
              list.filter(tasks, fn(task) { task.id != dragged_task.id })
            dict.insert(model.task_columns, from, tasks)
          }
          Error(_) -> model.task_columns
        }

        let task_columns = case dict.get(task_columns, to) {
          Ok(tasks) -> {
            let #(before, after) = list.split(tasks, insert_index)
            let tasks = list.append(before, [dragged_task, ..after])
            dict.insert(task_columns, to, tasks)
          }
          Error(_) -> model.task_columns
        }

        Ok(Model(
          dragged_task: option.None,
          task_columns:,
          hovered_column: option.None,
        ))
      }

      case result {
        Ok(model) -> model
        Error(_) -> model
      }
    }

    UserDraggedOverTask(to:, index:) -> {
      let model = Model(..model, hovered_column: Some(DropTarget(to, index)))

      model
    }

    UserDraggedTask(task:, from:, height:) -> {
      let model =
        Model(..model, dragged_task: Some(DraggedTask(task, from, height)))

      model
    }

    UserDraggedOverColumn(to:) -> {
      let index = case dict.get(model.task_columns, to) {
        Ok(tasks) -> list.length(tasks)
        Error(_) -> 0
      }

      let hovered_column = case model.hovered_column {
        Some(drop_target) -> Some(DropTarget(to, drop_target.index))
        option.None -> Some(DropTarget(to, index))
      }

      let model = Model(..model, hovered_column:)

      model
    }
  }
}

// VIEW -----------------------------------------------------------------------

fn view(model: Model) -> element.Element(_) {
  html.div([attribute.class("flex flex-col p-4 gap-4")], [
    html.h1([attribute.class("text-2xl")], [html.text("Lustre Kanban Board")]),
    html.div([attribute.class("flex gap-4")], [
      task_column_view(
        "To Do",
        ToDo,
        model.task_columns,
        model.dragged_task,
        model.hovered_column,
      ),
      task_column_view(
        "In Progress",
        InProgress,
        model.task_columns,
        model.dragged_task,
        model.hovered_column,
      ),
      task_column_view(
        "Done",
        Done,
        model.task_columns,
        model.dragged_task,
        model.hovered_column,
      ),
    ]),
  ])
}

fn task_column_view(
  column_title: String,
  column_type: ColumnType,
  tasks: dict.Dict(ColumnType, List(Task)),
  dragged_task: option.Option(DraggedTask),
  hovered_column: option.Option(DropTarget),
) {
  let tasks = case dict.get(tasks, column_type) {
    Ok(tasks) -> tasks
    Error(_) -> []
  }
  let current_task_title = case dragged_task {
    Some(dragged_task) -> {
      dragged_task.task.title
    }
    option.None -> ""
  }

  let tasks =
    list.index_map(tasks, fn(task, index) {
      task_view(
        task.id,
        task.title,
        column_type,
        current_task_title == task.title,
        index,
      )
    })

  let tasks = case hovered_column, dragged_task {
    Some(DropTarget(hovered_type, index)), Some(DraggedTask(height:, ..))
      if hovered_type == column_type
    -> {
      let #(before, after) = list.split(tasks, index)
      list.append(before, [placeholder_view(height), ..after])
    }
    _, _ -> {
      tasks
    }
  }

  html.div(
    [
      event.on("drop", decode.success(UserDroppedTask(column_type))),
      event.on(
        "dragover",
        decode.success(UserDraggedOverColumn(to: column_type)),
      )
        |> event.stop_propagation()
        |> event.prevent_default(),
      attribute.class("border p-4 rounded-md w-64 min-h-40"),
    ],
    [
      html.h2([attribute.class("mb-2")], [html.text(column_title)]),
      html.ul([attribute.class("flex flex-col gap-2 min-h-40")], tasks),
    ],
  )
}

fn task_view(
  task_id: Int,
  task_title: String,
  column_type: ColumnType,
  dragged: Bool,
  index: Int,
) {
  let dragover_decoder = {
    use y <- decode.field("clientY", decode.int)
    use element <- decode.field("currentTarget", decode.dynamic)
    let rect = get_rect(element)
    let midpoint = rect.y + rect.height / 2

    let index = case y > midpoint {
      True -> index + 1
      False -> index
    }

    decode.success(UserDraggedOverTask(to: column_type, index:))
  }
  let dragstart_decoder = {
    use element <- decode.field("currentTarget", decode.dynamic)
    let rect = get_rect(element)
    decode.success(UserDraggedTask(
      task: Task(task_id, task_title),
      from: column_type,
      height: rect.height,
    ))
  }

  html.li(
    [
      attribute.draggable(True),
      event.on("dragstart", dragstart_decoder),
      event.on("dragover", dragover_decoder)
        |> event.stop_propagation()
        |> event.prevent_default(),
      attribute.class("border p-2 rounded-md hover:cursor-grab"),
      attribute.class("active:cursor-grabbing text-wrap max-w-64"),
      attribute.class(case dragged {
        True -> "opacity-20"
        False -> ""
      }),
    ],
    [html.p([], [html.text(task_title)])],
  )
}

fn placeholder_view(height) {
  html.li(
    [
      attribute.class("border p-2 rounded-md"),
      attribute.style("height", int.to_string(height) <> "px"),
    ],
    [],
  )
}

// EXTERNAL -------------------------------------------------------------------

pub type Rect {
  Rect(
    x: Int,
    y: Int,
    width: Int,
    height: Int,
    top: Int,
    right: Int,
    bottom: Int,
    left: Int,
  )
}

@external(javascript, "./rect.ffi.mjs", "getBoundingClientRect")
fn get_rect(element: dynamic.Dynamic) -> Rect
```

Create one more file under /src and name it `rect.ffi.mjs` and write this:

```js
/**
 *
 * @param {Element} element
 * @returns {DOMRect}
 */

export function getBoundingClientRect(element) {
  return element.getBoundingClientRect();
}
```

We'll have three part: model, update, and view. Model will contain all the data
the webpage will need to render the page. Update will update the model, each time
the model updates, the page will rerender. And view defines how we should use
the model to render the page.

## Model

The `Model` type have three record: dragged_task which holds data of the currently
dragged task, hovered_column which contains information of the drop target, and
task_columns which has all the task data of all column.

`Message` type contains all the possible user action. Later we will pattern
match the message in the update function.

```gleam
fn init(_) {
  Model(
    dragged_task: option.None,
    task_columns: dict.new()
      |> dict.insert(ToDo, [
        Task(1, "Reinvent universe"),
      ])
      |> dict.insert(InProgress, [Task(2, "Reinvent wheel")])
      |> dict.insert(Done, [
        Task(3, "Play Chesshire"),
        Task(4, "Make drag and drop using Lustre works"),
      ]),
    hovered_column: option.None,
  )
}
```

In `init()` we create the model and initial data.

## Update

`update` takes a model and message. We then pattern match the message and update
the model according to the message.

When the user dropped the task, we first get the drop_target and dragged_task,
if any of that is missing, we don't update the model. We must first get the
original index and calculate the insert index because when the list is filtered,
the index would shift making the placement of the task incorrect.

Let's assume the task column is ["A", "B", "C", "D"]. When we try to move B to
between C and D, we move it to index 3. But after we filter B out, A is index 0
C is 1, D is 2. Moving to index 3 would mean placing B to the last. That's why
we calculate the original index and then if the drop_target's index is bigger
than the original index, we reduce the insert_index by one.

The we simply split the tasks into two based on the insert_index add the
dragged_task to the middle and append everything together and insert it into the
dict.

When user dragged over task or dragged task, we simply update the either the
hovered_column or dragged_task.

When the user dragged over column, we don't know if the hovered column is empty
or not so we first get length and update index before updating the
hovered_column.

## View

The view function will render the page based on the model. I divide the view
into components which are just function. There are `task_column_view` to render
the column, `task_view` to render individual task, and `placeholder_view` to render
the placeholder when dragging over a column.

The interesting bit is on the `task_view`:

```gleam
fn task_view(
  task_id: Int,
  task_title: String,
  column_type: ColumnType,
  dragged: Bool,
  index: Int,
) {
  let dragover_decoder = {
    use y <- decode.field("clientY", decode.int)
    use element <- decode.field("currentTarget", decode.dynamic)
    let rect = get_rect(element)
    let midpoint = rect.y + rect.height / 2

    let index = case y > midpoint {
      True -> index + 1
      False -> index
    }

    decode.success(UserDraggedOverTask(to: column_type, index:))
  }
  let dragstart_decoder = {
    use element <- decode.field("currentTarget", decode.dynamic)
    let rect = get_rect(element)
    decode.success(UserDraggedTask(
      task: Task(task_id, task_title),
      from: column_type,
      height: rect.height,
    ))
  }

  html.li(
    [
      attribute.draggable(True),
      event.on("dragstart", dragstart_decoder),
      event.on("dragover", dragover_decoder)
        |> event.stop_propagation()
        |> event.prevent_default(),
      attribute.class("border p-2 rounded-md hover:cursor-grab"),
      attribute.class("active:cursor-grabbing text-wrap max-w-64"),
      attribute.class(case dragged {
        True -> "opacity-20"
        False -> ""
      }),
    ],
    [html.p([], [html.text(task_title)])],
  )
}
```

Notice the decoder is decoding `clientY` and `currentTarget`. Lustre's `event.on`
can run a decoder on the event object. So it's equivalent to

```javascript
element.addEventListener("dragover", (event) => {
  // do something with event object
});
```

Here we calculate midway point to get the index. If mouse cursor (y) is past
midway, then we add 1 to index. Then we can send the value to the message which
will be updated in update function.

Note that to get the rect we need to write a Javascript FFI `get_rect` which
takes a dynamic and return a `Rect`. Don't forget to set the target to "javscript"
in gleam.toml or else the compiler would complain because by default the target
is Erlang.

## Running the Example

To run the example, run this command: `gleam run -m lustre/dev start`. This
command will run Lustre dev tool server and you can open the website on
`http://localhost:1234`.

## Mobile Support

If you want to also support mobile web browsers, you should use Pointer Events
API instead of Drag and Drop API because Drag and Drop API on mobile is poor or
unsupported. You can find an example using Lustre [here](https://github.com/uh-kay/lustre_dnd_pointer_example).
The main difference is we use pointer event instead of drag event on view. The
other difference is that we need to add `touch-action-none` on task to disable
the default behavior of scrolling or zooming on mobile. We also need to add
another JS FFI code to release pointer capture so the pointer can target elements
underneath.

## Conclusion

That's it peeps! Lustre is a simple yet powerful library. While there's a lot of
library for drag and drop functionality in Lustre, I wrote this blog to highlight
that it's very simple to write it yourself and use the libraries if you need
something more. Hope you find the guide useful :)
