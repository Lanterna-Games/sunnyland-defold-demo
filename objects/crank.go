components {
  id: "script"
  component: "/objects/crank.script"
}
embedded_components {
  id: "sprite"
  type: "sprite"
  data: "default_animation: \"crank-up\"\n"
  "material: \"/builtins/materials/sprite.material\"\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/world/props.atlas\"\n"
  "}\n"
  ""
  position {
    x: 0.0
    y: 8.0
  }
}
embedded_components {
  id: "collisionobject"
  type: "collisionobject"
  data: "type: COLLISION_OBJECT_TYPE_TRIGGER\n"
  "mass: 0.0\n"
  "friction: 0.1\n"
  "restitution: 0.5\n"
  "group: \"interact\"\n"
  "mask: \"player\"\n"
  "embedded_collision_shape {\n"
  "  shapes {\n"
  "    shape_type: TYPE_BOX\n"
  "    position {\n"
  "      x: 0.0\n"
  "      y: 8.0\n"
  "    }\n"
  "    rotation {\n"
  "    }\n"
  "    index: 0\n"
  "    count: 3\n"
  "    id: \"box\"\n"
  "  }\n"
  "  data: 11.0\n"
  "  data: 8.0\n"
  "  data: 10.0\n"
  "}\n"
  ""
}
