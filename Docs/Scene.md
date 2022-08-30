# Scene

⚠️ For now, scenes are static and can only be created through a builder.

## TODO
- [ ] Dynamic scenes
- [ ] Read from file
- [ ] Save to file
- [ ] Create and store the buffers in advance (at the moment scenes are small enough to not need buffers at all)

```mermaid
classDiagram

class SceneBuilder{
    + add(light: LightSource)
    + add(camera: Camera)
    + add(object: Renderable)
    + build(device: MTLDevice) -> Scene
}
SceneBuilder --> Scene : Creates

Scene: + mainCamera

class Camera{
    - fovy:        Float
    - aspectRatio: Float
    - near:        Float
    - far:         Float

    - view:       Matrix4x4
    - projection: Matrix4x4
}

Scene *--"*" LightSource
Scene *--"*" Camera
Scene *--"*" Renderable

class LightSource{
    + color: Vector4
    + intensity: Float
}

Camera --|> Mobile
Mobile --|> Positionable
LightSource --|> Positionable
Renderable --|> Positionable

```