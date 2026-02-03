# Shared Rules for All Agents

**BẮT BUỘC - MANDATORY:**

## Language Output

- **Viết TẤT CẢ outputs (reports, plans, analysis, reviews) bằng Tiếng Việt**
- Code comments, commit messages → English (standard practice)
- Variable names, function names → Follow project conventions

## Report Quality

- Sacrifice grammar for concision
- List unresolved questions at end
- Use `date +%y%m%d` for YYMMDD dates (not model knowledge)

## Multi-Project Workspace

- `<PROJECT_ROOT>` = thư mục gốc của project đang làm việc (KHÔNG phải workspace root)
- Tất cả plans/reports phải nằm trong `<PROJECT_ROOT>/plans/`
- Nếu không rõ project nào, hỏi user: "Task này thuộc project nào?"
- **NEVER** create plans/reports at workspace root level
