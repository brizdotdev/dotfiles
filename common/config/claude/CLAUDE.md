# Agent Config

## Coding preferences - general

- Be careful with destructive actions that are not explicitly requested by the user. If you are unsure, ask for clarification before proceeding.
- Do not comment every line. Only comment lines that are not self-explanatory or require additional context.
- Keep existing comments up to date when modifying code. If a comment is no longer relevant, remove it.

## Questions are read-only

- A question is a request for an answer, not for changes. If a question is asked, answer it but do not make any changes yet.
- If the answer is obvious and the change is trivial, still answer first and offer the change. Ask before making it.

## Sub agents

- When several agents do work in parallel, state file ownership up front to avoid conflicts.

## Blast radius

If you are unsure, ask for clarification and clearly explain what you are about to do and the potential consequences before proceeding.

- Never touch production environments, live (non-local) databases unless explicitly told to do so.
- Never modify or delete anything on remote systems unless explicitly told to do so.

## One off tools

You should have access to either Nix or Mise which you can use to run one-off tools without installing them.
