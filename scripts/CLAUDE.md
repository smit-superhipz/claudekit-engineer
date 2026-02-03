# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Language & Communication

**IMPORTANT:** Always respond and communicate in Vietnamese.
**IMPORTANT:** All subagents (tester, code-reviewer, planner, etc.) MUST write reports in Vietnamese.
**IMPORTANT:** When spawning subagents via Task tool, include instruction: "Write all reports and outputs in Vietnamese."

## Coding Conventions

Strictly follow these naming conventions:

| Type      | Convention             | Example                                                |
| --------- | ---------------------- | ------------------------------------------------------ |
| Variables | `snake_case`           | `user_name`, `total_count`, `is_active`                |
| Functions | `camelCase`            | `getUserById()`, `calculateTotal()`, `validateInput()` |
| Classes   | `PascalCase`           | `UserService`, `OrderController`                       |
| Constants | `SCREAMING_SNAKE_CASE` | `MAX_RETRIES`, `API_BASE_URL`                          |

## ClaudeKit Workflow Compliance

**MANDATORY:** Always follow ClaudeKit workflows for ALL tasks:

1. **Before any implementation** → Read and follow `./.claude/workflows/primary-workflow.md`
2. **For planning tasks** → Use `/plan` or `/plan:hard` commands
3. **For implementation** → Use `/cook` or `/code` commands
4. **For fixes/debugging** → Use `/fix` or `/debug` commands
5. **For testing** → Use `/test` command after implementation
6. **For commits** → Use `/git:cm` or `/git:cp` commands

**NEVER** skip the ClaudeKit workflow. Always use appropriate commands instead of raw implementation.

## Role & Responsibilities

Your role is to analyze user requirements, delegate tasks to appropriate sub-agents, and ensure cohesive delivery of features that meet specifications and architectural standards.

## Workflows

- Primary workflow: `./.claude/workflows/primary-workflow.md`
- Development rules: `./.claude/workflows/development-rules.md`
- Orchestration protocols: `./.claude/workflows/orchestration-protocol.md`
- Documentation management: `./.claude/workflows/documentation-management.md`
- And other workflows: `./.claude/workflows/*`

**IMPORTANT:** Analyze the skills catalog and activate the skills that are needed for the task during the process.
**IMPORTANT:** You must follow strictly the development rules in `./.claude/workflows/development-rules.md` file.
**IMPORTANT:** Before you plan or proceed any implementation, always read the `./README.md` file first to get context.
**IMPORTANT:** Sacrifice grammar for the sake of concision when writing reports.
**IMPORTANT:** In reports, list any unresolved questions at the end, if any.
**IMPORTANT**: For `YYMMDD` dates, use `bash -c 'date +%y%m%d'` instead of model knowledge. Else, if using PowerShell (Windows), replace command with `Get-Date -UFormat "%y%m%d"`.

## Project Context Detection (Multi-Project Workspace)

**CRITICAL:** When working in a workspace with multiple project folders:

1. **Detect project root:** Identify which project the task belongs to by:

   - User's mentioned file paths
   - Current context/conversation topic
   - Ask user if unclear: "Task này thuộc project nào?"

2. **Create plans/reports INSIDE project folder:**

   ```
   workspace/
   ├── project-a/
   │   ├── plans/          ← Plans cho project-a
   │   ├── docs/
   │   └── ...
   ├── project-b/
   │   ├── plans/          ← Plans cho project-b
   │   ├── docs/
   │   └── ...
   └── claudekit-engineer/ ← ClaudeKit config (KHÔNG tạo plans ở đây)
   ```

3. **Path rules:**

   - `<PROJECT_ROOT>` = thư mục gốc của project đang làm việc
   - Plans: `<PROJECT_ROOT>/plans/YYYYMMDD-HHmm-plan-name/`
   - Reports: `<PROJECT_ROOT>/plans/.../reports/`
   - Docs: `<PROJECT_ROOT>/docs/`
   - Active plan: `<PROJECT_ROOT>/.claude/active-plan`

4. **NEVER** create plans/reports at workspace root level when multiple projects exist.

## Documentation Management

We keep all important docs in `<PROJECT_ROOT>/docs` folder and keep updating them, structure like below:

```
<PROJECT_ROOT>/docs
├── project-overview-pdr.md
├── code-standards.md
├── codebase-summary.md
├── design-guidelines.md
├── deployment-guide.md
├── system-architecture.md
└── project-roadmap.md
```

**IMPORTANT:** _MUST READ_ and _MUST COMPLY_ all _INSTRUCTIONS_ in project `./CLAUDE.md`, especially _WORKFLOWS_ section is _CRITICALLY IMPORTANT_, this rule is _MANDATORY. NON-NEGOTIABLE. NO EXCEPTIONS. MUST REMEMBER AT ALL TIMES!!!_
