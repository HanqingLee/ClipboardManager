# Screenshot narrative (5 shots)

前 3 张决定大多数用户是否继续看；所有 headline ≤40 字符。中文与英文为人工撰写，其他 Tier 1 语言为本地化文案，建议母语者复核 ja/de/fr/es/pt-BR 的断行。

## Shot 1

**Headline (en-US, 28/40):** `Copy it. Press ⌘⇧V. Find it.`

**Supplement:** Pastewell keeps a searchable history of everything you copy.

**Real UI state:** Full picker open with the search field focused and six real cards.

| locale | chars | headline |
|---|---|---|
| en-US | 28 | `Copy it. Press ⌘⇧V. Find it.` |
| zh-Hans | 13 | `复制后按 ⌘⇧V，马上找回` |
| zh-Hant | 13 | `複製後按 ⌘⇧V，馬上找回` |
| ja | 18 | `コピーしたら ⌘⇧V ですぐ見つかる` |
| de-DE | 29 | `Kopiert. ⌘⇧V. Wiedergefunden.` |
| fr-FR | 21 | `Copié. ⌘⇧V. Retrouvé.` |
| es-ES | 25 | `Copiado. ⌘⇧V. Recuperado.` |
| pt-BR | 19 | `Copiou. ⌘⇧V. Achou.` |

## Shot 2

**Headline (en-US, 27/40):** `Search everything you copy.`

**Supplement:** Type a word; results narrow as you type.

**Real UI state:** Search field with a word typed and the list filtered to two matching cards.

| locale | chars | headline |
|---|---|---|
| en-US | 27 | `Search everything you copy.` |
| zh-Hans | 9 | `搜索你复制过的一切` |
| zh-Hant | 9 | `搜尋你複製過的一切` |
| ja | 10 | `コピーした内容を検索` |
| de-DE | 26 | `Alles Kopierte durchsuchen` |
| fr-FR | 34 | `Recherchez tout ce que vous copiez` |
| es-ES | 24 | `Busca todo lo que copias` |
| pt-BR | 30 | `Pesquise tudo o que você copia` |

## Shot 3

**Headline (en-US, 27/40):** `Text, links, images, files.`

**Supplement:** Text, links, images, and files live in one history.

**Real UI state:** One text, one link, one image, and one file card visible together.

| locale | chars | headline |
|---|---|---|
| en-US | 27 | `Text, links, images, files.` |
| zh-Hans | 11 | `文本、链接、图片、文件` |
| zh-Hant | 11 | `文字、連結、圖片、檔案` |
| ja | 12 | `テキスト・画像・ファイル` |
| de-DE | 28 | `Text, Links, Bilder, Dateien` |
| fr-FR | 30 | `Texte, liens, images, fichiers` |
| es-ES | 34 | `Texto, enlaces, imágenes, archivos` |
| pt-BR | 31 | `Texto, links, imagens, arquivos` |

## Shot 4

**Headline (en-US, 25/40):** `Keyboard-first. No mouse.`

**Supplement:** Arrows to move, Return to choose, Esc to close.

**Real UI state:** Picker with a small keycap overlay showing arrows, Return, and Esc.

| locale | chars | headline |
|---|---|---|
| en-US | 25 | `Keyboard-first. No mouse.` |
| zh-Hans | 9 | `键盘优先，无需鼠标` |
| zh-Hant | 8 | `鍵盤優先，免滑鼠` |
| ja | 10 | `キーボードだけで操作` |
| de-DE | 19 | `Tastatur statt Maus` |
| fr-FR | 23 | `Au clavier, sans souris` |
| es-ES | 18 | `Teclado, sin ratón` |
| pt-BR | 18 | `Teclado, sem mouse` |

## Shot 5

**Headline (en-US, 31/40):** `Private by design. Stays local.`

**Supplement:** No account, no network, no special permission.

**Real UI state:** Settings General section showing the history limit, plus a small on-device note.

| locale | chars | headline |
|---|---|---|
| en-US | 31 | `Private by design. Stays local.` |
| zh-Hans | 9 | `隐私优先，只存本机` |
| zh-Hant | 9 | `隱私優先，只存本機` |
| ja | 14 | `プライバシー優先、端末内保存` |
| de-DE | 30 | `Privat. Bleibt auf deinem Mac.` |
| fr-FR | 29 | `Confidentiel, stocké en local` |
| es-ES | 23 | `Privado, solo en tu Mac` |
| pt-BR | 22 | `Privado, só no seu Mac` |

## 制作说明

- 使用真实的 Pastewell 面板与设置窗口，不伪造界面元素；文字/卡片内容可用测试数据。

- 本地化截图只做 Tier 1 八种语言；其余 locale 回退英文图。

- 最省的做法是在 1.1.1 加一个 Debug-only 的离屏渲染钩子，按语言把面板渲染成 PNG，不依赖屏幕录制权限。

