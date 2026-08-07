# ANCHOR: all
import protobuf_serialization
import protobuf_serialization/proto_parser

# This macro generates Task, TaskList, and Priority types at compile time
import_proto3 "protocol.proto3"

# Use the generated types as if they were manually defined
let task = Task(
  id: "task-001",
  title: "Implement feature",
  description: "Add new functionality",
  priority: Priority.HIGH,
  tags: @["urgent", "backend"],
  completed: false
)

let taskList = TaskList(
  tasks: @[task],
  owner: "alice"
)

# Encode and decode
let encoded = Protobuf.encode(taskList)
let decoded = Protobuf.decode(encoded, TaskList)

assert decoded.tasks[0].title == "Implement feature"
assert decoded.tasks[0].priority == Priority.HIGH
assert decoded.tasks[0].tags == @["urgent", "backend"]
assert decoded.owner == "alice"

echo "Import proto complete example passed!"
# ANCHOR_END: all
