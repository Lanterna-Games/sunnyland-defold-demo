components {
  id: "script"
  component: "/world/world.script"
}
embedded_components {
  id: "music"
  type: "sound"
  data: "sound: \"/music/walkyandtalky.ogg\"\n"
  "looping: 1\n"
  "group: \"master\"\n"
  "gain: 1.0\n"
  ""
}
embedded_components {
  id: "feedback"
  type: "factory"
  data: "prototype: \"/pickups/feedback.go\"\n"
  ""
}
