# AGENTS.md

## Build Discipline

- 在修改完毕后，必须至少进行一次可执行的编译构建检查，再结束本轮工作。
- Flutter App 改动后，优先执行：
  - `flutter analyze`
  - `flutter build apk --debug`
- 如果改动涉及测试逻辑或可测试 UI，额外执行：
  - `flutter test`

