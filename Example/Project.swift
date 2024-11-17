import ProjectDescription

let project = Project(
  name: "TodoList",
  packages: [
    .local(path: "..")
  ],
  targets: [
    .target(
      name: "TodoList",
      destinations: .iOS,
      product: .app,
      bundleId: "io.tuist.TodoList",
      infoPlist: .extendingDefault(
        with: [
          "UILaunchScreen": [
            "UIColorName": "",
            "UIImageName": "",
          ]
        ]
      ),
      sources: ["TodoList/Sources/**"],
      resources: ["TodoList/Resources/**"],
      dependencies: [
        .package(product: "SwiftStore")
      ]
    ),
    .target(
      name: "TodoListTests",
      destinations: .iOS,
      product: .unitTests,
      bundleId: "io.tuist.TodoListTests",
      infoPlist: .default,
      sources: ["TodoList/Tests/**"],
      resources: [],
      dependencies: [
        .target(name: "TodoList")
      ]
    ),
  ]
)
