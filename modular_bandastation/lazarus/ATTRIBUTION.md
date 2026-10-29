# Источники проекта «Лазарь»

Карта, механики, тексты и модуль антагониста перенесены из
[ThaumicNik/Paradise-SS220, IceEvent](https://github.com/ThaumicNik/Paradise-SS220/tree/fa1ad6a104368d3445c5a83666a0daab0ca69838/modular_ss220/lazarus).
Зафиксированный коммит: `fa1ad6a104368d3445c5a83666a0daab0ca69838`, 20 июля 2025.
Автор модуля и коммитов события — ThaumicNik.

Код и его адаптации распространяются под AGPL-3.0. Текст лицензии:
`LICENSE-AGPLv3.txt` рядом с этим файлом.

Исходный [README с лицензиями](https://github.com/ThaumicNik/Paradise-SS220/blob/fa1ad6a104368d3445c5a83666a0daab0ca69838/README.md#licenses)
относит остальные ресурсы, не отмеченные отдельно, к CC BY-SA 3.0.
Текст лицензии: `LICENSE-CC-BY-SA-3.0.txt` рядом с этим файлом.
В модуль не копировались каталоги ресурсов Goonstation с отдельной лицензией.

| Ресурсы | Источник |
| --- | --- |
| Карты колонии и TSF, геотермальные генераторы, растения, лестницы, снег, биоморфы, Великая Мать, плоть и кнопки | `modular_ss220/lazarus`, ThaumicNik / участники исходного Paradise |
| Индикатор запаса тепла | `icons/mob/screen_frostbite.dmi`, IceEvent |
| Цветные полы колонии и TSF | `modular_ss220/aesthetics/floors/icons/floors.dmi`, Paradise-SS220; локальная копия `icons/lazarus_floors.dmi` |
| Животные и растения | `icons/mob/winter_mob.dmi`, `icons/mob/animal.dmi`, `icons/obj/hydroponics/harvest.dmi`, Paradise |
| Тестеры, снаряд и камень душ | `icons/obj/hypo.dmi`, `icons/obj/projectiles.dmi`, `icons/obj/wizard.dmi`, Paradise |
| Пепельница | `icons/ashtray.dmi`, Paradise |
| Оповещение эволюции и гибель биоморфа | `sound/ambience/antag/ling_alert.ogg`, `sound/shadowdemon/shadowdeath.ogg`, Paradise |

Ресурсы скопированы побайтово. `assets.json` фиксирует исходные пути и SHA-256.
Существующие изображения и звуки PrimeDream используются на условиях их
собственных исходных лицензий.

`icons/colony_map.png` — новый схематичный план перенесённой карты, созданный
`dmm-tools suite-1.11`. Подземелья, частные убежища, точки появления и служебные
маркеры скрыты. Оригинальная ссылка с бумажной карты возвращает заглушку и
не используется. Исходный хэш карты, параметры скрытия и хэш PNG записаны
в `generated_assets` файла `assets.json`.

Исходный трек Darkwood-OST-Morning.ogg не включён в этот порт: отдельная лицензия трека в доноре не подтверждена. Событие использует штатную музыку лобби.
