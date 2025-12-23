# Hyper-Local Pollen Alert

## Чек-лист «день #1»

1. ☑︎ Создать приватный репозиторий GitHub.
2. ☑︎ Добавить Debug.xcconfig/Release.xcconfig с пустыми TOMORROW_API_KEY, AMBEE_API_KEY.
3. ☑︎ Подключить SPM: H3Swift, GRDB. (Подготовлен код, требуется добавить в Xcode)
4. ☑︎ Скомпилировать «пустое» приложение — CI должен пройти. (Переведено на SwiftUI)
5. ☑︎ Написать первый unit-тест: GeoTests.latLonToH3().
6. ☑︎ Обновить данный файл: пометить выполненные пункты ☑︎.

---

## Структура проекта
- `Sources/App/`: Точка входа (SwiftUI).
- `Sources/Core/`: Бизнес-логика, модели, алгоритмы.
- `Sources/UI/`: Интерфейс, компоненты, тема.
- `Config/`: Конфигурация и API ключи (Keys.xcconfig в игноре).
- `Tests/`: Unit-тесты.

## Технологии
- iOS 26.2+
- Swift 6
- SwiftUI
- Google Maps SDK
- GRDB (SQLite)
- H3 Indexing

