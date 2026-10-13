components {
  id: "script"
  component: "/pickups/pickup.script"
  properties {
    id: "kind"
    value: "cherry"
    type: PROPERTY_TYPE_HASH
  }
}
embedded_components {
  id: "sprite"
  type: "sprite"
  data: "default_animation: \"cherry\"\n"
  "material: \"/builtins/materials/sprite.material\"\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/pickups/pickups.atlas\"\n"
  "}\n"
  ""
}
embedded_components {
  id: "collisionobject"
  type: "collisionobject"
  data: "type: COLLISION_OBJECT_TYPE_TRIGGER\n"
  "mass: 0.0\n"
  "friction: 0.1\n"
  "restitution: 0.5\n"
  "group: \"pickup\"\n"
  "mask: \"player\"\n"
  "embedded_collision_shape {\n"
  "  shapes {\n"
  "    shape_type: TYPE_SPHERE\n"
  "    position {\n"
  "      x: 0.0\n"
  "      y: 0.0\n"
  "    }\n"
  "    rotation {\n"
  "    }\n"
  "    index: 0\n"
  "    count: 1\n"
  "    id: \"sphere\"\n"
  "  }\n"
  "  data: 10.0\n"
  "}\n"
  ""
}
