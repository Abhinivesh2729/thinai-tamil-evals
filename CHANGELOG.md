## 0.1.0

- Tamil dataset v1: 60 items, nine tasks, three skills.
- Scorers: multiple choice above chance, chrF (sacreBLEU-compatible), short-answer match with Tamil case endings, rule-checked writing, correction gain.
- `EvalRunner` with immediate cancellation and a single retry per item.
- `OpenAiGenerator` and a CLI for OpenAI-compatible servers.
