components {
  id: "tilemap"
  component: "/world/world.tilemap"
}
embedded_components {
  id: "collisionobject"
  type: "collisionobject"
  data: "collision_shape: \"/world/world.tilemap\"\n"
  "type: COLLISION_OBJECT_TYPE_STATIC\n"
  "mass: 0.0\n"
  "friction: 0.1\n"
  "restitution: 0.5\n"
  "group: \"ground\"\n"
  "mask: \"player\"\n"
  "mask: \"enemy\"\n"
  ""
}
