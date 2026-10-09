# Hacker News feedback, 2026-10-09

Thread: [Let your AI agents paint big arrows, boxes and text on your screen](https://news.ycombinator.com/item?id=50018817), 185 points and 74 comments when read on 2026-10-09 at 16:35 CEST, #1 on the front page for a while. Also covered: PRs [#36](https://github.com/franzenzenhofer/big-arrow-on-the-screen/pull/36) and [#37](https://github.com/franzenzenhofer/big-arrow-on-the-screen/pull/37).

Every comment was read. Each point was sorted into one of four groups: real criticism (we act on it), real use cases (they shape the README and the skill), jokes and scope requests (we do not build them), and general debate (nothing to build). Tickets live in [`docs/plan/tickets.json`](../plan/tickets.json), milestone M6.

## Real criticism

| Comment | Point | What we do |
|---|---|---|
| [hn8726](https://news.ycombinator.com/item?id=50019459) | The permissions FAQ is unreadable | T42 [#39](https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/39): a table, plain sentences |
| [intended](https://news.ycombinator.com/item?id=50020886) | The tagline says nothing | T42 #39: says what it draws and where |
| [einpoklum](https://news.ycombinator.com/item?id=50019005), [mococa](https://news.ycombinator.com/item?id=50019789), [cyberjunkie](https://news.ycombinator.com/item?id=50019641) | Reads like generated text | T42 #39: the vaguest passages rewritten, the jokes stay |
| [satyanash](https://news.ycombinator.com/item?id=50018945) | How can an arrow without focus be in front? | T42 #39: new FAQ entry |
| [m-s-y](https://news.ycombinator.com/item?id=50019964) | Why a skill, and how many tokens does it cost? | T42 #39: FAQ entry with the measured token counts |
| [pimlottc](https://news.ycombinator.com/item?id=50020187) | The hero's arrows are wonky | T44 [#41](https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/41): re-staged on short paths, no rendering change |
| [arshxyz](https://news.ycombinator.com/item?id=50019233) | The README only speaks to technical people | T43 [#40](https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/40): real apps, everyday tasks |
| [tilemarch](https://news.ycombinator.com/item?id=50020731), [ex-aws-dude](https://news.ycombinator.com/item?id=50019401) | An arrow says where to click, not whether you should | T45 [#42](https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/42): on approvals the sign names the consequence |
| [hn8726](https://news.ycombinator.com/item?id=50019459), [Maken](https://news.ycombinator.com/item?id=50019723) | Could an agent cover the Decline button? | T47 [#44](https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/44): honest FAQ answer, every guarantee backed by a test |
| [alexpotato](https://news.ycombinator.com/item?id=50020859) | Use deep links | T46 [#43](https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/43): the skill opens the exact pane first, then points |
| [TekMol](https://news.ycombinator.com/item?id=50019011) | Four languages to draw on a Mac? | T48 [#45](https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/45): the binary is Swift only; tooling excluded from GitHub's language stats |
| [jarombouts, PR #37](https://github.com/franzenzenhofer/big-arrow-on-the-screen/pull/37) | The box around the target drifts while it pulses | T41 [#38](https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/38): fixed with credit, regression test added |

## Real use cases

| Comment | Use case | Where it went |
|---|---|---|
| [inanutshellus](https://news.ycombinator.com/item?id=50019008) | A guiding agent, not a doing agent: "teach me to do this" | README "Show me how", real-app scenes (#40) |
| [ravila4](https://news.ycombinator.com/item?id=50020002) | Learning a complex app (Blender) with an LLM | same |
| [FinnLobsien](https://news.ycombinator.com/item?id=50019113) | Docs whose screenshots still make you search | `--png` and the real-app scenes |
| [arshxyz](https://news.ycombinator.com/item?id=50019233), [lbreakjai](https://news.ycombinator.com/item?id=50019407), [ghm2180](https://news.ycombinator.com/item?id=50019715), [conception](https://news.ycombinator.com/item?id=50019468) | Helping parents and relatives | README "Helping someone else", TextEdit print scene (#40) |
| [melvinroest](https://news.ycombinator.com/item?id=50019373), [alansaber](https://news.ycombinator.com/item?id=50019330) | Agents should be able to point at what they see | the project's premise |

## Jokes and scope requests we do not build

| Comment | Request | Decision |
|---|---|---|
| [isoprophlex](https://news.ycombinator.com/item?id=50019128), PRs #36 and #37 | Rainbow dripping arrows, flames, shaking, airhorn | Not now, T49 [#46](https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/46). The PRs are careful work, but the arrow's job is to be calm and quick to read. The one real bug they found is fixed (#38). |
| [lbreakjai](https://news.ycombinator.com/item?id=50019407) | An iPad version | Not possible, T50 [#47](https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/47): iPadOS does not let an app draw over other apps |
| [vessenes](https://news.ycombinator.com/item?id=50019039) | Agents pointing for each other | No consumer yet |

## General debate, nothing to build

AI-generated projects on the front page, trust in hosted models, enshittification, the future of desktops, Idiocracy, and Don Hopkins' 1989 PostScript pointing hand for NeWS ([prior art, with thanks](https://news.ycombinator.com/item?id=50019247)).
