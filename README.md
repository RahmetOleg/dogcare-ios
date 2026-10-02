# DogCare для iOS

iOS-версия Android-приложения **DogCare** (исходник: `../DogCare`, APK: `DogCare.apk`).
Переписано с Kotlin + Jetpack Compose на **Swift + SwiftUI**, функциональность сохранена один в один.

## Что внутри (соответствие Android-версии)

| Функция | Android | iOS (этот проект) |
|---|---|---|
| Профиль собаки (фото, кличка, порода, дата рождения, вес, пол, аллергии, хроника) | `feature/profile` | `Views/Profile` |
| Прогулки: таймер + история + заметки | `feature/walks` | `Views/Walks` |
| Прививки: список, срок следующей, push за 3 дня в 9:00 | `feature/vaccines` | `Views/Vaccines` |
| Напоминания: лекарства/кормление, дни недели, время, вкл/выкл | `feature/reminders` | `Views/Reminders` |
| Справочник опасных продуктов: 243 записи, поиск с транслитом и fuzzy, карточка, калькулятор лакомств (RER/MER, ≤10%), аллергия-предупреждения, риски пород, кнопка звонка ветеринару | `feature/foods` | `Views/Foods` |
| Календарь течки: сетка месяца, прогноз по циклу, история | `feature/heat` | `Views/Settings/HeatView` |
| Настройки: тема (система/светлая/тёмная), экспорт в JSON | `feature/settings` | `Views/Settings` |
| Локализация RU + EN, русские склонения возраста | `values-ru` + plurals | `ru.lproj`/`en.lproj` + stringsdict |

Портированы без изменений логика поиска (`FoodSearchEngine` — скоринг, транслит «курица→kurica», Levenshtein), сопоставление аллергий и пород (`AllergyMatcher`, `BreedMatcher`), калькулятор порций, прогноз течки (60–400 дней, по умолчанию 180) и вся цветовая тема (градиентный фон, палитра, статусы продуктов).

## Требования

* macOS + **Xcode 15+** (проект открывается как есть)
* iOS **16.0+**, iPhone
* Для запуска на своём устройстве: бесплатный Apple ID достаточно (Xcode → Settings → Accounts)

## Сборка

1. Откройте `DogCare.xcodeproj` в Xcode.
2. Выберите команду подписи: target **DogCare** → **Signing & Capabilities** → **Team** (ваш Apple ID; Bundle ID при желании поменяйте — `com.dogcare.ios` может быть занят).
3. Выберите свой iPhone в списке устройств → **Run**.

## Получить .ipa без Mac

В проекте лежит GitHub Actions workflow `.github/workflows/build-ipa.yml`:
положите проект в репозиторий на GitHub → Actions → «Build iOS IPA» → скачайте артефакт
`DogCare-unsigned.ipa`. Это **неподписанный** IPA: установить его можно через
[Sideloadly](https://sideloadly.io) или [AltStore](https://altstore.io) со своим Apple ID (бесплатно, до 3 приложений, переподпись раз в 7 дней).

## Отличия от Android-версии (осознанные)

* **Хранилище**: вместо Room/WorkManager — JSON-файлы в Application Support + `UserDefaults` + `UNUserNotificationCenter`. Повторяющиеся напоминания по дням недели реализованы штатными repeating-триггерами iOS (в Android — одноразовые задачи WorkManager с перепланированием).
* **Material You dynamic color** (Android 12+) не переносится — на iOS всегда фирменная палитра.
* Формат экспорта JSON совпадает с Android-версией (те же поля), файлы взаимно читаемы.
* `foods_guide.json` перенесён из Android-проекта без изменений.

## Структура

```
DogCare.xcodeproj          — проект Xcode (сгенерирован скриптом)
DogCare/
  App/                     — точка входа, панель вкладок, тема
  Models/                  — Dog, Walk, Vaccine, Reminder, HeatPeriod, Food…
  Persistence/             — JSON-хранилище, настройки, загрузчик справочника
  Domain/                  — поиск, калькуляторы, валидация, прогноз, уведомления, экспорт
  Stores/                  — AppStore (центральное состояние, @MainActor)
  Views/                   — экраны по фичам (как feature-модули Android)
  Resources/               — локализация, foods_guide.json, ассеты, иконка
```
